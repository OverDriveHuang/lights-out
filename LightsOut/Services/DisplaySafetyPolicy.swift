import Foundation

public struct DisplaySafetySnapshot: Equatable {
    public let id: DisplayID
    public let isActive: Bool

    public init(id: DisplayID, isActive: Bool) {
        self.id = id
        self.isActive = isActive
    }
}

public enum DisconnectRejectionReason: Equatable {
    case targetNotActive
    case lastActiveDisplay
}

public enum DisconnectPreflightResult: Equatable {
    case allowed
    case rejected(DisconnectRejectionReason)
}

public enum DisplaySafetyPolicy {
    public static func disconnectPreflight(
        targetID: DisplayID,
        displays: [DisplaySafetySnapshot]
    ) -> DisconnectPreflightResult {
        guard displays.first(where: { $0.id == targetID })?.isActive == true else {
            return .rejected(.targetNotActive)
        }

        let activeDisplayCount = displays.filter(\.isActive).count
        guard activeDisplayCount > 1 else {
            return .rejected(.lastActiveDisplay)
        }

        return .allowed
    }
}

