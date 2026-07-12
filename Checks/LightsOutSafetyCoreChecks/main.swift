import LightsOutSafetyCore
import Foundation

@main
struct LightsOutSafetyCoreChecks {
    static func main() {
        testRestoreCandidatesMergeSourcesInStableOrder()
        testRestoreCandidatesUseFallbackOneOnlyForRestoreList()
        testRestoreCandidatesDoNotReenableAlreadyActiveSavedDisplay()
        testDisconnectRejectsInactiveTarget()
        testDisconnectRejectsLastActiveDisplay()
        testDisconnectAllowsActiveTargetWhenAnotherDisplayRemainsActive()
        testVirtualDisplayCannotProtectLastPhysicalDisplay()
        testBatchDisconnectRequiresRemainingPhysicalDisplay()
        testBatchDisconnectAllowsWhenPhysicalDisplayRemains()
        testBatchDisconnectRejectsInactiveTarget()
        testDisplayLayoutModeCyclesInProductOrder()
        testFirstHotKeyShowsAllWithoutPriorInteraction()
        testMouseSelectionEstablishesHotKeyCursor()
        testIdentityCollisionDoesNotRestoreOff()
        testUniqueColorSyncIdentityRestoresSetting()
        testEDIDIdentityFallbackRestoresSetting()
        testDuplicateStoredIdentityDoesNotRestoreOff()
        testZeroSerialWithoutUUIDIsAmbiguous()
        testHistoricalCollisionDoesNotBecomeUniqueLater()
        testCustomLayoutDocumentRoundTripsLastKnownDescriptor()
        testCustomStoreMigratesV1ByDroppingOnRecords()
        testCustomStorePersistsOnlyOffRecords()
        testHideExternalEnablesBuiltInBeforeDisablingExternals()
        testHideExternalWithActiveBuiltInDisablesOnlyPhysicalExternals()
        testHideExternalWithoutBuiltInInitiallyPreservesActivePhysicalDisplays()
        testHideExternalMissingCapturedTargetDoesNotDisableFallbackDisplay()
        testHideExternalRestoresCapturedTargetWithoutBuiltIn()
        testShowAllEnablesPhysicalAndUnknownButExcludesVirtual()
        testCustomUniqueTargetsEnableThenDisable()
        testCustomUnknownDisplayDefaultsOn()
        testCustomExcludesVirtualDisplay()
        testCustomAmbiguousDisplayDefaultsOn()
        testCustomAmbiguousDisplayCanUseSessionOnlyOffOverride()
        testCustomOffOnlyStorePreservesActivePhysicalFallbackWhenDefaultOnExternalIsMissing()
        testBeginConfigurationDoesNotTriggerRestore()
        testExternalRemovalWithDisconnectedBuiltInTriggersRestore()
        testVirtualDisplayDoesNotBlockDisconnectedBuiltInRestore()
        testPhysicalExternalDisplayBlocksDisconnectedBuiltInRestore()
        testBuiltInDisplayBlocksUnnecessaryRestore()
        testVirtualOnlyDesktopTriggersRestore()
        testDisplayAddDoesNotAutoRedisconnectOrRestoreByItself()
        testTopologyBurstUsesTrailingEdgeAfterSingleEvent()
        testTopologyBurstResetsTrailingEdgeForEventStorm()
        testTopologyBurstCapsContinuousEventStorm()
        print("LightsOutSafetyCoreChecks passed")
    }
}

private func testTopologyBurstUsesTrailingEdgeAfterSingleEvent() {
    let burst = DisplayTopologyEventBurst(firstEventTime: 10)
    expectEqual(burst.fireTime(quietPeriod: 0.3, maximumDelay: 2), 10.3)
}

private func testTopologyBurstResetsTrailingEdgeForEventStorm() {
    var burst = DisplayTopologyEventBurst(firstEventTime: 10)
    burst.recordEvent(at: 10.1)
    burst.recordEvent(at: 10.25)
    expectEqual(burst.fireTime(quietPeriod: 0.3, maximumDelay: 2), 10.55)
}

private func testTopologyBurstCapsContinuousEventStorm() {
    var burst = DisplayTopologyEventBurst(firstEventTime: 10)
    burst.recordEvent(at: 11.9)
    burst.recordEvent(at: 12.1)
    expectEqual(burst.fireTime(quietPeriod: 0.3, maximumDelay: 2), 12.0)
}

private func testRestoreCandidatesMergeSourcesInStableOrder() {
    let snapshot = RestoreCandidateSnapshot(
        persistedDisabledDisplayIDs: [9, 3],
        disconnectedDisplayIDs: [4, 3],
        onlineDisplayIDs: [1, 4, 6],
        activeDisplayIDs: [6],
        savedBuiltInDisplayID: 2,
        fallbackDisplayID: 1,
        builtInFallbackDisplayIDs: [2, 5]
    )

    expectEqual(RestoreCandidateAggregator.candidateIDs(from: snapshot), [3, 9, 4, 1, 2, 5])
}

private func testRestoreCandidatesUseFallbackOneOnlyForRestoreList() {
    let snapshot = RestoreCandidateSnapshot(
        persistedDisabledDisplayIDs: [],
        disconnectedDisplayIDs: [],
        onlineDisplayIDs: [],
        activeDisplayIDs: [],
        savedBuiltInDisplayID: nil,
        fallbackDisplayID: 1,
        builtInFallbackDisplayIDs: []
    )

    expectEqual(RestoreCandidateAggregator.candidateIDs(from: snapshot), [1])
}

private func testRestoreCandidatesDoNotReenableAlreadyActiveSavedDisplay() {
    let snapshot = RestoreCandidateSnapshot(
        persistedDisabledDisplayIDs: [],
        disconnectedDisplayIDs: [],
        onlineDisplayIDs: [1, 4],
        activeDisplayIDs: [1, 4],
        savedBuiltInDisplayID: 1,
        fallbackDisplayID: 1,
        builtInFallbackDisplayIDs: [1]
    )

    expectEqual(RestoreCandidateAggregator.candidateIDs(from: snapshot), [])
}

private func testDisconnectRejectsInactiveTarget() {
    let result = DisplaySafetyPolicy.disconnectPreflight(
        targetID: 1,
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: false),
            DisplaySafetySnapshot(id: 2, isActive: true)
        ]
    )

    expectEqual(result, .rejected(.targetNotActive))
}

private func testDisconnectRejectsLastActiveDisplay() {
    let result = DisplaySafetyPolicy.disconnectPreflight(
        targetID: 1,
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: true),
            DisplaySafetySnapshot(id: 2, isActive: false)
        ]
    )

    expectEqual(result, .rejected(.lastActivePhysicalDisplay))
}

private func testVirtualDisplayCannotProtectLastPhysicalDisplay() {
    let result = DisplaySafetyPolicy.disconnectPreflight(
        targetID: 1,
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: true, classification: .physical),
            DisplaySafetySnapshot(id: 2, isActive: true, classification: .virtual)
        ]
    )

    expectEqual(result, .rejected(.lastActivePhysicalDisplay))
}

private func testBatchDisconnectRequiresRemainingPhysicalDisplay() {
    let result = DisplaySafetyPolicy.disconnectBatchPreflight(
        targetIDs: [1, 2],
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: true, classification: .physical),
            DisplaySafetySnapshot(id: 2, isActive: true, classification: .physical),
            DisplaySafetySnapshot(id: 3, isActive: true, classification: .unknown)
        ]
    )

    expectEqual(result, .rejected(.lastActivePhysicalDisplay))
}

private func testBatchDisconnectAllowsWhenPhysicalDisplayRemains() {
    let result = DisplaySafetyPolicy.disconnectBatchPreflight(
        targetIDs: [1, 2],
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: true, classification: .physical),
            DisplaySafetySnapshot(id: 2, isActive: true, classification: .physical),
            DisplaySafetySnapshot(id: 3, isActive: true, classification: .physical)
        ]
    )

    expectEqual(result, .allowed)
}

private func testBatchDisconnectRejectsInactiveTarget() {
    let result = DisplaySafetyPolicy.disconnectBatchPreflight(
        targetIDs: [1, 2],
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: true),
            DisplaySafetySnapshot(id: 2, isActive: false),
            DisplaySafetySnapshot(id: 3, isActive: true)
        ]
    )

    expectEqual(result, .rejected(.targetNotActive))
}

private func testDisplayLayoutModeCyclesInProductOrder() {
    expectEqual(DisplayLayoutMode.showAll.next, .hideExternal)
    expectEqual(DisplayLayoutMode.hideExternal.next, .custom)
    expectEqual(DisplayLayoutMode.custom.next, .showAll)
}

private func testFirstHotKeyShowsAllWithoutPriorInteraction() {
    expectEqual(
        DisplayLayoutSelectionPolicy.nextHotKeyPreview(
            hasLayoutInteraction: false,
            cursorMode: nil,
            currentMode: .showAll
        ),
        .showAll
    )
}

private func testMouseSelectionEstablishesHotKeyCursor() {
    expectEqual(
        DisplayLayoutSelectionPolicy.nextHotKeyPreview(
            hasLayoutInteraction: true,
            cursorMode: .hideExternal,
            currentMode: .hideExternal
        ),
        .custom
    )
}

private func testIdentityCollisionDoesNotRestoreOff() {
    let identity = externalIdentity(uuid: "collision")
    let settings = [CustomDisplaySetting(identity: identity, isEnabled: false)]

    let result = PersistentDisplayIdentityMatcher.match(
        current: identity,
        allCurrent: [identity, identity],
        settings: settings
    )

    expectEqual(result, .unknownOrAmbiguous)
}

private func testUniqueColorSyncIdentityRestoresSetting() {
    let identity = externalIdentity(uuid: "unique")
    let result = PersistentDisplayIdentityMatcher.match(
        current: identity,
        allCurrent: [identity],
        settings: [CustomDisplaySetting(identity: identity, isEnabled: false)]
    )

    expectEqual(result, .unique(settingIndex: 0))
}

private func testEDIDIdentityFallbackRestoresSetting() {
    let identity = PersistentDisplayIdentity(
        isBuiltIn: false,
        edidUUID: "edid-unique",
        vendorID: 10,
        productID: 20,
        serialNumber: 0
    )
    let result = PersistentDisplayIdentityMatcher.match(
        current: identity,
        allCurrent: [identity],
        settings: [CustomDisplaySetting(identity: identity, isEnabled: false)]
    )

    expectEqual(result, .unique(settingIndex: 0))
}

private func testDuplicateStoredIdentityDoesNotRestoreOff() {
    let identity = externalIdentity(uuid: "duplicate-store")
    let result = PersistentDisplayIdentityMatcher.match(
        current: identity,
        allCurrent: [identity],
        settings: [
            CustomDisplaySetting(identity: identity, isEnabled: false),
            CustomDisplaySetting(identity: identity, isEnabled: true)
        ]
    )

    expectEqual(result, .unknownOrAmbiguous)
}

private func testZeroSerialWithoutUUIDIsAmbiguous() {
    let identity = PersistentDisplayIdentity(
        isBuiltIn: false,
        vendorID: 10,
        productID: 20,
        serialNumber: 0
    )
    let result = PersistentDisplayIdentityMatcher.match(
        current: identity,
        allCurrent: [identity],
        settings: [CustomDisplaySetting(identity: identity, isEnabled: false)]
    )

    expectEqual(result, .unknownOrAmbiguous)
}

private func testHistoricalCollisionDoesNotBecomeUniqueLater() {
    let identity = externalIdentity(uuid: "collision")
    let settings = [
        CustomDisplaySetting(
            identity: identity,
            isEnabled: false,
            lastKnownName: "Display A",
            hasIdentityCollision: true
        )
    ]

    let result = PersistentDisplayIdentityMatcher.match(
        current: identity,
        allCurrent: [identity],
        settings: settings
    )

    expectEqual(result, .unknownOrAmbiguous)
}

private func testCustomLayoutDocumentRoundTripsLastKnownDescriptor() {
    let original = CustomLayoutDocument(
        hasBeenInitialized: true,
        settings: [
            CustomDisplaySetting(
                identity: externalIdentity(uuid: "persisted"),
                isEnabled: false,
                lastKnownName: "DELL UP2516D",
                hasIdentityCollision: false
            )
        ]
    )
    do {
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomLayoutDocument.self, from: data)
        expectEqual(decoded, original)
    } catch {
        fatalError("Custom layout round-trip failed: \(error)")
    }
}

private func testCustomStoreMigratesV1ByDroppingOnRecords() {
    let suiteName = "LightsOutSafetyCoreChecks.migrate.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Unable to create isolated UserDefaults suite")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let offIdentity = externalIdentity(uuid: "off")
    let legacyDocument = CustomLayoutDocument(
        version: 1,
        hasBeenInitialized: true,
        settings: [
            CustomDisplaySetting(identity: offIdentity, isEnabled: false, lastKnownName: "Saved Off"),
            CustomDisplaySetting(identity: externalIdentity(uuid: "display-6"), isEnabled: true, lastKnownName: "Display 6")
        ]
    )
    defaults.set(try? JSONEncoder().encode(legacyDocument), forKey: "CustomDisplayLayoutV1")

    let migrated = CustomLayoutStore(defaults: defaults).load()
    expectEqual(migrated.version, 2)
    expectEqual(migrated.settings, [
        CustomDisplaySetting(identity: offIdentity, isEnabled: false, lastKnownName: "Saved Off")
    ])
    expectEqual(defaults.object(forKey: "CustomDisplayLayoutV1") == nil, true)
}

private func testCustomStorePersistsOnlyOffRecords() {
    let suiteName = "LightsOutSafetyCoreChecks.save.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Unable to create isolated UserDefaults suite")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = CustomLayoutStore(defaults: defaults)
    do {
        try store.save(CustomLayoutDocument(settings: [
            CustomDisplaySetting(identity: externalIdentity(uuid: "off"), isEnabled: false),
            CustomDisplaySetting(identity: externalIdentity(uuid: "on"), isEnabled: true)
        ]))
    } catch {
        fatalError("Unable to save Custom layout: \(error)")
    }

    let loaded = store.load()
    expectEqual(loaded.settings.count, 1)
    expectEqual(loaded.settings.first?.isEnabled, false)
}

private func testHideExternalEnablesBuiltInBeforeDisablingExternals() {
    let plan = DisplayLayoutPolicy.plan(
        mode: .hideExternal,
        displays: [
            layoutDisplay(id: 1, builtIn: true, active: false),
            layoutDisplay(id: 2, builtIn: false, active: true)
        ]
    )

    expectEqual(plan.enableFirst, [1])
    expectEqual(plan.disableAfterVerification, [2])
}

private func testHideExternalWithActiveBuiltInDisablesOnlyPhysicalExternals() {
    let plan = DisplayLayoutPolicy.plan(
        mode: .hideExternal,
        displays: [
            layoutDisplay(id: 1, builtIn: true, active: true),
            layoutDisplay(id: 2, builtIn: false, active: true),
            layoutDisplay(id: 3, builtIn: false, active: true, classification: .virtual),
            layoutDisplay(id: 4, builtIn: false, active: true, classification: .unknown)
        ]
    )

    expectEqual(plan.enableFirst, [])
    expectEqual(plan.disableAfterVerification, [2])
}

private func testHideExternalWithoutBuiltInInitiallyPreservesActivePhysicalDisplays() {
    let plan = DisplayLayoutPolicy.plan(
        mode: .hideExternal,
        displays: [
            layoutDisplay(id: 2, builtIn: false, active: true),
            layoutDisplay(id: 3, builtIn: false, active: false)
        ]
    )

    expectEqual(plan.enableFirst, [])
    expectEqual(plan.disableAfterVerification, [])
    expectEqual(plan.fallback, .preservingSafetyDisplays([2]))
}

private func testHideExternalMissingCapturedTargetDoesNotDisableFallbackDisplay() {
    let missingIdentity = externalIdentity(uuid: "missing")
    let plan = DisplayLayoutPolicy.plan(
        mode: .hideExternal,
        displays: [layoutDisplay(id: 2, identity: externalIdentity(uuid: "present"), builtIn: false, active: true)],
        hideExternalFallbackTarget: [missingIdentity]
    )

    expectEqual(plan.enableFirst, [])
    expectEqual(plan.disableAfterVerification, [])
    expectEqual(plan.fallback, .waitingForBuiltIn)
}

private func testShowAllEnablesPhysicalAndUnknownButExcludesVirtual() {
    let plan = DisplayLayoutPolicy.plan(
        mode: .showAll,
        displays: [
            layoutDisplay(id: 1, builtIn: true, active: true),
            layoutDisplay(id: 2, builtIn: false, active: false),
            layoutDisplay(id: 3, builtIn: false, active: false, classification: .unknown),
            layoutDisplay(id: 4, builtIn: false, active: false, classification: .virtual)
        ]
    )

    expectEqual(plan.enableFirst, [2, 3])
    expectEqual(plan.disableAfterVerification, [])
}

private func testCustomUniqueTargetsEnableThenDisable() {
    let builtIn = PersistentDisplayIdentity(isBuiltIn: true)
    let external = externalIdentity(uuid: "external")
    let plan = DisplayLayoutPolicy.plan(
        mode: .custom,
        displays: [
            layoutDisplay(id: 1, identity: builtIn, builtIn: true, active: true),
            layoutDisplay(id: 2, identity: external, builtIn: false, active: false)
        ],
        customSettings: [
            CustomDisplaySetting(identity: builtIn, isEnabled: false)
        ]
    )

    expectEqual(plan.enableFirst, [2])
    expectEqual(plan.disableAfterVerification, [1])
}

private func testCustomUnknownDisplayDefaultsOn() {
    let plan = DisplayLayoutPolicy.plan(
        mode: .custom,
        displays: [layoutDisplay(id: 2, builtIn: false, active: false, classification: .unknown)]
    )

    expectEqual(plan.enableFirst, [2])
    expectEqual(plan.disableAfterVerification, [])
}

private func testCustomExcludesVirtualDisplay() {
    let plan = DisplayLayoutPolicy.plan(
        mode: .custom,
        displays: [layoutDisplay(id: 2, builtIn: false, active: true, classification: .virtual)]
    )

    expectEqual(plan.enableFirst, [])
    expectEqual(plan.disableAfterVerification, [])
    expectEqual(plan.fallback, .waitingForCustomTargets)
}

private func testCustomAmbiguousDisplayDefaultsOn() {
    let identity = externalIdentity(uuid: "shared")
    let plan = DisplayLayoutPolicy.plan(
        mode: .custom,
        displays: [
            layoutDisplay(id: 1, identity: identity, builtIn: false, active: false),
            layoutDisplay(id: 2, identity: identity, builtIn: false, active: true)
        ],
        customSettings: [CustomDisplaySetting(identity: identity, isEnabled: false)]
    )

    expectEqual(plan.enableFirst, [1])
    expectEqual(plan.disableAfterVerification, [])
}

private func testCustomAmbiguousDisplayCanUseSessionOnlyOffOverride() {
    let identity = externalIdentity(uuid: "shared")
    let plan = DisplayLayoutPolicy.plan(
        mode: .custom,
        displays: [
            layoutDisplay(id: 1, identity: identity, builtIn: false, active: true),
            layoutDisplay(id: 2, identity: identity, builtIn: false, active: true)
        ],
        customSettings: [],
        customSessionOverrides: [1: false, 2: true]
    )

    expectEqual(plan.enableFirst, [])
    expectEqual(plan.disableAfterVerification, [1])
}

private func testHideExternalRestoresCapturedTargetWithoutBuiltIn() {
    let targetIdentity = externalIdentity(uuid: "target")
    let otherIdentity = externalIdentity(uuid: "other")
    let plan = DisplayLayoutPolicy.plan(
        mode: .hideExternal,
        displays: [
            layoutDisplay(id: 1, identity: targetIdentity, builtIn: false, active: false),
            layoutDisplay(id: 2, identity: otherIdentity, builtIn: false, active: true)
        ],
        hideExternalFallbackTarget: [targetIdentity]
    )

    expectEqual(plan.enableFirst, [1])
    expectEqual(plan.disableAfterVerification, [2])
    expectEqual(plan.fallback, .waitingForBuiltIn)
}

private func testCustomOffOnlyStorePreservesActivePhysicalFallbackWhenDefaultOnExternalIsMissing() {
    let builtIn = PersistentDisplayIdentity(isBuiltIn: true)
    let plan = DisplayLayoutPolicy.plan(
        mode: .custom,
        displays: [layoutDisplay(id: 1, identity: builtIn, builtIn: true, active: true)],
        customSettings: [
            CustomDisplaySetting(identity: builtIn, isEnabled: false)
        ]
    )

    expectEqual(plan.enableFirst, [])
    expectEqual(plan.disableAfterVerification, [])
    expectEqual(plan.fallback, .preservingSafetyDisplays([1]))
}

private func externalIdentity(uuid: String) -> PersistentDisplayIdentity {
    PersistentDisplayIdentity(
        isBuiltIn: false,
        colorSyncUUID: uuid,
        vendorID: 10,
        productID: 20,
        serialNumber: 30
    )
}

private func layoutDisplay(
    id: DisplayID,
    identity: PersistentDisplayIdentity? = nil,
    builtIn: Bool,
    active: Bool,
    classification: DisplayClassification = .physical,
    available: Bool = true
) -> LayoutDisplaySnapshot {
    LayoutDisplaySnapshot(
        id: id,
        identity: identity,
        isBuiltIn: builtIn,
        isActive: active,
        isAvailable: available,
        classification: classification
    )
}

private func testDisconnectAllowsActiveTargetWhenAnotherDisplayRemainsActive() {
    let result = DisplaySafetyPolicy.disconnectPreflight(
        targetID: 1,
        displays: [
            DisplaySafetySnapshot(id: 1, isActive: true),
            DisplaySafetySnapshot(id: 2, isActive: true)
        ]
    )

    expectEqual(result, .allowed)
}

private func testBeginConfigurationDoesNotTriggerRestore() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.begin],
        activeDisplayIDs: [4],
        activePhysicalExternalDisplayIDs: [4],
        onlineDisplayIDs: [4],
        disconnectedDisplayIDs: [1],
        builtInDisplayID: 1
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), false)
}

private func testExternalRemovalWithDisconnectedBuiltInTriggersRestore() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.removed],
        activeDisplayIDs: [],
        activePhysicalExternalDisplayIDs: [],
        onlineDisplayIDs: [],
        disconnectedDisplayIDs: [1],
        builtInDisplayID: 1
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), true)
}

private func testVirtualDisplayDoesNotBlockDisconnectedBuiltInRestore() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.removed],
        activeDisplayIDs: [21],
        activePhysicalExternalDisplayIDs: [],
        onlineDisplayIDs: [21],
        disconnectedDisplayIDs: [1],
        builtInDisplayID: 1
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), true)
}

private func testPhysicalExternalDisplayBlocksDisconnectedBuiltInRestore() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.removed],
        activeDisplayIDs: [4],
        activePhysicalExternalDisplayIDs: [4],
        onlineDisplayIDs: [4],
        disconnectedDisplayIDs: [1],
        builtInDisplayID: 1
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), false)
}

private func testBuiltInDisplayBlocksUnnecessaryRestore() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.removed],
        activeDisplayIDs: [1],
        activePhysicalExternalDisplayIDs: [],
        onlineDisplayIDs: [1],
        disconnectedDisplayIDs: [4],
        builtInDisplayID: 1
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), false)
}

private func testVirtualOnlyDesktopTriggersRestore() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.removed],
        activeDisplayIDs: [21],
        activePhysicalExternalDisplayIDs: [],
        onlineDisplayIDs: [21],
        disconnectedDisplayIDs: [4],
        builtInDisplayID: nil
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), true)
}

private func testDisplayAddDoesNotAutoRedisconnectOrRestoreByItself() {
    let snapshot = ReconfigurationSnapshot(
        flags: [.added],
        activeDisplayIDs: [4],
        activePhysicalExternalDisplayIDs: [4],
        onlineDisplayIDs: [4],
        disconnectedDisplayIDs: [1],
        builtInDisplayID: 1
    )

    expectEqual(ReconfigurationDangerPolicy.shouldRestoreAllDisplays(after: snapshot), false)
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    guard actual == expected else {
        fatalError("Expected \(expected), got \(actual)", file: file, line: line)
    }
}
