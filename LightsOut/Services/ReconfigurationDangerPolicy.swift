import Foundation

public struct ReconfigurationFlags: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let begin = ReconfigurationFlags(rawValue: 1 << 0)
    public static let removed = ReconfigurationFlags(rawValue: 1 << 1)
    public static let disabled = ReconfigurationFlags(rawValue: 1 << 2)
    public static let setMain = ReconfigurationFlags(rawValue: 1 << 3)
    public static let added = ReconfigurationFlags(rawValue: 1 << 4)
}

public struct ReconfigurationSnapshot: Equatable {
    public let flags: ReconfigurationFlags
    public let activeDisplayIDs: Set<DisplayID>
    public let activePhysicalExternalDisplayIDs: Set<DisplayID>
    public let onlineDisplayIDs: Set<DisplayID>
    public let disconnectedDisplayIDs: Set<DisplayID>
    public let builtInDisplayID: DisplayID?

    public init(
        flags: ReconfigurationFlags,
        activeDisplayIDs: Set<DisplayID>,
        activePhysicalExternalDisplayIDs: Set<DisplayID>,
        onlineDisplayIDs: Set<DisplayID>,
        disconnectedDisplayIDs: Set<DisplayID>,
        builtInDisplayID: DisplayID?
    ) {
        self.flags = flags
        self.activeDisplayIDs = activeDisplayIDs
        self.activePhysicalExternalDisplayIDs = activePhysicalExternalDisplayIDs
        self.onlineDisplayIDs = onlineDisplayIDs
        self.disconnectedDisplayIDs = disconnectedDisplayIDs
        self.builtInDisplayID = builtInDisplayID
    }
}

/// Pure timing model for coalescing a burst of display-topology notifications.
/// Each new event moves the trailing-edge deadline, while `maximumDelay` keeps
/// a noisy device from postponing reconciliation forever.
public struct DisplayTopologyEventBurst: Equatable {
    public private(set) var firstEventTime: TimeInterval
    public private(set) var lastEventTime: TimeInterval

    public init(firstEventTime: TimeInterval) {
        self.firstEventTime = firstEventTime
        lastEventTime = firstEventTime
    }

    public mutating func recordEvent(at time: TimeInterval) {
        lastEventTime = max(lastEventTime, time)
    }

    public func fireTime(quietPeriod: TimeInterval, maximumDelay: TimeInterval) -> TimeInterval {
        min(lastEventTime + quietPeriod, firstEventTime + maximumDelay)
    }
}

public enum ReconfigurationDangerPolicy {
    public static func shouldRestoreAllDisplays(after snapshot: ReconfigurationSnapshot) -> Bool {
        guard !snapshot.flags.contains(.begin) else {
            return false
        }

        let restoreRelevantFlags: ReconfigurationFlags = [.removed, .disabled, .setMain]
        guard !snapshot.flags.intersection(restoreRelevantFlags).isEmpty else {
            return false
        }

        guard !snapshot.disconnectedDisplayIDs.isEmpty else {
            return false
        }

        let hasActiveBuiltInDisplay = snapshot.builtInDisplayID.map {
            snapshot.activeDisplayIDs.contains($0)
        } ?? false
        let hasActivePhysicalDisplay = hasActiveBuiltInDisplay
            || !snapshot.activePhysicalExternalDisplayIDs.isEmpty

        return !hasActivePhysicalDisplay
    }
}
