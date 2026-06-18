import LightsOutSafetyCore

@main
struct LightsOutSafetyCoreChecks {
    static func main() {
        testRestoreCandidatesMergeSourcesInStableOrder()
        testRestoreCandidatesUseFallbackOneOnlyForRestoreList()
        testDisconnectRejectsInactiveTarget()
        testDisconnectRejectsLastActiveDisplay()
        testDisconnectAllowsActiveTargetWhenAnotherDisplayRemainsActive()
        testBeginConfigurationDoesNotTriggerRestore()
        testExternalRemovalWithDisconnectedBuiltInTriggersRestore()
        testVirtualDisplayDoesNotBlockDisconnectedBuiltInRestore()
        testPhysicalExternalDisplayBlocksDisconnectedBuiltInRestore()
        testDisplayAddDoesNotAutoRedisconnectOrRestoreByItself()
        print("LightsOutSafetyCoreChecks passed")
    }
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

    expectEqual(result, .rejected(.lastActiveDisplay))
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
