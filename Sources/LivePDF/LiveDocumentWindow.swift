import AppKit

protocol LiveDocumentWindow: AnyObject {
    var onOpenURLs: (([URL]) -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
    func start()
}

extension DocumentWindowController: LiveDocumentWindow {}
extension MarkdownWindowController: LiveDocumentWindow {}
