import SwiftUI

struct RecordButton: View {

    let state: RecordingState
    let isModelLoaded: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .scaleEffect(state == .recording && isPulsing ? 1.1 : 1.0)
                    .animation(
                        state == .recording
                            ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )

                if state == .processing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: state == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(!isModelLoaded || state == .processing)
        .opacity(isModelLoaded ? 1.0 : 0.5)
        .onChange(of: state) { _, newState in
            isPulsing = newState == .recording
        }
    }

    private var buttonColor: Color {
        switch state {
        case .idle: return Color(.darkGray)
        case .recording: return .red
        case .processing: return Color(.darkGray)
        }
    }
}
