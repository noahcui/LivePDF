import Foundation
import Testing
@testable import LivePDFCore

struct MarkdownDocumentTests {
    @Test func utf8BOMUnicodeAndEmptyDocuments() throws {
        #expect(try MarkdownDocumentLoader.load(data: Data("\u{FEFF}# 中文 📝".utf8)) == "# 中文 📝")
        #expect(try MarkdownDocumentLoader.load(data: Data()) == "")
        #expect(throws: MarkdownDocumentLoader.LoadError.self) {
            try MarkdownDocumentLoader.load(data: Data([0xff, 0xfe, 0x61]))
        }
    }

    @Test func classifiesSupportedPathsWithoutRequiringExistingFiles() {
        for ext in ["md", "MD", "markdown", "mdown", "mkd"] {
            #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/尚未创建.\(ext)")) == .markdown)
        }
        #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/paper.pdf")) == .pdf)
        #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/script.sh")) == nil)
        #expect(DocumentKind(url: URL(string: "https://example.com/doc.md")!) == nil)
    }

    @Test func imageResourcesAllowUnicodeAndRejectTraversalAndSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let docs = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let resolver = MarkdownResourceResolver(documentURL: docs.appendingPathComponent("readme.md"))
        let image = docs.appendingPathComponent("图 1.png")
        let bytes = Data([1, 2, 3])
        try bytes.write(to: image)
        let resourceURL = resolver.baseURL.appendingPathComponent("图 1.png")
        #expect(try resolver.resource(resourceURL).data == bytes)
        #expect(try resolver.resource(resourceURL).mimeType == "image/png")
        let outside = root.appendingPathComponent("secret.png")
        try bytes.write(to: outside)
        try FileManager.default.createSymbolicLink(at: docs.appendingPathComponent("escape.png"), withDestinationURL: outside)
        for path in ["../secret.png", "%2e%2e/secret.png", "escape.png"] {
            let url = URL(string: "livepdf-resource://document/" + path)!
            #expect(throws: (any Error).self) { try resolver.resource(url) }
        }
        for address in ["file:///etc/passwd", "livepdf-resource://other/a.png", "livepdf-resource://document:99/a.png"] {
            #expect(throws: (any Error).self) { try resolver.resolve(URL(string: address)!) }
        }
        try bytes.write(to: docs.appendingPathComponent("code.js"))
        #expect(throws: (any Error).self) { try resolver.resource(resolver.baseURL.appendingPathComponent("code.js")) }
        let literal = docs.appendingPathComponent("%2F.png")
        try bytes.write(to: literal)
        #expect(try resolver.resource(resolver.baseURL.appendingPathComponent("%2F.png")).data == bytes)
    }

    @Test func markdownWatcherUsesSnapshotsAndRecoversAfterInvalidEncoding() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("live.md")
        try Data("# Initial".utf8).write(to: file)
        let changed = DispatchSemaphore(value: 0)
        let recorder = MarkdownRecorder()
        let watcher = FileWatcher(url: file, debounceInterval: 0.05, onSnapshot: { data in
            recorder.record(data)
            changed.signal()
        })
        try watcher.start()
        defer { watcher.stop() }
        try Data("# Atomic save".utf8).write(to: file, options: .atomic)
        #expect(changed.wait(timeout: .now() + 5) == .success)
        #expect(recorder.current == "# Atomic save")
        try Data([0xff]).write(to: file)
        #expect(changed.wait(timeout: .now() + 5) == .success)
        #expect(recorder.current == "# Atomic save")
        try FileManager.default.removeItem(at: file)
        #expect(changed.wait(timeout: .now() + 0.3) == .timedOut)
        try Data("# Recreated".utf8).write(to: file)
        #expect(changed.wait(timeout: .now() + 5) == .success)
        #expect(recorder.current == "# Recreated")
    }
}

private final class MarkdownRecorder {
    private let lock = NSLock()
    private var source = ""
    var current: String { lock.withLock { source } }
    func record(_ data: Data) {
        if let text = try? MarkdownDocumentLoader.load(data: data) {
            lock.withLock { source = text }
        }
    }
}
