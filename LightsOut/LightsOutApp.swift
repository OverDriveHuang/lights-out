import AppKit
import CoreGraphics
import SwiftUI

private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@main
struct LightsOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private enum PanelPresentationSource {
        case mouse
        case hotKey
        case postDisplayChange
    }

    private enum PanelCloseReason {
        case userDismissed
        case systemRelocation
        case appTermination
    }

    var statusItem: NSStatusItem!
    private var menuPanel: MenuPanel?
    var eventMonitor: Any?
    var screenParametersObserver: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var topologyEventBurst: DisplayTopologyEventBurst?
    private var topologyReconcileWorkItem: DispatchWorkItem?
    private var topologyReconcileGeneration: UInt64 = 0
    private var topologyReconcileInProgress = false
    private var topologyEventPendingAfterMutation = false
    let displaysViewModel = DisplaysViewModel(fetchOnInit: false)
    lazy var layoutController = DisplayLayoutController(displaysViewModel: displaysViewModel)
    var contextMenuManager: ContextMenuManager!
    private var displayLayoutHotKey: GlobalDisplayLayoutHotKey?
    private var preservedPopoverState: PreservedPopoverState?
    private var shouldReopenPanelAfterDisplayChange = false
    private let topologyQuietPeriod: TimeInterval = 0.3
    private let topologyMaximumDelay: TimeInterval = 2.0

    private struct PreservedPopoverState {
        let displayID: CGDirectDisplayID
        let originOffset: NSPoint
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "LightsOut")
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        contextMenuManager = ContextMenuManager(statusItem: statusItem)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                if self?.menuPanel?.isVisible == true {
                    self?.closeMenuPanel(reason: .userDismissed)
                }
            }
        }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.scheduleTopologyReconcile()
                self.restorePopoverPositionIfNeeded()
            }
        }

        displaysViewModel.willChangeDisplays = { [weak self] disablingDisplayIDs in
            self?.preparePopoverForDisplayChange(disablingDisplayIDs: disablingDisplayIDs)
        }

        displaysViewModel.didChangeDisplays = { [weak self] in
            self?.scheduleTopologyReconcile()
            self?.restorePopoverPositionIfNeeded()
            DispatchQueue.main.async { [weak self] in
                self?.restorePopoverPositionIfNeeded()
            }
        }
        displaysViewModel.didObserveDisplayReconfiguration = { [weak self] in
            self?.scheduleTopologyReconcile()
        }

        layoutController.onRequestPanelPresentation = { [weak self] in
            self?.showMenuPanelFromHotKey()
        }
        layoutController.onApplyFinished = { [weak self] in
            self?.resumeTopologyReconcileAfterMutationIfNeeded()
        }
        displayLayoutHotKey = GlobalDisplayLayoutHotKey(
            onPressed: { [weak self] in self?.layoutController.handleHotKeyPressed() },
            onCombinationReleased: { [weak self] in self?.layoutController.handleHotKeyCombinationReleased() },
            onAllKeysReleased: { [weak self] in self?.layoutController.handleAllHotKeyKeysReleased() }
        )
        if displayLayoutHotKey == nil {
            print("LightsOut failed to register Control-Command-P Display Layout hotkey.")
        }

        displaysViewModel.restoreAllDisplays()
        layoutController.finishStartup()
        registerWorkspaceObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        layoutController.terminate()
        cancelTopologyReconcile()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        closeMenuPanel(reason: .appTermination)
        displaysViewModel.restoreAllDisplays()
    }

    private func registerWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let willSleepNames: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification
        ]
        let didWakeNames: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]

        for name in willSleepNames {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.cancelTopologyReconcile()
                    self?.layoutController.suspend()
                }
            })
        }
        for name in didWakeNames {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleTopologyReconcile() }
            })
        }
    }

    private func scheduleTopologyReconcile() {
        guard layoutController.lifecycle != .terminating else { return }
        if topologyReconcileInProgress
            || layoutController.isApplying
            || !displaysViewModel.busyDisplayIDs.isEmpty {
            topologyEventPendingAfterMutation = true
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if topologyEventBurst == nil {
            topologyEventBurst = DisplayTopologyEventBurst(firstEventTime: now)
            topologyReconcileGeneration &+= 1
        } else {
            topologyEventBurst?.recordEvent(at: now)
        }

        guard let burst = topologyEventBurst else { return }
        let generation = topologyReconcileGeneration
        let delay = max(0, burst.fireTime(
            quietPeriod: topologyQuietPeriod,
            maximumDelay: topologyMaximumDelay
        ) - now)
        topologyReconcileWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, generation == self.topologyReconcileGeneration else { return }
            self.performTopologyReconcile(generation: generation)
        }
        topologyReconcileWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func performTopologyReconcile(generation: UInt64) {
        topologyReconcileWorkItem = nil
        topologyEventBurst = nil
        guard !layoutController.isApplying, displaysViewModel.busyDisplayIDs.isEmpty else {
            topologyEventPendingAfterMutation = true
            return
        }
        topologyReconcileInProgress = true

        _ = displaysViewModel.performPendingReconfigurationSafetyRestoreIfNeeded()
        displaysViewModel.fetchDisplays { [weak self] in
            guard let self, generation == self.topologyReconcileGeneration else { return }

            if !self.displaysViewModel.hasActiveConfirmedPhysicalDisplay() {
                self.displaysViewModel.restoreAllDisplays()
                self.displaysViewModel.fetchDisplays { [weak self] in
                    guard let self, generation == self.topologyReconcileGeneration else { return }
                    self.finishTopologyReconcile()
                }
            } else {
                self.finishTopologyReconcile()
            }
        }
    }

    private func finishTopologyReconcile() {
        if layoutController.lifecycle == .suspended {
            layoutController.resumeAndReconcile()
        } else {
            layoutController.reconcileCurrentMode()
        }
        if !layoutController.isApplying {
            completeTopologyReconcileCycle()
        }
    }

    private func resumeTopologyReconcileAfterMutationIfNeeded() {
        completeTopologyReconcileCycle()
    }

    private func completeTopologyReconcileCycle() {
        topologyReconcileInProgress = false
        guard topologyEventPendingAfterMutation else { return }
        topologyEventPendingAfterMutation = false
        scheduleTopologyReconcile()
    }

    private func cancelTopologyReconcile() {
        topologyReconcileGeneration &+= 1
        topologyReconcileWorkItem?.cancel()
        topologyReconcileWorkItem = nil
        topologyEventBurst = nil
        topologyReconcileInProgress = false
        topologyEventPendingAfterMutation = false
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            contextMenuManager.showContextMenu()
        } else {
            toggleMenuPanel(sender)
        }
    }

    func toggleMenuPanel(_ sender: NSStatusBarButton) {
        if menuPanel?.isVisible == true {
            closeMenuPanel(reason: .userDismissed)
        } else {
            showMenuPanel(anchoredTo: sender, source: .mouse)
        }
    }

    private func preparePopoverForDisplayChange(disablingDisplayIDs: Set<CGDirectDisplayID>) {
        guard let menuPanel,
              menuPanel.isVisible,
              let screen = menuPanel.screen else {
            preservedPopoverState = nil
            return
        }

        let displayID = screen.displayID
        if disablingDisplayIDs.contains(displayID) {
            shouldReopenPanelAfterDisplayChange = true
            closeMenuPanel(reason: .systemRelocation)
            preservedPopoverState = nil
            return
        }

        preservedPopoverState = PreservedPopoverState(
            displayID: displayID,
            originOffset: NSPoint(
                x: menuPanel.frame.origin.x - screen.frame.origin.x,
                y: menuPanel.frame.origin.y - screen.frame.origin.y
            )
        )
    }

    private func restorePopoverPositionIfNeeded() {
        if shouldReopenPanelAfterDisplayChange,
           menuPanel?.isVisible != true,
           let button = statusItem.button {
            shouldReopenPanelAfterDisplayChange = false
            showMenuPanel(anchoredTo: button, source: .postDisplayChange)
            return
        }
        guard let menuPanel,
              menuPanel.isVisible,
              let preservedPopoverState,
              let screen = NSScreen.screens.first(where: { $0.displayID == preservedPopoverState.displayID }) else {
            self.preservedPopoverState = nil
            return
        }

        let desiredOrigin = NSPoint(
            x: screen.frame.origin.x + preservedPopoverState.originOffset.x,
            y: screen.frame.origin.y + preservedPopoverState.originOffset.y
        )

        guard menuPanel.frame.origin != desiredOrigin else { return }

        var frame = menuPanel.frame
        frame.origin = desiredOrigin
        menuPanel.setFrame(frame, display: false)
        menuPanel.orderFrontRegardless()
    }

    private func showMenuPanelFromHotKey() {
        guard menuPanel?.isVisible != true, let button = statusItem.button else { return }
        showMenuPanel(anchoredTo: button, source: .hotKey)
    }

    private func showMenuPanel(anchoredTo button: NSStatusBarButton, source: PanelPresentationSource) {
        let contentView = MenuBarView()
            .environmentObject(displaysViewModel)
            .environmentObject(layoutController)
            .withErrorHandling()

        let hostingController = NSHostingController(rootView: contentView)
        hostingController.loadView()
        hostingController.view.layoutSubtreeIfNeeded()
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let fittingSize = hostingController.view.fittingSize
        let panelSize = NSSize(
            width: max(372, fittingSize.width),
            height: max(240, fittingSize.height)
        )

        let panel = MenuPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentViewController = hostingController
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.cornerRadius = 24
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true
        panel.invalidateShadow()
        panel.setFrameOrigin(panelOrigin(for: button, panelSize: panelSize))

        menuPanel = panel

        if source == .mouse {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.orderFrontRegardless()
        if source == .mouse {
            panel.makeKey()
        }
        preservedPopoverState = nil
        DispatchQueue.main.async { [weak self] in
            self?.displaysViewModel.fetchDisplays()
        }
    }

    private func closeMenuPanel(reason: PanelCloseReason) {
        if reason == .userDismissed {
            layoutController.cancelPreview()
        }
        menuPanel?.orderOut(nil)
        menuPanel?.close()
        menuPanel = nil
        preservedPopoverState = nil
    }

    private func panelOrigin(for button: NSStatusBarButton, panelSize: NSSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        })
            ?? button.window?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visibleFrame = targetScreen?.visibleFrame ?? .zero
        let edgeInset: CGFloat = 12

        return NSPoint(
            x: visibleFrame.maxX - panelSize.width - edgeInset,
            y: visibleFrame.maxY - panelSize.height - edgeInset
        )
    }
}

#Preview {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    MenuBarView()
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
}
