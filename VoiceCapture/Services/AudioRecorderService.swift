import AVFoundation
import Foundation

protocol AudioRecorderServiceDelegate: AnyObject {
    func audioRecorderService(_ service: AudioRecorderService, didFinishChunk chunkURL: URL, index: Int, startTime: TimeInterval, endTime: TimeInterval)
    func audioRecorderService(_ service: AudioRecorderService, didFailWithError error: Error)
}

final class AudioRecorderService {

    weak var delegate: AudioRecorderServiceDelegate?

    private let audioEngine = AVAudioEngine()
    private var currentChunkFile: AVAudioFile?
    private var chunkIndex = 0
    private var chunkStartTime: TimeInterval = 0
    private var recordingStartTime: Date?
    private var samplesInCurrentChunk: AVAudioFrameCount = 0

    // 30-second chunks at 16 kHz mono
    private let samplesPerChunk: AVAudioFrameCount = 16_000 * 30
    private let outputFormat: AVAudioFormat

    private(set) var isRecording = false

    var currentDuration: TimeInterval {
        guard let start = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    init() {
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }

    // MARK: - Public

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw RecorderError.converterCreationFailed
        }

        chunkIndex = 0
        samplesInCurrentChunk = 0
        recordingStartTime = Date()
        isRecording = true

        try createNewChunkFile()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        finalizeCurrentChunk()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cleanupTempFiles() {
        let tmpDir = chunkDirectory()
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Private

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let ratio = 16_000.0 / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard frameCount > 0,
              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            delegate?.audioRecorderService(self, didFailWithError: error)
            return
        }

        guard let chunkFile = currentChunkFile else { return }

        do {
            try chunkFile.write(from: convertedBuffer)
            samplesInCurrentChunk += convertedBuffer.frameLength

            if samplesInCurrentChunk >= samplesPerChunk {
                finalizeCurrentChunk()
                try createNewChunkFile()
            }
        } catch {
            delegate?.audioRecorderService(self, didFailWithError: error)
        }
    }

    private func createNewChunkFile() throws {
        let url = chunkFileURL(for: chunkIndex)
        currentChunkFile = try AVAudioFile(forWriting: url, settings: outputFormat.settings)
        samplesInCurrentChunk = 0
        chunkStartTime = Double(chunkIndex) * 30.0
    }

    private func finalizeCurrentChunk() {
        guard let file = currentChunkFile, samplesInCurrentChunk > 0 else {
            currentChunkFile = nil
            return
        }
        let url = file.url
        let endTime = chunkStartTime + Double(samplesInCurrentChunk) / 16_000.0
        let index = chunkIndex
        currentChunkFile = nil
        chunkIndex += 1

        delegate?.audioRecorderService(self, didFinishChunk: url, index: index, startTime: chunkStartTime, endTime: endTime)
    }

    private func chunkDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("VoiceCapture", isDirectory: true)
    }

    private func chunkFileURL(for index: Int) -> URL {
        let dir = chunkDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chunk_\(index).wav")
    }

    // MARK: - Errors

    enum RecorderError: LocalizedError {
        case converterCreationFailed

        var errorDescription: String? {
            switch self {
            case .converterCreationFailed:
                return "Failed to create audio format converter."
            }
        }
    }
}
