import SwiftUI

struct ActionButtons: View {

    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ActionButton(title: "Copy Text", icon: "doc.on.doc") {
                    viewModel.copyTranscript()
                }

                ActionButton(title: "Send to Claude", icon: "paperplane") {
                    viewModel.sendToClaude()
                }

                ActionButton(title: "Send to ChatGPT", icon: "bubble.left") {
                    viewModel.sendToChatGPT()
                }

                ActionButton(
                    title: viewModel.showingOrganized ? "Show Original" : "Organize Text",
                    icon: "text.alignleft"
                ) {
                    viewModel.organizeText()
                }
            }
        }
    }
}

// MARK: - Single action button

struct ActionButton: View {

    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 80, height: 60)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
