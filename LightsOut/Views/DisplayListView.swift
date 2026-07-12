import SwiftUI

let enableSpinnerHoldDuration: TimeInterval = 2.0

struct DisplayListView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var layoutController: DisplayLayoutController

    var body: some View {
        VStack(spacing: 0) {
            DisplayLayoutSection()

            Divider()
                .padding(.vertical, 8)

            Text("Displays")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            if viewModel.displays.isEmpty && !viewModel.hasCompletedInitialRefresh {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Loading Displays")
                        .font(.headline)

                    Text("Checking connected displays...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.displays.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "display")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No Displays")
                        .font(.headline)

                    Text("Connect a display to manage it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        ForEach(viewModel.displays) { display in
                            DisplayControlView(display: display)
                        }

                        ForEach(layoutController.missingCustomDisplayRows) { row in
                            MissingCustomDisplayView(row: row)
                        }
                    }
                }
            }
        }
    }

    private var hasActiveExternals: Bool {
        viewModel.displays.contains { !$0.isBuiltIn && $0.state == .active }
    }

    private var hasDisabledExternals: Bool {
        let externals = viewModel.displays.filter { !$0.isBuiltIn }
        return !externals.isEmpty && externals.allSatisfy { $0.state.isOff }
    }

    private var hasDisabledDisplays: Bool {
        viewModel.displays.contains { $0.state.isOff }
    }

    private var hasActiveBuiltInDisplay: Bool {
        viewModel.displays.contains { $0.isBuiltIn && $0.state == .active }
    }
}

struct MissingCustomDisplayView: View {
    @EnvironmentObject var layoutController: DisplayLayoutController
    let row: DisplayLayoutController.MissingCustomDisplayRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Target: Off · Unavailable")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)

            Button {
                layoutController.forgetMissingCustomSetting(id: row.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Forget this saved Off target. It will default to On if it reconnects.")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .opacity(0.65)
        .help("This unavailable display is remembered only because Custom saved it as Off.")
    }
}

struct DisplayLayoutSection: View {
    @EnvironmentObject var controller: DisplayLayoutController

    var body: some View {
        VStack(spacing: 2) {
            Text("Display Layout")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            DisplayLayoutRow(mode: .showAll, title: "Show All Displays", icon: "display.2")
            DisplayLayoutRow(mode: .hideExternal, title: "Hide External Displays", icon: "laptopcomputer")
            DisplayLayoutRow(mode: .custom, title: "Custom Layout", icon: "switch.2")

            if controller.lifecycle == .starting {
                Text("Preparing displays…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
            } else if let fallback = controller.fallback {
                Text(fallbackLabel(fallback))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
            }
        }
    }

    private func fallbackLabel(_ fallback: LayoutFallback) -> String {
        switch fallback {
        case .waitingForBuiltIn: "Waiting for the built-in display"
        case .waitingForCustomTargets: "Waiting for a Custom target display"
        case .preservingSafetyDisplays: "Temporarily preserving a safety display"
        case .hardwareOperationFailed: "The requested layout could not be fully applied"
        }
    }
}

struct DisplayLayoutRow: View {
    @EnvironmentObject var controller: DisplayLayoutController
    let mode: DisplayLayoutMode
    let title: String
    let icon: String
    @State private var isHovered = false

    private var isPreview: Bool { controller.previewMode == mode }
    private var isCurrent: Bool { controller.currentMode == mode }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(isPreview ? Color.accentColor : .secondary)

            Text(title)
                .font(.body.weight(.medium))

            Spacer(minLength: 12)

            if controller.isApplying && isCurrent {
                ProgressView().controlSize(.small)
            } else if isPreview {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else if isCurrent {
                Image(systemName: controller.isSatisfied ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(controller.isSatisfied ? Color.accentColor : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isPreview ? Color.accentColor.opacity(0.16) : (isHovered ? Color.white.opacity(0.1) : .clear))
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture { controller.selectMode(mode) }
        .disabled(controller.lifecycle == .terminating)
    }
}

struct HideExternalsButton: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var errorHandler: ErrorHandler
    let isEnabled: Bool
    @State private var isHovered = false
    @State private var isBusy = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                } else {
                    Image(systemName: "display.2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)

            Text("Hide External Displays")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            hideExternalDisplays()
        }
        .disabled(isBusy || !isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func hideExternalDisplays() {
        guard !isBusy, isEnabled else { return }

        let builtInIsActive = viewModel.displays.contains { $0.isBuiltIn && $0.state == .active }

        guard builtInIsActive else {
            errorHandler.handle(error: DisplayError(msg: "Cannot hide external displays — no built-in display is visible."))
            return
        }

        let externalActive = viewModel.displays.filter { !$0.isBuiltIn && $0.state == .active }

        guard !externalActive.isEmpty else { return }

        let busyDisplayIDs = Set(externalActive.map(\.id))
        isBusy = true
        viewModel.markDisplaysBusy(busyDisplayIDs)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for display in externalActive {
                do {
                    try viewModel.disconnectDisplay(display: display)
                } catch {
                    errorHandler.handle(error: displayError(from: error))
                    viewModel.fetchDisplays()
                    viewModel.clearDisplaysBusy(busyDisplayIDs)
                    isBusy = false
                    return
                }
            }
            viewModel.fetchDisplays()
            viewModel.clearDisplaysBusy(busyDisplayIDs)
            isBusy = false
        }
    }
}

struct ShowExternalsButton: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var errorHandler: ErrorHandler
    @State private var isHovered = false
    @State private var isBusy = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                } else {
                    Image(systemName: "display.2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)

            Text("Show External Displays")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            showExternalDisplays()
        }
        .disabled(isBusy)
    }

    private func showExternalDisplays() {
        guard !isBusy else { return }

        let externalDisabled = viewModel.displays.filter { !$0.isBuiltIn && $0.state.isOff }
        guard !externalDisabled.isEmpty else { return }

        let busyDisplayIDs = Set(externalDisabled.map(\.id))
        isBusy = true
        viewModel.markDisplaysBusy(busyDisplayIDs)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for display in externalDisabled {
                do {
                    try viewModel.turnOnDisplay(display: display)
                } catch {
                    errorHandler.handle(error: displayError(from: error))
                    viewModel.fetchDisplays()
                    viewModel.clearDisplaysBusy(busyDisplayIDs)
                    isBusy = false
                    return
                }
            }
            viewModel.fetchDisplays()
            DispatchQueue.main.asyncAfter(deadline: .now() + enableSpinnerHoldDuration) {
                viewModel.clearDisplaysBusy(busyDisplayIDs)
                isBusy = false
            }
        }
    }
}

struct ShowAllDisplaysButton: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    let isEnabled: Bool
    @State private var isHovered = false
    @State private var isBusy = false
    @State private var showResetPopup = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)

            Text("Show All Displays")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            showAllDisplays()
        }
        .disabled(isBusy || !isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .overlay(alignment: .bottom) {
            if showResetPopup {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Show All Displays")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .offset(y: 44)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showResetPopup = false
                    }
                }
            }
        }
    }

    private func showAllDisplays() {
        guard !isBusy, isEnabled else { return }

        let busyDisplayIDs = Set(viewModel.displays.map(\.id))
        isBusy = true
        viewModel.markDisplaysBusy(busyDisplayIDs)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            viewModel.resetAllDisplays()
            DispatchQueue.main.asyncAfter(deadline: .now() + enableSpinnerHoldDuration) {
                viewModel.clearDisplaysBusy(busyDisplayIDs)
                showResetPopup = true
                isBusy = false
            }
        }
    }
}

struct DisplayControlView: View {
    @ObservedObject var display: DisplayInfo
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var errorHandler: ErrorHandler
    @EnvironmentObject var layoutController: DisplayLayoutController

    @State private var isHovered = false
    @State private var isBusy = false

    private var isOn: Bool {
        layoutController.currentMode == .custom
            ? (layoutController.customTarget(for: display) ?? (display.state == .active))
            : display.state == .active
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if isBusy || viewModel.busyDisplayIDs.contains(display.id) || display.state == .pending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isOn ? .white : .secondary)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isOn ? .white : .secondary)
                }
            }
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(isOn ? Color.accentColor : Color.white.opacity(0.06))
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(display.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isOn ? .primary : .secondary)

                HStack(spacing: 6) {
                    if display.isPrimary {
                        Text("Primary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            if layoutController.currentMode == .custom,
               layoutController.hasPersistedCustomOffSetting(for: display) {
                Button {
                    forgetSavedCustomSetting()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Forget the saved Off target and return this display to the default On state.")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handlePress()
        }
        .disabled(
            display.state == .pending
                || isBusy
                || layoutController.currentMode != .custom
                || layoutController.isApplying
                || display.displayClassification == .virtual
        )
        .opacity(layoutController.currentMode == .custom && display.displayClassification != .virtual ? 1 : 0.55)
        .help(displayHelp)
    }

    private func handlePress() {
        if display.state == .pending || isBusy { return }

        let canAttemptRecoveryWhileHidden = display.state.isOff && display.isUserHidden

        guard display.isAvailable || !display.state.isOff || canAttemptRecoveryWhileHidden else {
            errorHandler.handle(error: DisplayError(msg: "Display '\(display.name)' is no longer available."))
            viewModel.fetchDisplays()
            return
        }

        let requestedTarget = !isOn
        let isEnablingDisplay = requestedTarget
        let isReactivatingHiddenUnavailableDisplay = display.state.isOff && display.isUserHidden && !display.isAvailable
        isBusy = true
        viewModel.markDisplaysBusy([display.id])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            do {
                try layoutController.setCustomDisplay(display, enabled: requestedTarget)
                if isReactivatingHiddenUnavailableDisplay {
                    errorHandler.inform(
                        title: "Display Reactivation Pending",
                        message: "LightsOut will show '\(display.name)' again when it becomes available on the expected input."
                    )
                }
            } catch {
                errorHandler.handle(error: displayError(from: error))
            }
            viewModel.fetchDisplays()
            let spinnerHoldDuration = isEnablingDisplay ? enableSpinnerHoldDuration : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + spinnerHoldDuration) {
                viewModel.clearDisplaysBusy([display.id])
                isBusy = false
            }
        }
    }

    private func forgetSavedCustomSetting() {
        do {
            try layoutController.forgetCustomSetting(for: display)
        } catch {
            errorHandler.handle(error: displayError(from: error))
        }
    }

    private var statusLabel: String {
        if display.displayClassification == .virtual {
            return "Virtual display · Not configurable"
        }
        if layoutController.currentMode == .custom,
           let target = layoutController.customTarget(for: display) {
            let actual: String
            switch display.state {
            case .disconnected: actual = display.isAvailable ? "Hidden" : "Unavailable"
            case .active: actual = "Visible"
            case .pending: actual = "Applying"
            }
            return "Target: \(target ? "On" : "Off") · \(actual)"
        }

        switch display.state {
        case .disconnected:
            return display.isAvailable ? "Hidden" : "Unavailable"
        case .active:
            return "Visible"
        case .pending:
            return "Applying change"
        }
    }

    private var displayHelp: String {
        if display.displayClassification == .virtual {
            return "Virtual and headless displays are excluded from Custom Layout and safety checks."
        }
        return layoutController.currentMode == .custom
            ? "Edit this Custom Layout target"
            : "Select Custom Layout to edit individual displays"
    }
}

private func displayError(from error: Error) -> DisplayError {
    error as? DisplayError ?? DisplayError(msg: error.localizedDescription)
}

#Preview("Display List") {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    DisplayListView()
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
        .frame(width: 372)
        .padding()
}

#Preview("Display Control — Active") {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    DisplayControlView(display: DisplayInfo(id: 1, name: "LG Ultrafine 5K", state: .active, isPrimary: true, isBuiltIn: false))
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
        .frame(width: 372)
        .padding()
}

#Preview("Display Control — Disconnected") {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    DisplayControlView(display: DisplayInfo(id: 2, name: "Dell U2723QE", state: .disconnected, isPrimary: false, isBuiltIn: false))
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
        .frame(width: 372)
        .padding()
}

#Preview("Display Control — Unavailable") {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    DisplayControlView(display: DisplayInfo(id: 3, name: "Studio Display", state: .disconnected, isPrimary: false, isBuiltIn: false, isUserHidden: true, isAvailable: false))
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
        .frame(width: 372)
        .padding()
}
