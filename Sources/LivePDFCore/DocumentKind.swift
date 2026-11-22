import Foundation
import UniformTypeIdentifiers

public enum DocumentKind {
    case pdf, markdown, presentation

    public static let markdownExtensions = ["md", "markdown", "mdown", "mkd"]
    /// Converted to PDF by an installed PowerPoint or Keynote; see PresentationConverter.
    public static let presentationExtensions = ["pptx", "ppt", "ppsx", "pps"]

    public init?(url: URL) {
        guard url.isFileURL else { return nil }
        let ext = url.pathExtension.lowercased()
        if Self.markdownExtensions.contains(ext) { self = .markdown }
        else if Self.presentationExtensions.contains(ext) { self = .presentation }
        else if ext == "pdf" || (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .pdf)) == true { self = .pdf }
        else { return nil }
    }

    public static var contentTypes: [UTType] {
        [.pdf] + (markdownExtensions + presentationExtensions).compactMap { UTType(filenameExtension: $0) }
    }
}
