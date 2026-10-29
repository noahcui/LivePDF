import Foundation

public enum MarkdownDocumentLoader {
    public enum LoadError: Error, LocalizedError {
        case invalidEncoding
        public var errorDescription: String? {
            L10n.text("Markdown must be a UTF-8 text file.")
        }
    }

    public static func load(url: URL) throws -> String {
        try load(data: FileSnapshot.read(url: url).data)
    }

    public static func load(data: Data) throws -> String {
        guard var text = String(data: data, encoding: .utf8) else { throw LoadError.invalidEncoding }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        return text
    }
}
