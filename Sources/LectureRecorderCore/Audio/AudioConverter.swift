import Foundation
import AVFoundation

public enum AudioConverter {
    /// Transcodes a finished linear-PCM CAF recording to AAC .m4a for storage.
    public static func convertCAFToM4A(source: URL, destination: URL) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        let asset = AVURLAsset(url: source)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioRecorderError.conversionFailed("Could not create export session")
        }
        exportSession.outputURL = destination
        exportSession.outputFileType = .m4a

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    let message = exportSession.error?.localizedDescription ?? "unknown export error"
                    continuation.resume(throwing: AudioRecorderError.conversionFailed(message))
                default:
                    continuation.resume(throwing: AudioRecorderError.conversionFailed("unexpected export status"))
                }
            }
        }
    }
}
