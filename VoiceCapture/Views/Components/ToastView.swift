import SwiftUI

struct ToastView: View {

    let message: String

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .background(Color.green.opacity(0.3))
                .clipShape(Capsule())
                .padding(.bottom, 120)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
