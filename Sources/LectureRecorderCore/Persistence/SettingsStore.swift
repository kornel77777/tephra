import Foundation
import Combine

public struct AppSettings: Codable, Sendable {
    public var vaultPath: String?
    public var selectedModel: ModelVariant
    public var subjects: [Subject]
    public var sampleRateHz: Double
    public var recordingChannels: Int

    public init(
        vaultPath: String? = nil,
        selectedModel: ModelVariant = .largeV3Full,
        subjects: [Subject] = [],
        sampleRateHz: Double = 48_000,
        recordingChannels: Int = 1
    ) {
        self.vaultPath = vaultPath
        self.selectedModel = selectedModel
        self.subjects = subjects
        self.sampleRateHz = sampleRateHz
        self.recordingChannels = recordingChannels
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var settings: AppSettings {
        didSet { try? store.save(settings) }
    }

    private let store: JSONFileStore<AppSettings>

    public init() {
        let store = JSONFileStore<AppSettings>(url: AppPaths.settingsFile, defaultValue: AppSettings())
        self.store = store
        self.settings = store.load()
    }

    public var vaultURL: URL? {
        settings.vaultPath.map { URL(fileURLWithPath: $0) }
    }
}
