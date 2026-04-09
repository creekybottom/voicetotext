import UIKit

enum ExternalApp {
    case claude
    case chatGPT

    var customSchemeURL: String {
        switch self {
        case .claude: return "claude://new"
        case .chatGPT: return "chatgpt://new"
        }
    }

    var universalLinkURL: String {
        switch self {
        case .claude: return "https://claude.ai/new"
        case .chatGPT: return "https://chat.openai.com/"
        }
    }

    var appStoreURL: String {
        switch self {
        case .claude: return "https://apps.apple.com/app/claude/id6473753684"
        case .chatGPT: return "https://apps.apple.com/app/chatgpt/id6448311069"
        }
    }
}

@MainActor
final class DeepLinkHelper {

    static func openApp(_ app: ExternalApp, withText text: String) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Step 1: Try custom URL scheme
        let customURLString: String
        switch app {
        case .claude:
            customURLString = "claude://new?text=\(encodedText)"
        case .chatGPT:
            customURLString = "chatgpt://new?text=\(encodedText)"
        }

        if let url = URL(string: customURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }

        // Step 2: Try universal link
        let universalURLString: String
        switch app {
        case .claude:
            universalURLString = "https://claude.ai/new?q=\(encodedText)"
        case .chatGPT:
            universalURLString = "https://chat.openai.com/?q=\(encodedText)"
        }

        if let url = URL(string: universalURLString) {
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                if !success {
                    // Step 3: Copy to clipboard and open App Store
                    Task { @MainActor in
                        UIPasteboard.general.string = text
                        if let storeURL = URL(string: app.appStoreURL) {
                            UIApplication.shared.open(storeURL)
                        }
                    }
                }
            }
            return
        }

        // Final fallback: copy and open store
        UIPasteboard.general.string = text
        if let storeURL = URL(string: app.appStoreURL) {
            UIApplication.shared.open(storeURL)
        }
    }
}
