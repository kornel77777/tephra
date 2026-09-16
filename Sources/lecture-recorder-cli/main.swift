import Foundation
import LectureRecorderCore

/// Phase 1 proof-of-concept: transcribe an existing audio file from the command
/// line so the model, prompt glossary, and VAD chunking behavior can be checked
/// before any of the SwiftUI app exists.
@main
struct LectureRecorderCLI {
    static func main() async {
        let arguments = CommandLine.arguments
        var audioPath: String?
        var modelName = ModelVariant.largeV3Full.rawValue
        var prompt = ""
        var outputPath: String?

        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--audio":
                index += 1
                audioPath = arguments[safe: index]
            case "--model":
                index += 1
                modelName = arguments[safe: index] ?? modelName
            case "--prompt":
                index += 1
                prompt = arguments[safe: index] ?? ""
            case "--out":
                index += 1
                outputPath = arguments[safe: index]
            case "--help", "-h":
                printUsage()
                return
            default:
                break
            }
            index += 1
        }

        guard let audioPath else {
            print("Missing required --audio <path>")
            printUsage()
            exit(1)
        }

        guard let variant = ModelVariant(rawValue: modelName) else {
            print("Unknown model: \(modelName)")
            print("Available: \(ModelVariant.allCases.map(\.rawValue).joined(separator: ", "))")
            exit(1)
        }

        let promptTokenEstimate = prompt.split(separator: " ").count
        if promptTokenEstimate > PromptLimits.maxTokens {
            print("Warning: prompt glossary looks long (~\(promptTokenEstimate) words); WhisperKit's prefill prompt caps at \(PromptLimits.maxTokens) tokens and will be truncated by the tokenizer filter.")
        }

        let service = TranscriptionService()

        print("Preparing model \(variant.rawValue) (first run downloads it and can take a few minutes to specialize for the Neural Engine)...")
        do {
            try await service.prepare(variant: variant)
        } catch {
            print("Failed to prepare model: \(error.localizedDescription)")
            exit(1)
        }

        print("Transcribing \(audioPath)...")
        let start = Date()
        do {
            let result = try await service.transcribe(
                audioPath: audioPath,
                promptGlossary: prompt,
                incrementalLoading: false,
                onProgress: { fraction in
                    print(String(format: "\rProgress: %.0f%%", fraction * 100), terminator: "")
                    fflush(stdout)
                },
                shouldContinue: { true }
            )
            print("")

            let cleaned = PostProcessor.clean(result.segments)
            let transcript = PostProcessor.toTimestampedTranscript(cleaned)
            let elapsed = Date().timeIntervalSince(start)
            print("Done in \(String(format: "%.1f", elapsed))s using \(result.modelUsed).")

            if let outputPath {
                try transcript.write(toFile: outputPath, atomically: true, encoding: .utf8)
                print("Transcript written to \(outputPath)")
            } else {
                print("\n--- Transcript ---\n")
                print(transcript)
            }
        } catch {
            print("\nTranscription failed: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        Usage: lecture-recorder-cli --audio <path> [--model <variant>] [--prompt "term1, term2"] [--out <path>]

        Models:
          \(ModelVariant.allCases.map(\.rawValue).joined(separator: "\n  "))
        """)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
