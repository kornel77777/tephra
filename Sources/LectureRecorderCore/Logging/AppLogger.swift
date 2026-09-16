import Foundation
import os

/// Mirrors log output to both the unified logging system and a plain text file
/// under ~/Library/Logs/LectureRecorder/, so logs are inspectable without Console.app.
public enum AppLogger {
    private static let logger = Logger(subsystem: "com.lecturerecorder.app", category: "general")

    private static var fileHandle: FileHandle? = {
        let dateString = DateFormatter.logFileDateFormatter.string(from: Date())
        let url = AppPaths.logsDirectory.appendingPathComponent("\(dateString).log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return try? FileHandle(forWritingTo: url)
    }()

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        write("INFO", message)
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        write("ERROR", message)
    }

    private static func write(_ level: String, _ message: String) {
        guard let fileHandle else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) [\(level)] \(message)\n"
        if let data = line.data(using: .utf8) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }
}

private extension DateFormatter {
    static let logFileDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
