import Foundation
import UniformTypeIdentifiers

public enum DocumentKind {
    case pdf, markdown

    public static let markdownExtensions = ["md", "markdown", "mdown", "mkd"]

    public init?(url: URL) {
        guard url.isFileURL else { return nil }
        let ext = url.pathExtension.lowercased()
        if Self.markdownExtensions.contains(ext) { self = .markdown }
        else if ext == "pdf" || (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .pdf)) == true { self = .pdf }
        else { return nil }
    }

    public static var contentTypes: [UTType] {
        [.pdf] + markdownExtensions.compactMap { UTType(filenameExtension: $0) }
    }
}
