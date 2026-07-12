import Foundation

public struct PersistentDisplayIdentity: Codable, Hashable, Sendable {
    public let isBuiltIn: Bool
    public let colorSyncUUID: String?
    public let edidUUID: String?
    public let vendorID: UInt32
    public let productID: UInt32
    public let serialNumber: UInt32

    public init(
        isBuiltIn: Bool,
        colorSyncUUID: String? = nil,
        edidUUID: String? = nil,
        vendorID: UInt32 = 0,
        productID: UInt32 = 0,
        serialNumber: UInt32 = 0
    ) {
        self.isBuiltIn = isBuiltIn
        self.colorSyncUUID = colorSyncUUID
        self.edidUUID = edidUUID
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
    }
}

public struct CustomDisplaySetting: Codable, Equatable, Sendable {
    public var identity: PersistentDisplayIdentity
    public var isEnabled: Bool
    public var lastKnownName: String?
    public var hasIdentityCollision: Bool

    public init(
        identity: PersistentDisplayIdentity,
        isEnabled: Bool,
        lastKnownName: String? = nil,
        hasIdentityCollision: Bool = false
    ) {
        self.identity = identity
        self.isEnabled = isEnabled
        self.lastKnownName = lastKnownName
        self.hasIdentityCollision = hasIdentityCollision
    }
}

public struct CustomLayoutDocument: Codable, Equatable, Sendable {
    public var version: Int
    public var hasBeenInitialized: Bool
    public var settings: [CustomDisplaySetting]

    public init(version: Int = 2, hasBeenInitialized: Bool = true, settings: [CustomDisplaySetting] = []) {
        self.version = version
        self.hasBeenInitialized = hasBeenInitialized
        self.settings = settings
    }
}

public enum DisplayIdentityMatch: Equatable, Sendable {
    case unique(settingIndex: Int)
    case unknownOrAmbiguous
}

public enum PersistentDisplayIdentityMatcher {
    public static func hasCurrentCollision(
        current: PersistentDisplayIdentity,
        allCurrent: [PersistentDisplayIdentity]
    ) -> Bool {
        if current.isBuiltIn {
            return allCurrent.filter(\.isBuiltIn).count > 1
        }

        let keys: [(PersistentDisplayIdentity) -> String?] = [
            { $0.colorSyncUUID?.lowercased() },
            { $0.edidUUID?.lowercased() },
            {
                guard $0.serialNumber != 0 else { return nil }
                return "\($0.vendorID):\($0.productID):\($0.serialNumber)"
            }
        ]
        return keys.contains { key in
            guard let value = key(current) else { return false }
            return allCurrent.filter { key($0) == value }.count > 1
        }
    }

    public static func match(
        current: PersistentDisplayIdentity,
        allCurrent: [PersistentDisplayIdentity],
        settings: [CustomDisplaySetting]
    ) -> DisplayIdentityMatch {
        let usableSettings = settings.enumerated().filter { !$0.element.hasIdentityCollision }

        if current.isBuiltIn {
            return uniqueMatch(
                current: current,
                allCurrent: allCurrent,
                candidates: usableSettings,
                key: { $0.isBuiltIn ? "builtin" : nil }
            )
        }

        let keyPaths: [(PersistentDisplayIdentity) -> String?] = [
            { $0.colorSyncUUID.map { "colorsync:\($0.lowercased())" } },
            { $0.edidUUID.map { "edid:\($0.lowercased())" } },
            {
                guard $0.serialNumber != 0 else { return nil }
                return "vps:\($0.vendorID):\($0.productID):\($0.serialNumber)"
            }
        ]

        for key in keyPaths {
            let result = uniqueMatch(current: current, allCurrent: allCurrent, candidates: usableSettings, key: key)
            if case .unique = result { return result }
        }

        return .unknownOrAmbiguous
    }

    private static func uniqueMatch(
        current: PersistentDisplayIdentity,
        allCurrent: [PersistentDisplayIdentity],
        candidates: [(offset: Int, element: CustomDisplaySetting)],
        key: (PersistentDisplayIdentity) -> String?
    ) -> DisplayIdentityMatch {
        guard let currentKey = key(current) else { return .unknownOrAmbiguous }
        let currentCount = allCurrent.filter { key($0) == currentKey }.count
        let stored = candidates.filter { key($0.element.identity) == currentKey }
        guard currentCount == 1, stored.count == 1 else { return .unknownOrAmbiguous }
        return .unique(settingIndex: stored[0].offset)
    }
}
