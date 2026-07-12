import Foundation

public enum DisplayLayoutSelectionPolicy {
    public static func nextHotKeyPreview(
        hasLayoutInteraction: Bool,
        cursorMode: DisplayLayoutMode?,
        currentMode: DisplayLayoutMode
    ) -> DisplayLayoutMode {
        guard hasLayoutInteraction || cursorMode != nil else { return .showAll }
        return (cursorMode ?? currentMode).next
    }
}

public enum DisplayLayoutPolicy {
    public static func plan(
        mode: DisplayLayoutMode,
        displays: [LayoutDisplaySnapshot],
        customSettings: [CustomDisplaySetting] = [],
        customSessionOverrides: [DisplayID: Bool] = [:],
        hideExternalFallbackTarget: Set<PersistentDisplayIdentity>? = nil
    ) -> DisplayLayoutPlan {
        switch mode {
        case .showAll:
            let enable = Set(displays.filter { $0.classification != .virtual && $0.isAvailable && !$0.isActive }.map(\.id))
            return DisplayLayoutPlan(enableFirst: enable)

        case .hideExternal:
            return hideExternalPlan(displays: displays, fallbackTarget: hideExternalFallbackTarget)

        case .custom:
            return customPlan(displays: displays, settings: customSettings, sessionOverrides: customSessionOverrides)
        }
    }

    private static func hideExternalPlan(
        displays: [LayoutDisplaySnapshot],
        fallbackTarget: Set<PersistentDisplayIdentity>?
    ) -> DisplayLayoutPlan {
        guard let builtIn = displays.first(where: { $0.isBuiltIn && $0.classification == .physical && $0.isAvailable }) else {
            let activePhysical = displays.filter { $0.classification == .physical && $0.isActive }
            guard let fallbackTarget else {
                return DisplayLayoutPlan(
                    fallback: .preservingSafetyDisplays(Set(activePhysical.map(\.id))),
                    shouldRetryWhenTopologyChanges: true
                )
            }

            let targetIDs = Set(displays.compactMap { display -> DisplayID? in
                guard display.classification == .physical,
                      let identity = display.identity,
                      fallbackTarget.contains(identity) else { return nil }
                return display.id
            })
            let enable = Set(displays.filter { targetIDs.contains($0.id) && !$0.isActive && $0.isAvailable }.map(\.id))
            let disable = Set(displays.filter { $0.classification == .physical && $0.isActive && !targetIDs.contains($0.id) }.map(\.id))
            return DisplayLayoutPlan(
                enableFirst: enable,
                disableAfterVerification: targetIDs.isEmpty ? [] : disable,
                fallback: .waitingForBuiltIn,
                shouldRetryWhenTopologyChanges: true
            )
        }

        let enable: Set<DisplayID> = builtIn.isActive ? [] : [builtIn.id]
        let disable = Set(displays.filter { !$0.isBuiltIn && $0.classification == .physical && $0.isActive }.map(\.id))
        return DisplayLayoutPlan(enableFirst: enable, disableAfterVerification: disable)
    }

    private static func customPlan(
        displays: [LayoutDisplaySnapshot],
        settings: [CustomDisplaySetting],
        sessionOverrides: [DisplayID: Bool]
    ) -> DisplayLayoutPlan {
        let identities = displays.compactMap(\.identity)
        var onTargets = Set<DisplayID>()
        var offTargets = Set<DisplayID>()

        for display in displays where display.classification != .virtual {
            if let override = sessionOverrides[display.id] {
                if override {
                    onTargets.insert(display.id)
                } else {
                    offTargets.insert(display.id)
                }
                continue
            }
            guard let identity = display.identity else {
                onTargets.insert(display.id)
                continue
            }
            switch PersistentDisplayIdentityMatcher.match(current: identity, allCurrent: identities, settings: settings) {
            case let .unique(index):
                if settings[index].isEnabled {
                    onTargets.insert(display.id)
                } else {
                    offTargets.insert(display.id)
                }
            case .unknownOrAmbiguous:
                onTargets.insert(display.id)
            }
        }

        let availableOnTargets = displays.filter { onTargets.contains($0.id) && $0.isAvailable }
        guard !availableOnTargets.isEmpty else {
            let activePhysical = Set(displays.filter { $0.classification == .physical && $0.isActive }.map(\.id))
            return DisplayLayoutPlan(
                fallback: activePhysical.isEmpty ? .waitingForCustomTargets : .preservingSafetyDisplays(activePhysical),
                shouldRetryWhenTopologyChanges: true
            )
        }

        let enable = Set(availableOnTargets.filter { !$0.isActive }.map(\.id))
        let disable = Set(displays.filter { offTargets.contains($0.id) && $0.isActive }.map(\.id))
        return DisplayLayoutPlan(enableFirst: enable, disableAfterVerification: disable)
    }
}
