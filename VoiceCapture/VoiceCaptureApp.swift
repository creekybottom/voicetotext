import SwiftUI

@main
struct VoiceCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            RecorderView()
                .preferredColorScheme(.dark)
        }
    }
}
