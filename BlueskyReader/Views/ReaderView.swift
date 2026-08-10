import SwiftUI
import SafariServices

/// Wraps SFSafariViewController for SwiftUI, with reader mode enabled where available.
struct ReaderView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
