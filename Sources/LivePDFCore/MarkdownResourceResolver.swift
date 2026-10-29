import Foundation
import UniformTypeIdentifiers

/// WebKit can read images beside the document without granting access to the filesystem root.
public struct MarkdownResourceResolver {
    private let directory: URL
    public let baseURL = URL(string: "livepdf-resource://document/")!

    public init(documentURL: URL) {
        directory = documentURL.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
    }

    public func resolve(_ url: URL) throws -> URL {
        guard url.scheme == baseURL.scheme, url.host == baseURL.host,
              url.user == nil, url.password == nil, url.port == nil else {
            throw CocoaError(.fileReadNoPermission)
        }
        // URL.path decodes once; never decode a second time (e.g. a literal %2F filename).
        let candidate = directory.appendingPathComponent(String(url.path.dropFirst()))
            .standardizedFileURL.resolvingSymlinksInPath()
        let root = directory.pathComponents
        guard candidate.pathComponents.count > root.count,
              Array(candidate.pathComponents.prefix(root.count)) == root else {
            throw CocoaError(.fileReadNoPermission)
        }
        return candidate
    }

    public func resource(_ url: URL) throws -> (data: Data, mimeType: String) {
        let file = try resolve(url)
        let extensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "svg", "avif", "heic", "heif", "bmp", "tif", "tiff"]
        guard extensions.contains(file.pathExtension.lowercased()),
              let type = UTType(filenameExtension: file.pathExtension),
              let mimeType = type.preferredMIMEType else { throw CocoaError(.fileReadUnsupportedScheme) }
        return (try FileSnapshot.read(url: file).data, mimeType)
    }
}
