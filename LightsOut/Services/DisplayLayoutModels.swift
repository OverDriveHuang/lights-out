import Foundation

public enum DisplayClassification: String, Codable, Equatable, Sendable {
    case physical
    case virtual
    case unknown
}

public enum DisplayClassificationEvidence: String, Codable, Equatable, Sendable {
    case builtIn
    case ioRegistryOrEDID
    case knownVirtualName
    case insufficientEvidence
}

public enum DisplayLayoutMode: String, CaseIterable, Equatable, Sendable {
    case showAll
    case hideExternal
    case custom

    public var next: DisplayLayoutMode {
        switch self {
        case .showAll: .hideExternal
        case .hideExternal: .custom
        case .custom: .showAll
        }
    }
}

public enum DisplayLayoutLifecycle: Equatable, Sendable {
    case starting
    case ready
    case suspended
    case terminating
}

public struct LayoutDisplaySnapshot: Equatable, Sendable {
    public let id: DisplayID
    public let identity: PersistentDisplayIdentity?
    public let isBuiltIn: Bool
    public let isActive: Bool
    public let isAvailable: Bool
    public let classification: DisplayClassification

    public init(
        id: DisplayID,
        identity: PersistentDisplayIdentity?,
        isBuiltIn: Bool,
        isActive: Bool,
        isAvailable: Bool,
        classification: DisplayClassification
    ) {
        self.id = id
        self.identity = identity
        self.isBuiltIn = isBuiltIn
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.classification = classification
    }
}

public enum LayoutFallback: Equatable, Sendable {
    case waitingForBuiltIn
    case waitingForCustomTargets
    case preservingSafetyDisplays(Set<DisplayID>)
    case hardwareOperationFailed
}

public struct DisplayLayoutPlan: Equatable, Sendable {
    public let enableFirst: Set<DisplayID>
    public let disableAfterVerification: Set<DisplayID>
    public let fallback: LayoutFallback?
    public let shouldRetryWhenTopologyChanges: Bool

    public init(
        enableFirst: Set<DisplayID> = [],
        disableAfterVerification: Set<DisplayID> = [],
        fallback: LayoutFallback? = nil,
        shouldRetryWhenTopologyChanges: Bool = false
    ) {
        self.enableFirst = enableFirst
        self.disableAfterVerification = disableAfterVerification
        self.fallback = fallback
        self.shouldRetryWhenTopologyChanges = shouldRetryWhenTopologyChanges
    }
}
