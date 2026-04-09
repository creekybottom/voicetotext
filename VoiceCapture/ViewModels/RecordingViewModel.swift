import SwiftUI
import AVFoundation

enum RecordingState {
    case idle
    case recording
    case processing
}

@MainActor
final class RecordingViewModel: ObservableObject {

    // MARK: - Published state

    @Published var recordingState: RecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var transcriptText: String = ""
    @Published var organizedText: String?
    @Published var showingOrganized: Bool = false
    @Published var chunks: [TranscriptChunk] = []
    @Published var currentTranscribingChunk: Int?
    @Published var totalChunks: Int = 0
    @Published var isModelLoaded: Bool = false
    @Published var modelLoadingProgress: Double = 0
    @Published var showMicPermissionAlert: Bool = false
    @Published var showCopiedToast: Bool = false
    @Published var errorMessage: String?

    // MARK: - Settings

    @Published var selectedModel: String = "openai_whisper-base"
    @Published var autoPunctuate: Bool = true
    @Published var removeFillers: Bool = true

    // MARK: - Computed

    var hasTranscript: Bool { !transcriptText.isEmpty }

    var displayedTranscript: String {
        showingOrganized ? (organizedText ?? transcriptText) : transcriptText
    }

    var formattedDuration: String {
        let h = Int(recordingDuration) / 3600
        let m = (Int(recordingDuration) % 3600) / 60
        let s = Int(recordingDuration) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Private

    private let audioService = AudioRecorderService()
    private let transcriptionService = TranscriptionService()
    private var timer: Timer?
    private var pendingChunks: [(url: URL, index: Int, startTime: TimeInterval, endTime: TimeInterval)] = []
    private var isTranscribingChunk = false

    // MARK: - Init

    init() {
        audioService.delegate = self
        Task { await loadModel() }
    }

    // MARK: - Model loading

    func loadModel() async {
        isModelLoaded = false
        modelLoadingProgress = 0
        do {
            try await transcriptionService.loadModel(named: selectedModel)
            isModelLoaded = true
            modelLoadingProgress = 1.0
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        switch recordingState {
        case .idle: requestPermissionAndRecord()
        case .recording: stopRecording()
        case .processing: break
        }
    }

    private func requestPermissionAndRecord() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted { self?.beginRecording() }
                    else { self?.showMicPermissionAlert = true }
                }
            }
        case .denied:
            showMicPermissionAlert = true
        case .granted:
            beginRecording()
        @unknown default:
            showMicPermissionAlert = true
        }
    }

    private func beginRecording() {
        chunks.removeAll()
        transcriptText = ""
        organizedText = nil
        showingOrganized = false
        pendingChunks.removeAll()
        audioService.cleanupTempFiles()

        do {
            try audioService.startRecording()
            recordingState = .recording
            recordingDuration = 0
            startTimer()
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        audioService.stopRecording()
        stopTimer()
        recordingState = .processing

        Task {
            await drainPendingChunks()
            recordingState = .idle
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.recordingState == .recording else { return }
                self.recordingDuration = self.audioService.currentDuration
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Transcription pipeline

    private func processNextChunk() async {
        guard !isTranscribingChunk, !pendingChunks.isEmpty else { return }
        isTranscribingChunk = true

        let info = pendingChunks.removeFirst()
        currentTranscribingChunk = info.index + 1

        do {
            let text = try await transcriptionService.transcribe(audioFileURL: info.url)
            let chunk = TranscriptChunk(
                index: info.index,
                startTime: info.startTime,
                endTime: info.endTime,
                text: text,
                isTranscribed: true
            )
            chunks.append(chunk)
            if !transcriptText.isEmpty { transcriptText += " " }
            transcriptText += text
        } catch {
            let chunk = TranscriptChunk(
                index: info.index,
                startTime: info.startTime,
                endTime: info.endTime,
                text: "",
                isTranscribed: false,
                error: error.localizedDescription
            )
            chunks.append(chunk)
            transcriptText += " [transcription failed for segment \(info.index + 1)]"
        }

        currentTranscribingChunk = nil
        isTranscribingChunk = false

        if !pendingChunks.isEmpty {
            await processNextChunk()
        }
    }

    private func drainPendingChunks() async {
        while !pendingChunks.isEmpty || isTranscribingChunk {
            if !isTranscribingChunk, !pendingChunks.isEmpty {
                await processNextChunk()
            } else {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    // MARK: - Actions

    func copyTranscript() {
        UIPasteboard.general.string = displayedTranscript
        showCopiedToast = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCopiedToast = false
        }
    }

    func sendToClaude() {
        DeepLinkHelper.openApp(.claude, withText: displayedTranscript)
    }

    func sendToChatGPT() {
        DeepLinkHelper.openApp(.chatGPT, withText: displayedTranscript)
    }

    func organizeText() {
        if showingOrganized {
            showingOrganized = false
            return
        }
        let result = TextOrganizer.organize(
            chunks: chunks,
            removeFillers: removeFillers,
            autoPunctuate: autoPunctuate
        )
        organizedText = result.fullText
        showingOrganized = true
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - AudioRecorderServiceDelegate

extension RecordingViewModel: AudioRecorderServiceDelegate {

    nonisolated func audioRecorderService(
        _ service: AudioRecorderService,
        didFinishChunk chunkURL: URL,
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        Task { @MainActor in
            totalChunks = index + 1
            pendingChunks.append((url: chunkURL, index: index, startTime: startTime, endTime: endTime))
            await processNextChunk()
        }
    }

    nonisolated func audioRecorderService(
        _ service: AudioRecorderService,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            errorMessage = "Recording error: \(error.localizedDescription)"
        }
    }
}
