import Foundation

public final class CustomLayoutStore {
    private enum Keys {
        static let documentV1 = "CustomDisplayLayoutV1"
        static let documentV2 = "CustomDisplayLayoutV2"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func load() -> CustomLayoutDocument {
        if let data = defaults.data(forKey: Keys.documentV2),
           let document = try? decoder.decode(CustomLayoutDocument.self, from: data) {
            return normalizedOffOnlyDocument(document)
        }

        if let legacyData = defaults.data(forKey: Keys.documentV1),
           let legacyDocument = try? decoder.decode(CustomLayoutDocument.self, from: legacyData) {
            let migrated = normalizedOffOnlyDocument(legacyDocument)
            try? save(migrated)
            defaults.removeObject(forKey: Keys.documentV1)
            return migrated
        }

        return CustomLayoutDocument()
    }

    public func save(_ document: CustomLayoutDocument) throws {
        defaults.set(try encoder.encode(normalizedOffOnlyDocument(document)), forKey: Keys.documentV2)
    }

    private func normalizedOffOnlyDocument(_ document: CustomLayoutDocument) -> CustomLayoutDocument {
        CustomLayoutDocument(
            version: 2,
            hasBeenInitialized: true,
            settings: document.settings.filter { !$0.isEnabled }
        )
    }
}
