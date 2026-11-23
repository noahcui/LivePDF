import AppKit
import UniformTypeIdentifiers
import WebKit

public enum PDFExport {
    /// The file name offered when exporting `source`. A PDF gets a distinct name
    /// so the default never overwrites the file being watched.
    public static func suggestedFileName(for source: URL) -> String {
        let base = source.deletingPathExtension().lastPathComponent
        return source.pathExtension.lowercased() == "pdf" ? "\(base)-export.pdf" : "\(base).pdf"
    }

    /// Asks where to save the export of `source`, as a sheet on `window`.
    @MainActor
    public static func chooseDestination(for source: URL, in window: NSWindow, then export: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.directoryURL = source.deletingLastPathComponent()
        panel.nameFieldStringValue = suggestedFileName(for: source)
        panel.prompt = L10n.text("Export")
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            export(url)
        }
    }

    /// Writes the web view's whole document to `destination` as a paginated PDF,
    /// laid out by WebKit's print pipeline (the page's `@media print` rules apply).
    @MainActor
    public static func export(_ webView: WKWebView, to destination: URL, completion: @escaping (Bool) -> Void) {
        guard let window = webView.window else { completion(false); return }
        let info = NSPrintInfo()
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destination
        info.topMargin = 48
        info.bottomMargin = 48
        info.leftMargin = 48
        info.rightMargin = 48
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        // WebKit's print view has no size until it is given one.
        operation.view?.frame = NSRect(origin: .zero, size: info.paperSize)
        let delegate = PrintDelegate(completion: completion)
        PrintDelegate.running.insert(delegate)
        // WKWebView renders asynchronously, so only the modal-for-window form works.
        operation.runModal(for: window, delegate: delegate,
                           didRun: #selector(PrintDelegate.printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
    }
}

@MainActor
private final class PrintDelegate: NSObject {
    /// NSPrintOperation does not retain its delegate.
    static var running: Set<PrintDelegate> = []
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) { self.completion = completion }

    @objc func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        Self.running.remove(self)
        completion(success)
    }
}
