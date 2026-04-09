import SwiftUI

struct TranscriptView: View {

    let text: String
    let isProcessing: Bool
    let currentChunk: Int?
    let totalChunks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isProcessing, let chunk = currentChunk {
                Text("Transcribing chunk \(chunk)/\(totalChunks)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(text.isEmpty ? "Tap the record button to start..." : text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(text.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .onChange(of: text) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
