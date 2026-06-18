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

        if let builtInDisplayID = snapshot.builtInDisplayID,
           snapshot.disconnectedDisplayIDs.contains(builtInDisplayID) {
            return snapshot.activePhysicalExternalDisplayIDs.isEmpty
        }

        return snapshot.activeDisplayIDs.isEmpty
    }
}
