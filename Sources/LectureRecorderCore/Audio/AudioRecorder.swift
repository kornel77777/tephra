import Foundation
import AVFoundation
import Combine
import AudioToolbox

public enum AudioRecorderError: Error, LocalizedError {
    case engineStartFailed(String)
    case notRecording
    case conversionFailed(String)
    case fileCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .engineStartFailed(let m): return "Could not start recording: \(m)"
        case .notRecording: return "No active recording."
        case .conversionFailed(let m): return "Could not finalize recording: \(m)"
        case .fileCreationFailed(let m): return "Could not create the recording file: \(m)"
        }
    }
}

public enum RecorderState: Equatable, Sendable {
    case idle
    case recording
    case paused
}

/// Records to CAF (linear PCM) while running, since an m4a file's moov atom is
/// only written on a clean close and a crash mid-recording would corrupt it.
/// `finish()` converts the finished CAF to AAC .m4a for storage.
@MainActor
public final class AudioRecorder: ObservableObject {
    @Published public private(set) var state: RecorderState = .idle
    @Published public private(set) var elapsedSeconds: Double = 0
    @Published public private(set) var inputLevel: Float = 0
    @Published public private(set) var bookmarks: [Bookmark] = []

    private let engine = AVAudioEngine()
    private var cafFile: AVAudioFile?
    private var cafURL: URL?
    private var startedAt: Date?
    private var pausedAccumulated: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var displayTimer: Timer?
    private var sleepActivityToken: NSObjectProtocol?

    public init() {}

    public func availableInputDevices() -> [InputDevice] {
        CoreAudioDeviceLister.listInputDevices()
    }

    public func start(sampleRate: Double, channels: Int, inputDevice: InputDevice?) throws {
        guard state == .idle else { return }

        if let inputDevice {
            try setEngineInputDevice(inputDevice.id)
        }

        let workDir = AppPaths.recordingsDirectory
        let url = workDir.appendingPathComponent("\(UUID().uuidString).caf")

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else {
            throw AudioRecorderError.fileCreationFailed("Unsupported format")
        }

        do {
            let file = try AVAudioFile(forWriting: url, settings: recordingFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            cafFile = file
        } catch {
            throw AudioRecorderError.fileCreationFailed(error.localizedDescription)
        }
        cafURL = url

        let converter = AVAudioConverter(from: hardwareFormat, to: recordingFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.updateLevel(from: buffer)

            let bufferToWrite: AVAudioPCMBuffer
            if hardwareFormat.sampleRate == recordingFormat.sampleRate,
               hardwareFormat.channelCount == recordingFormat.channelCount {
                bufferToWrite = buffer
            } else if let converter {
                guard let converted = AVAudioPCMBuffer(
                    pcmFormat: recordingFormat,
                    frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * recordingFormat.sampleRate / hardwareFormat.sampleRate) + 1024
                ) else { return }
                var error: NSError?
                converter.convert(to: converted, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                if error != nil { return }
                bufferToWrite = converted
            } else {
                return
            }

            try? self.cafFile?.write(from: bufferToWrite)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineStartFailed(error.localizedDescription)
        }

        startedAt = Date()
        pausedAccumulated = 0
        bookmarks = []
        state = .recording
        beginDisplayTimer()
        beginSleepPrevention()
    }

    public func pause() {
        guard state == .recording else { return }
        engine.pause()
        pauseStartedAt = Date()
        state = .paused
    }

    public func resume() throws {
        guard state == .paused else { return }
        if let pauseStartedAt {
            pausedAccumulated += Date().timeIntervalSince(pauseStartedAt)
        }
        pauseStartedAt = nil
        do {
            try engine.start()
        } catch {
            throw AudioRecorderError.engineStartFailed(error.localizedDescription)
        }
        state = .recording
    }

    public func addBookmark(note: String = "") {
        guard state == .recording || state == .paused else { return }
        bookmarks.append(Bookmark(offsetSeconds: elapsedSeconds, note: note))
    }

    /// Stops the engine, closes the CAF file, converts it to AAC .m4a, and
    /// returns the finished file's URL plus the bookmark list.
    public func finish() async throws -> (url: URL, duration: Double, bookmarks: [Bookmark]) {
        guard state != .idle, let cafURL else { throw AudioRecorderError.notRecording }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        endSleepPrevention()
        endDisplayTimer()

        cafFile = nil // closes the file handle, flushing the moov-equivalent CAF chunks

        let finalDuration = elapsedSeconds
        let finalBookmarks = bookmarks

        let m4aURL = cafURL.deletingPathExtension().appendingPathExtension("m4a")
        try await AudioConverter.convertCAFToM4A(source: cafURL, destination: m4aURL)
        try? FileManager.default.removeItem(at: cafURL)

        state = .idle
        elapsedSeconds = 0
        bookmarks = []
        self.cafURL = nil

        return (m4aURL, finalDuration, finalBookmarks)
    }

    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        var sum: Float = 0
        let samples = channelData[0]
        for i in 0..<frameLength {
            sum += samples[i] * samples[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        let normalized = min(1, rms * 8)
        Task { @MainActor in
            self.inputLevel = normalized
        }
    }

    private func beginDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            Task { @MainActor in
                if self.state == .recording {
                    self.elapsedSeconds = Date().timeIntervalSince(startedAt) - self.pausedAccumulated
                }
            }
        }
    }

    private func endDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func beginSleepPrevention() {
        sleepActivityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled],
            reason: "Recording a lecture"
        )
    }

    private func endSleepPrevention() {
        if let sleepActivityToken {
            ProcessInfo.processInfo.endActivity(sleepActivityToken)
        }
        sleepActivityToken = nil
    }

    private func setEngineInputDevice(_ deviceID: AudioDeviceID) throws {
        guard let audioUnit = engine.inputNode.audioUnit else { return }
        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            throw AudioRecorderError.engineStartFailed("Could not select input device (OSStatus \(status))")
        }
    }
}
