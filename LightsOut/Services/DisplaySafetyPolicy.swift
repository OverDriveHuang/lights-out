import Foundation

public struct DisplaySafetySnapshot: Equatable {
    public let id: DisplayID
    public let isActive: Bool
    public let classification: DisplayClassification

    public init(id: DisplayID, isActive: Bool, classification: DisplayClassification = .physical) {
        self.id = id
        self.isActive = isActive
        self.classification = classification
    }
}

public enum DisconnectRejectionReason: Equatable {
    case targetNotActive
    case lastActivePhysicalDisplay
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

        let remainingActivePhysicalCount = displays.filter {
            $0.id != targetID && $0.isActive && $0.classification == .physical
        }.count
        guard remainingActivePhysicalCount > 0 else {
            return .rejected(.lastActivePhysicalDisplay)
        }

        return .allowed
    }

    public static func disconnectBatchPreflight(
        targetIDs: Set<DisplayID>,
        displays: [DisplaySafetySnapshot]
    ) -> DisconnectPreflightResult {
        guard !targetIDs.isEmpty,
              targetIDs.allSatisfy({ id in displays.first(where: { $0.id == id })?.isActive == true }) else {
            return .rejected(.targetNotActive)
        }

        let hasRemainingActivePhysicalDisplay = displays.contains {
            !targetIDs.contains($0.id) && $0.isActive && $0.classification == .physical
        }
        return hasRemainingActivePhysicalDisplay ? .allowed : .rejected(.lastActivePhysicalDisplay)
    }
}
