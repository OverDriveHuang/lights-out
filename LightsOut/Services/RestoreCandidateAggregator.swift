import Foundation

public typealias DisplayID = UInt32

public struct RestoreCandidateSnapshot: Equatable {
    public let persistedDisabledDisplayIDs: Set<DisplayID>
    public let disconnectedDisplayIDs: Set<DisplayID>
    public let onlineDisplayIDs: Set<DisplayID>
    public let activeDisplayIDs: Set<DisplayID>
    public let savedBuiltInDisplayID: DisplayID?
    public let fallbackDisplayID: DisplayID?
    public let builtInFallbackDisplayIDs: [DisplayID]

    public init(
        persistedDisabledDisplayIDs: Set<DisplayID>,
        disconnectedDisplayIDs: Set<DisplayID>,
        onlineDisplayIDs: Set<DisplayID>,
        activeDisplayIDs: Set<DisplayID>,
        savedBuiltInDisplayID: DisplayID?,
        fallbackDisplayID: DisplayID?,
        builtInFallbackDisplayIDs: [DisplayID]
    ) {
        self.persistedDisabledDisplayIDs = persistedDisabledDisplayIDs
        self.disconnectedDisplayIDs = disconnectedDisplayIDs
        self.onlineDisplayIDs = onlineDisplayIDs
        self.activeDisplayIDs = activeDisplayIDs
        self.savedBuiltInDisplayID = savedBuiltInDisplayID
        self.fallbackDisplayID = fallbackDisplayID
        self.builtInFallbackDisplayIDs = builtInFallbackDisplayIDs
    }
}

public enum RestoreCandidateAggregator {
    public static func candidateIDs(from snapshot: RestoreCandidateSnapshot) -> [DisplayID] {
        let onlineButInactiveDisplayIDs = snapshot.onlineDisplayIDs.subtracting(snapshot.activeDisplayIDs)
        var candidates: [DisplayID] = []

        candidates.append(contentsOf: snapshot.persistedDisabledDisplayIDs.sorted())
        candidates.append(contentsOf: snapshot.disconnectedDisplayIDs.sorted())
        candidates.append(contentsOf: onlineButInactiveDisplayIDs.sorted())

        if let savedBuiltInDisplayID = snapshot.savedBuiltInDisplayID,
           !snapshot.activeDisplayIDs.contains(savedBuiltInDisplayID) {
            candidates.append(savedBuiltInDisplayID)
        }

        if let fallbackDisplayID = snapshot.fallbackDisplayID,
           !snapshot.activeDisplayIDs.contains(fallbackDisplayID) {
            candidates.append(fallbackDisplayID)
        }

        candidates.append(contentsOf: snapshot.builtInFallbackDisplayIDs.filter {
            !snapshot.activeDisplayIDs.contains($0)
        })

        return candidates.uniqued()
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
