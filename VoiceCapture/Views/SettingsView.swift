import SwiftUI

struct SettingsView: View {

    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    private let modelOptions: [(id: String, label: String)] = [
        ("openai_whisper-base", "Base (fastest)"),
        ("openai_whisper-small", "Small (balanced)"),
        ("openai_whisper-medium", "Medium (most accurate)")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Whisper Model") {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(modelOptions, id: \.id) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .onChange(of: viewModel.selectedModel) {
                        Task { await viewModel.loadModel() }
                    }
                }

                Section("Transcription") {
                    Toggle("Auto-punctuate", isOn: $viewModel.autoPunctuate)
                    Toggle("Remove filler words", isOn: $viewModel.removeFillers)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("App", value: "VoiceCapture")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
