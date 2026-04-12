import SwiftUI
import AppKit

// Replaces SafariView on macOS - opens URLs in the default browser
enum LinkOpener {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Share Sheet (macOS)

struct ShareButton: View {
    let items: [Any]

    var body: some View {
        Button {
            guard let contentView = NSApplication.shared.keyWindow?.contentView else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}
