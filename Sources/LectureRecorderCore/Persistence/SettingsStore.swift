import Foundation
import Combine

public struct AppSettings: Codable, Sendable {
    public var vaultPath: String?
    public var selectedModel: ModelVariant
    public var subjects: [Subject]
    public var sampleRateHz: Double
    public var recordingChannels: Int
    // Optional so settings files written before themes existed still decode.
    public var themeID: String?
    public var customAccentHex: String?
    public var customAccentAltHex: String?
    /// "notch" (default) or "window".
    public var uiMode: String?
    /// Which modifier key, double-tapped, triggers each action ("control", "option", "shift", "command", "off").
    public var shortcutOpen: String?
    public var shortcutRecord: String?
    public var shortcutPause: String?
    public var lastSubjectCode: String?

    public init(
        vaultPath: String? = nil,
        selectedModel: ModelVariant = .largeV3Full,
        subjects: [Subject] = [],
        sampleRateHz: Double = 48_000,
        recordingChannels: Int = 1,
        themeID: String? = nil,
        customAccentHex: String? = nil,
        customAccentAltHex: String? = nil,
        uiMode: String? = nil,
        shortcutOpen: String? = nil,
        shortcutRecord: String? = nil,
        shortcutPause: String? = nil,
        lastSubjectCode: String? = nil
    ) {
        self.vaultPath = vaultPath
        self.selectedModel = selectedModel
        self.subjects = subjects
        self.sampleRateHz = sampleRateHz
        self.recordingChannels = recordingChannels
        self.themeID = themeID
        self.customAccentHex = customAccentHex
        self.customAccentAltHex = customAccentAltHex
        self.uiMode = uiMode
        self.shortcutOpen = shortcutOpen
        self.shortcutRecord = shortcutRecord
        self.shortcutPause = shortcutPause
        self.lastSubjectCode = lastSubjectCode
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
