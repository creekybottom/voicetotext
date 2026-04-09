import SwiftUI

struct RecorderView: View {

    @StateObject private var viewModel = RecordingViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                modelLoadingBanner
                TranscriptView(
                    text: viewModel.displayedTranscript,
                    isProcessing: viewModel.recordingState == .processing,
                    currentChunk: viewModel.currentTranscribingChunk,
                    totalChunks: viewModel.totalChunks
                )
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                if viewModel.hasTranscript && viewModel.recordingState == .idle {
                    ActionButtons(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                RecordButton(
                    state: viewModel.recordingState,
                    isModelLoaded: viewModel.isModelLoaded
                ) {
                    viewModel.toggleRecording()
                }
                .padding(.bottom, 24)
            }

            // Toast
            if viewModel.showCopiedToast {
                ToastView(message: "Copied \u{2713}")
            }
        }
        .alert("Microphone Access Required", isPresented: $viewModel.showMicPermissionAlert) {
            Button("Open Settings") { viewModel.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("VoiceCapture needs microphone access to record and transcribe your speech. Please enable it in Settings.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                if viewModel.recordingState == .recording {
                    PulsingDot()
                }
                Text(viewModel.formattedDuration)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(viewModel.recordingState == .recording ? .red : .secondary)
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var modelLoadingBanner: some View {
        if !viewModel.isModelLoaded {
            VStack(spacing: 8) {
                ProgressView(value: viewModel.modelLoadingProgress)
                    .tint(.accentColor)
                Text("Loading Whisper model...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Pulsing dot

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 10, height: 10)
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
