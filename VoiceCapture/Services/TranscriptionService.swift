import Foundation
@preconcurrency import WhisperKit

final class TranscriptionService {

    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var modelLoadingProgress: Double = 0

    func loadModel(named modelName: String) async throws {
        isModelLoaded = false
        modelLoadingProgress = 0

        let config = WhisperKitConfig(model: modelName)
        whisperKit = try await WhisperKit(config)

        isModelLoaded = true
        modelLoadingProgress = 1.0
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        let results = try await whisperKit.transcribe(audioPath: audioFileURL.path)
        return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum TranscriptionError: LocalizedError {
        case modelNotLoaded

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Whisper model is not loaded."
            }
        }
    }
}
