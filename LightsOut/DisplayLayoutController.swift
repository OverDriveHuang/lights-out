import Combine
import CoreGraphics
import Foundation

@MainActor
final class DisplayLayoutController: ObservableObject {
    struct MissingCustomDisplayRow: Identifiable {
        let id: Int
        let name: String
    }
    @Published private(set) var currentMode: DisplayLayoutMode = .showAll
    @Published private(set) var previewMode: DisplayLayoutMode?
    @Published private(set) var fallback: LayoutFallback?
    @Published private(set) var isApplying = false
    @Published private(set) var isSatisfied = true
    @Published private(set) var lifecycle: DisplayLayoutLifecycle = .starting

    var onRequestPanelPresentation: (() -> Void)?
    var onApplyFinished: (() -> Void)?

    private let displaysViewModel: DisplaysViewModel
    private let store: CustomLayoutStore
    private var customDocument: CustomLayoutDocument
    private var shortcutCommitWorkItem: DispatchWorkItem?
    private var generation: UInt64 = 0
    private var isHotKeyHeld = false
    private var allHotKeyKeysReleased = true
    private var queuedModeAfterApply: DisplayLayoutMode?
    private var cursorMode: DisplayLayoutMode?
    private var hasLayoutInteraction = false
    private var hideExternalFallbackTarget: Set<PersistentDisplayIdentity>?
    private var customSessionOverrides: [DisplayID: Bool] = [:]

    init(displaysViewModel: DisplaysViewModel, store: CustomLayoutStore = CustomLayoutStore()) {
        self.displaysViewModel = displaysViewModel
        self.store = store
        customDocument = store.load()
    }

    func finishStartup() {
        guard lifecycle == .starting else { return }
        let startupGeneration = generation
        displaysViewModel.fetchDisplays { [weak self] in
            guard let self, self.lifecycle == .starting, self.generation == startupGeneration else { return }
            self.lifecycle = .ready
            if self.previewMode != nil, self.allHotKeyKeysReleased {
                self.schedulePreviewCommit()
            }
        }
    }

    func handleHotKeyPressed() {
        guard lifecycle != .terminating, !isHotKeyHeld else { return }
        isHotKeyHeld = true
        allHotKeyKeysReleased = false
        shortcutCommitWorkItem?.cancel()
        shortcutCommitWorkItem = nil
        onRequestPanelPresentation?()

        let nextMode = DisplayLayoutSelectionPolicy.nextHotKeyPreview(
            hasLayoutInteraction: hasLayoutInteraction,
            cursorMode: previewMode ?? cursorMode,
            currentMode: currentMode
        )
        previewMode = nextMode
        cursorMode = nextMode
        hasLayoutInteraction = true
    }

    func handleHotKeyCombinationReleased() {
        isHotKeyHeld = false
    }

    func handleAllHotKeyKeysReleased() {
        allHotKeyKeysReleased = true
        guard previewMode != nil else { return }
        schedulePreviewCommit()
    }

    func selectMode(_ mode: DisplayLayoutMode) {
        guard lifecycle == .ready else {
            previewMode = mode
            cursorMode = mode
            hasLayoutInteraction = true
            return
        }
        cancelPreview()
        cursorMode = mode
        hasLayoutInteraction = true
        commit(mode)
    }

    func cancelPreview() {
        generation &+= 1
        shortcutCommitWorkItem?.cancel()
        shortcutCommitWorkItem = nil
        previewMode = nil
    }

    func suspend() {
        guard lifecycle != .terminating else { return }
        cancelPreview()
        lifecycle = .suspended
    }

    func resumeAndReconcile() {
        guard lifecycle == .suspended else { return }
        lifecycle = .ready
        reconcileCurrentMode()
    }

    func terminate() {
        lifecycle = .terminating
        generation &+= 1
        shortcutCommitWorkItem?.cancel()
        shortcutCommitWorkItem = nil
        previewMode = nil
        queuedModeAfterApply = nil
    }

    func reconcileCurrentMode() {
        guard lifecycle == .ready, !isApplying, allHotKeyKeysReleased else { return }
        apply(mode: currentMode)
    }

    func setCustomDisplay(_ display: DisplayInfo, enabled: Bool) throws {
        guard currentMode == .custom, lifecycle == .ready, !isApplying else {
            throw DisplayError(msg: "Select Custom Layout before editing individual displays.")
        }
        guard display.displayClassification != .virtual else {
            throw DisplayError(msg: "Virtual and headless displays cannot be Custom Layout targets.")
        }
        guard let identity = display.persistentIdentity else {
            throw DisplayError(msg: "This display does not have a stable identity yet.")
        }

        initializeCustomDocumentIfNeeded()
        let identities = displaysViewModel.displays.compactMap(\.persistentIdentity)
        var updatedDocument = customDocument
        var updatedOverrides = customSessionOverrides
        let match = PersistentDisplayIdentityMatcher.match(
            current: identity,
            allCurrent: identities,
            settings: updatedDocument.settings
        )

        if enabled {
            updatedOverrides.removeValue(forKey: display.id)
            if case let .unique(index) = match {
                updatedDocument.settings.remove(at: index)
            }
            updatedDocument.settings.removeAll { $0.identity == identity }
        } else if display.displayClassification == .physical,
                  !PersistentDisplayIdentityMatcher.hasCurrentCollision(
                    current: identity,
                    allCurrent: identities
                  ) {
            updatedOverrides.removeValue(forKey: display.id)
            if case let .unique(index) = match {
                updatedDocument.settings[index].isEnabled = false
                updatedDocument.settings[index].lastKnownName = display.name
            } else if let exactIndex = updatedDocument.settings.firstIndex(where: { $0.identity == identity }) {
                updatedDocument.settings[exactIndex].isEnabled = false
                updatedDocument.settings[exactIndex].lastKnownName = display.name
            } else {
                updatedDocument.settings.append(
                    CustomDisplaySetting(identity: identity, isEnabled: false, lastKnownName: display.name)
                )
            }
        } else {
            // Unknown, transient, virtual-like, or ambiguous identities may be edited for this
            // app session, but an Off target must never be replayed after a reconnect/restart.
            updatedOverrides[display.id] = false
        }

        let hasCurrentOnTarget = displaysViewModel.displays.contains { candidate in
            guard candidate.displayClassification != .virtual else { return false }
            if let value = updatedOverrides[candidate.id] { return value }
            guard let candidateIdentity = candidate.persistentIdentity else { return true }
            if case .unique = PersistentDisplayIdentityMatcher.match(
                current: candidateIdentity,
                allCurrent: identities,
                settings: updatedDocument.settings
            ) {
                return false
            }
            return true
        }
        guard hasCurrentOnTarget else {
            throw DisplayError(msg: "Custom Layout must keep at least one target display on.")
        }

        let plan = makePlan(
            mode: .custom,
            customSettings: updatedDocument.settings,
            customSessionOverrides: updatedOverrides
        )
        let busyIDs = plan.enableFirst.union(plan.disableAfterVerification)
        displaysViewModel.markDisplaysBusy(busyIDs)
        do {
            try displaysViewModel.applyDisplayLayoutBatches(
                enableDisplayIDs: plan.enableFirst,
                disableDisplayIDs: plan.disableAfterVerification
            )
            customDocument = updatedDocument
            customSessionOverrides = updatedOverrides
            try store.save(customDocument)
        } catch {
            displaysViewModel.clearDisplaysBusy(busyIDs)
            throw error
        }
        displaysViewModel.clearDisplaysBusy(busyIDs)
        displaysViewModel.fetchDisplays { [weak self] in self?.reconcileCurrentMode() }
    }

    func customTarget(for display: DisplayInfo) -> Bool? {
        if let override = customSessionOverrides[display.id] { return override }
        guard let identity = display.persistentIdentity else { return nil }
        let identities = displaysViewModel.displays.compactMap(\.persistentIdentity)
        guard case .unique = PersistentDisplayIdentityMatcher.match(
            current: identity,
            allCurrent: identities,
            settings: customDocument.settings
        ) else { return true }
        return false
    }

    func hasPersistedCustomOffSetting(for display: DisplayInfo) -> Bool {
        guard let identity = display.persistentIdentity else { return false }
        let identities = displaysViewModel.displays.compactMap(\.persistentIdentity)
        if case .unique = PersistentDisplayIdentityMatcher.match(
            current: identity,
            allCurrent: identities,
            settings: customDocument.settings
        ) {
            return true
        }
        return customDocument.settings.contains { $0.identity == identity }
    }

    func forgetCustomSetting(for display: DisplayInfo) throws {
        try setCustomDisplay(display, enabled: true)
    }

    func forgetMissingCustomSetting(id: Int) {
        guard currentMode == .custom, customDocument.settings.indices.contains(id) else { return }
        customDocument.settings.remove(at: id)
        try? store.save(customDocument)
        objectWillChange.send()
    }

    var missingCustomDisplayRows: [MissingCustomDisplayRow] {
        guard currentMode == .custom else { return [] }
        let identities = displaysViewModel.displays.compactMap(\.persistentIdentity)
        return customDocument.settings.enumerated().compactMap { index, setting in
            let hasUniqueCurrentMatch = identities.contains { current in
                guard case let .unique(settingIndex) = PersistentDisplayIdentityMatcher.match(
                    current: current,
                    allCurrent: identities,
                    settings: customDocument.settings
                ) else { return false }
                return settingIndex == index
            }
            guard !hasUniqueCurrentMatch else { return nil }
            return MissingCustomDisplayRow(
                id: index,
                name: setting.lastKnownName ?? "Previously configured display"
            )
        }
    }

    private func schedulePreviewCommit() {
        shortcutCommitWorkItem?.cancel()
        guard lifecycle == .ready, !isApplying else { return }
        let expectedGeneration = generation
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.lifecycle == .ready,
                  self.generation == expectedGeneration,
                  let mode = self.previewMode else { return }
            self.previewMode = nil
            self.commit(mode)
        }
        shortcutCommitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func commit(_ mode: DisplayLayoutMode) {
        currentMode = mode
        if mode != .hideExternal {
            hideExternalFallbackTarget = nil
        }
        apply(mode: mode)
    }

    private func apply(mode: DisplayLayoutMode) {
        guard lifecycle == .ready else { return }
        if isApplying {
            queuedModeAfterApply = mode
            return
        }

        if mode == .custom {
            initializeCustomDocumentIfNeeded()
        } else if mode == .hideExternal {
            captureHideExternalFallbackTargetIfNeeded()
        }

        fallback = nil
        let applyGeneration = generation

        if mode == .showAll {
            isApplying = true
            isSatisfied = false
            displaysViewModel.resetAllDisplays()
            finishApply(mode: mode, generation: applyGeneration)
            return
        }

        let plan = makePlan(mode: mode)
        fallback = plan.fallback
        if plan.enableFirst.isEmpty, plan.disableAfterVerification.isEmpty {
            isSatisfied = plan.fallback == nil
            onApplyFinished?()
            if previewMode != nil, allHotKeyKeysReleased {
                schedulePreviewCommit()
            }
            return
        }

        isApplying = true
        isSatisfied = false
        let busyIDs = plan.enableFirst.union(plan.disableAfterVerification)
        displaysViewModel.markDisplaysBusy(busyIDs)
        do {
            try displaysViewModel.applyDisplayLayoutBatches(
                enableDisplayIDs: plan.enableFirst,
                disableDisplayIDs: plan.disableAfterVerification
            )
        } catch {
            fallback = .hardwareOperationFailed
        }
        displaysViewModel.clearDisplaysBusy(busyIDs)
        finishApply(mode: mode, generation: applyGeneration)
    }

    private func finishApply(mode: DisplayLayoutMode, generation applyGeneration: UInt64) {
        displaysViewModel.fetchDisplays { [weak self] in
            guard let self, self.lifecycle != .terminating else { return }
            self.isApplying = false
            if self.generation == applyGeneration {
                let verificationPlan = self.makePlan(mode: mode)
                if self.fallback != .hardwareOperationFailed {
                    self.fallback = verificationPlan.fallback
                }
                self.isSatisfied = verificationPlan.enableFirst.isEmpty
                    && verificationPlan.disableAfterVerification.isEmpty
                    && verificationPlan.fallback == nil
            }
            if let queuedMode = self.queuedModeAfterApply {
                self.queuedModeAfterApply = nil
                self.apply(mode: queuedMode)
            } else {
                self.onApplyFinished?()
                if self.previewMode != nil, self.allHotKeyKeysReleased {
                    self.schedulePreviewCommit()
                }
            }
        }
    }

    private func makePlan(
        mode: DisplayLayoutMode,
        customSettings: [CustomDisplaySetting]? = nil,
        customSessionOverrides: [DisplayID: Bool]? = nil
    ) -> DisplayLayoutPlan {
        DisplayLayoutPolicy.plan(
            mode: mode,
            displays: displaysViewModel.displays.map {
                LayoutDisplaySnapshot(
                    id: $0.id,
                    identity: $0.persistentIdentity,
                    isBuiltIn: $0.isBuiltIn,
                    isActive: $0.state == .active,
                    isAvailable: $0.isAvailable,
                    classification: $0.displayClassification
                )
            },
            customSettings: customSettings ?? customDocument.settings,
            customSessionOverrides: customSessionOverrides ?? self.customSessionOverrides,
            hideExternalFallbackTarget: hideExternalFallbackTarget
        )
    }

    private func initializeCustomDocumentIfNeeded() {
        let originalDocument = customDocument
        customDocument.version = 2
        customDocument.hasBeenInitialized = true
        customDocument.settings.removeAll { $0.isEnabled }
        if customDocument != originalDocument {
            try? store.save(customDocument)
        }
    }

    private func captureHideExternalFallbackTargetIfNeeded() {
        let hasUsableBuiltIn = displaysViewModel.displays.contains {
            $0.isBuiltIn && $0.displayClassification == .physical && $0.isAvailable
        }
        guard !hasUsableBuiltIn, hideExternalFallbackTarget == nil else { return }
        hideExternalFallbackTarget = Set(displaysViewModel.displays.compactMap { display in
            guard !display.isBuiltIn,
                  display.displayClassification == .physical,
                  display.state == .active else { return nil }
            return display.persistentIdentity
        })
    }
}
