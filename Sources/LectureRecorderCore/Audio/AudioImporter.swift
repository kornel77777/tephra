import Foundation
import AVFoundation

/// Copies a dropped-in audio file (voice memo, mp3, wav, flac) into the app's
/// working storage so it goes through the same transcription pipeline as a
/// recording made in-app.
public enum AudioImporter {
    public static let supportedExtensions: Set<String> = ["m4a", "mp3", "wav", "flac", "caf", "aac"]

    public static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    public static func importFile(at sourceURL: URL) async throws -> (url: URL, duration: Double) {
        let destination = AppPaths.recordingsDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension)

        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let asset = AVURLAsset(url: destination)
        let duration = try await asset.load(.duration)
        return (destination, CMTimeGetSeconds(duration))
    }
}
