import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: Self.webURL(url))
    }

    /// SFSafariViewController throws on anything but http(s), and cellar links are typed or
    /// imported free text ("www.vivino.com/..."), so give them a scheme or search for them.
    static func webURL(_ url: URL) -> URL {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" { return url }
        let text = url.absoluteString
        if url.scheme == nil, !text.contains(" "), let fixed = URL(string: "https://" + text), fixed.host != nil { return fixed }
        let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=" + query)!
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
