import Foundation

/// Minimal load/save wrapper for a single Codable value backed by a JSON file.
/// Used for settings, the library index, and the transcription queue so all
/// of them survive an app restart without needing a database.
public struct JSONFileStore<Value: Codable> {
    public let url: URL
    private let defaultValue: () -> Value

    public init(url: URL, defaultValue: @escaping @autoclosure () -> Value) {
        self.url = url
        self.defaultValue = defaultValue
    }

    public func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return defaultValue() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Value.self, from: data)) ?? defaultValue()
    }

    public func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
