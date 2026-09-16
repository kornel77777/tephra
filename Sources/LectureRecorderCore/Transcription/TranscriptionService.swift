import Foundation
import WhisperKit

public enum ModelVariant: String, CaseIterable, Codable, Sendable, Identifiable {
    case largeV3Full = "openai_whisper-large-v3"
    case largeV3Turbo = "large-v3-v20240930_turbo"
    case largeV3TurboCompressed = "large-v3-v20240930_626MB"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .largeV3Full: return "Large v3 (full precision, most accurate)"
        case .largeV3Turbo: return "Large v3 Turbo (fast)"
        case .largeV3TurboCompressed: return "Large v3 Turbo 626MB (compressed, fast)"
        }
    }
}

public struct TranscriptSegment: Codable, Hashable, Sendable {
    public var startSeconds: Double
    public var endSeconds: Double
    public var text: String
}

public struct TranscriptionResult: Sendable {
    public var segments: [TranscriptSegment]
    public var modelUsed: String
    public var rawText: String
}

public enum TranscriptionError: Error, LocalizedError {
    case cancelled
    case modelNotReady
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled: return "Transcription was cancelled."
        case .modelNotReady: return "The model is not downloaded or loaded yet."
        case .underlying(let message): return message
        }
    }
}

/// Wraps WhisperKit with the accuracy-first defaults for lecture transcription:
/// no language auto-detection (always English), greedy decoding, VAD chunking for
/// long audio, and the standard hallucination-guard thresholds.
public actor TranscriptionService {
    public static func modelsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("LectureRecorder/models", isDirectory: true)
    }

    private var whisperKit: WhisperKit?
    private var loadedVariant: ModelVariant?

    public init() {}

    public func downloadModel(_ variant: ModelVariant, progress: @escaping @Sendable (Double) -> Void) async throws {
        let base = Self.modelsDirectory()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        _ = try await WhisperKit.download(
            variant: variant.rawValue,
            downloadBase: base,
            progressCallback: { downloadProgress in
                progress(downloadProgress.fractionCompleted)
            }
        )
    }

    /// Loads (and downloads if missing) the given model variant. A no-op if it is
    /// already the currently loaded model.
    public func prepare(variant: ModelVariant) async throws {
        if loadedVariant == variant, whisperKit != nil { return }
        let base = Self.modelsDirectory()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let config = WhisperKitConfig(
            model: variant.rawValue,
            downloadBase: base,
            prewarm: true,
            load: true,
            download: true
        )
        whisperKit = try await WhisperKit(config)
        loadedVariant = variant
    }

    public func removeModel(_ variant: ModelVariant) throws {
        let dir = Self.modelsDirectory().appendingPathComponent(variant.rawValue, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// Transcribes a single audio file. `shouldContinue` is polled during decoding;
    /// return false from it to cancel early. `incrementalLoading` should be set for
    /// very long files to bound memory use (note: clip timestamps are unavailable
    /// in that mode, which is fine since this app doesn't use them).
    public func transcribe(
        audioPath: String,
        promptGlossary: String,
        incrementalLoading: Bool,
        onProgress: @escaping @Sendable (Double) -> Void,
        shouldContinue: @escaping @Sendable () -> Bool
    ) async throws -> TranscriptionResult {
        guard let whisperKit else { throw TranscriptionError.modelNotReady }

        var promptTokens: [Int]?
        let trimmed = promptGlossary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let tokenizer = whisperKit.tokenizer {
            let encoded = tokenizer.encode(text: " " + trimmed)
            promptTokens = encoded.filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: "en",
            temperature: 0,
            usePrefillPrompt: promptTokens != nil,
            detectLanguage: false,
            wordTimestamps: false,
            promptTokens: promptTokens,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            noSpeechThreshold: 0.6,
            chunkingStrategy: .vad
        )

        let audioOptions = AudioInputOptions(
            audioLoadingMode: incrementalLoading ? .incremental : .fullFile
        )

        let results = try await whisperKit.transcribe(
            audioPath: audioPath,
            audioInputOptions: audioOptions,
            decodeOptions: options
        ) { _ in
            onProgress(whisperKit.progress.fractionCompleted)
            return shouldContinue()
        }

        // WhisperKit's own handling of a `false` return from the callback isn't
        // guaranteed to surface as a thrown error, so check again explicitly —
        // callers rely on TranscriptionError.cancelled to tell a user-initiated
        // cancel apart from a real failure.
        guard shouldContinue() else {
            throw TranscriptionError.cancelled
        }

        let segments = results.flatMap { $0.segments }.map {
            TranscriptSegment(startSeconds: Double($0.start), endSeconds: Double($0.end), text: $0.text)
        }
        let rawText = results.map { $0.text }.joined(separator: " ")
        return TranscriptionResult(segments: segments, modelUsed: loadedVariant?.rawValue ?? "", rawText: rawText)
    }
}

/// Token budget for the subject prompt glossary, per WhisperKit's prefill prompt limit.
public enum PromptLimits {
    public static let maxTokens = 224
}
