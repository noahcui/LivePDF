import AppKit
import PDFKit
import UniformTypeIdentifiers
import LivePDFCore

private func pdfURLs(from pasteboard: NSPasteboard) -> [URL] {
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ?? []
    return objects.compactMap { object in
        guard let url = object as? URL else { return nil }
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        return url.pathExtension.lowercased() == "pdf" || type?.conforms(to: .pdf) == true ? url : nil
    }
}

final class DropPDFView: PDFView {
    var onOpenURLs: (([URL]) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pdfURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = pdfURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onOpenURLs?(urls)
        return true
    }
}

private final class DropWelcomeView: NSView {
    var onOpenURLs: (([URL]) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pdfURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = pdfURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onOpenURLs?(urls)
        return true
    }
}

final class WelcomeWindowController: NSWindowController {
    var onOpenURLs: (([URL]) -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 400), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "LivePDF"
        window.minSize = NSSize(width: 620, height: 350)
        window.center()
        window.isReleasedWhenClosed = false
        let content = DropWelcomeView()
        content.onOpenURLs = { [weak self] in self?.onOpenURLs?($0) }
        window.contentView = content
        let title = NSTextField(labelWithString: "LivePDF")
        title.font = .systemFont(ofSize: 32, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: L10n.text("Drop a PDF here, or press ⌘O to open one.\nLive reload keeps your reading position."))
        detail.alignment = .center
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 3
        detail.preferredMaxLayoutWidth = 500
        let button = NSButton(title: L10n.text("Open PDF…"), target: nil, action: #selector(AppDelegate.openDocument(_:)))
        button.bezelStyle = .rounded
        let stack = NSStackView(views: [title, detail, button])
        stack.orientation = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -80),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 500)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
