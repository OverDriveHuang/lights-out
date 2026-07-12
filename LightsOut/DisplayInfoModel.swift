import SwiftUI

enum DisplayState {
    case disconnected
    case pending
    case active
    
    var isOff: Bool { self == .disconnected }
}

class DisplayInfo: ObservableObject, Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    var isPrimary: Bool
    let isBuiltIn: Bool
    @Published var persistentIdentity: PersistentDisplayIdentity?
    @Published var displayClassification: DisplayClassification
    @Published var classificationEvidence: DisplayClassificationEvidence
    @Published var isUserHidden: Bool
    @Published var isAvailable: Bool
    @Published var state: DisplayState

    init(
        id: CGDirectDisplayID,
        name: String,
        state: DisplayState,
        isPrimary: Bool,
        isBuiltIn: Bool,
        isUserHidden: Bool = false,
        isAvailable: Bool = true,
        displayClassification: DisplayClassification? = nil,
        classificationEvidence: DisplayClassificationEvidence? = nil,
        persistentIdentity: PersistentDisplayIdentity? = nil
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.isPrimary = isPrimary
        self.isBuiltIn = isBuiltIn
        self.isUserHidden = isUserHidden
        self.isAvailable = isAvailable
        self.displayClassification = displayClassification ?? (isBuiltIn ? .physical : .unknown)
        self.classificationEvidence = classificationEvidence ?? (isBuiltIn ? .builtIn : .insufficientEvidence)
        self.persistentIdentity = persistentIdentity
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
