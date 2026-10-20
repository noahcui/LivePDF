import CoreServices
import Darwin
import Foundation
import PDFKit
import Testing
@testable import LivePDFCore

@Suite(.serialized)
final class FileWatcherTests {
    private let directory: URL
    private let file: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePDF-watcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("paper.pdf")
        try makePDF(pageCount: 24, revision: "initial").write(to: file)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func testInPlaceOverwriteLoadsExactlyOnce() throws {
        let recorder = try ReloadRecorder(initialURL: file)
        let loaded = DispatchSemaphore(value: 0)
        recorder.onLoad = { count in if count == 1 { loaded.signal() } }
        let watcher = FileWatcher(url: file, onSnapshot: recorder.reload)
        try watcher.start()
        defer { watcher.stop() }

        try overwrite(makePDF(pageCount: 25, revision: "in-place"), at: file)
        #expect(loaded.wait(timeout: .now() + 8) == .success)
        Thread.sleep(forTimeInterval: 0.8)
        #expect(recorder.loadedPageCounts == [25])
    }

    @Test func testAtomicReplacementAndFollowingInPlaceWriteAreBothObserved() throws {
        let recorder = try ReloadRecorder(initialURL: file)
        let replaced = DispatchSemaphore(value: 0)
        let following = DispatchSemaphore(value: 0)
        recorder.onLoad = { count in
            if count == 1 { replaced.signal() }
            if count == 2 { following.signal() }
        }
        let watcher = FileWatcher(url: file, onSnapshot: recorder.reload)
        try watcher.start()
        defer { watcher.stop() }

        let temporary = directory.appendingPathComponent("paper.tmp")
        try makePDF(pageCount: 26, revision: "atomic").write(to: temporary)
        #expect(rename(temporary.path, file.path) == 0)
        #expect(replaced.wait(timeout: .now() + 8) == .success)
        try overwrite(makePDF(pageCount: 27, revision: "after atomic"), at: file)
        #expect(following.wait(timeout: .now() + 8) == .success)
        Thread.sleep(forTimeInterval: 0.8)
        #expect(recorder.loadedPageCounts == [26, 27])
    }

    @Test func testDeleteAndRecreateKeepsWatching() throws {
        let recorder = try ReloadRecorder(initialURL: file)
        let recreated = DispatchSemaphore(value: 0)
        recorder.onLoad = { count in if count == 1 { recreated.signal() } }
        let watcher = FileWatcher(url: file, onSnapshot: recorder.reload)
        try watcher.start()
        defer { watcher.stop() }

        try FileManager.default.removeItem(at: file)
        Thread.sleep(forTimeInterval: 0.5) // Let the missing-file debounce fire.
        #expect(recorder.loadedPageCounts == [])
        #expect(recorder.displayedPageCount == 24)
        try makePDF(pageCount: 28, revision: "recreated").write(to: file)
        #expect(recreated.wait(timeout: .now() + 8) == .success)
        Thread.sleep(forTimeInterval: 0.8)
        #expect(recorder.loadedPageCounts == [28])
    }

    @Test func testSlowChunkedWriteNeverInstallsPartialPDFAndLoadsOnceWhenComplete() throws {
        let recorder = try ReloadRecorder(initialURL: file)
        let completed = DispatchSemaphore(value: 0)
        recorder.onLoad = { count in if count == 1 { completed.signal() } }
        let watcher = FileWatcher(url: file, debounceInterval: 0.15, onSnapshot: recorder.reload)
        try watcher.start()
        defer { watcher.stop() }

        let replacement = try makePDF(pageCount: 29, revision: "chunked")
        try Data().write(to: file)
        let chunkSize = max(1, replacement.count / 5)
        var offset = 0
        while offset < replacement.count {
            let end = min(offset + chunkSize, replacement.count)
            let handle = try FileHandle(forWritingTo: file)
            try handle.seekToEnd()
            try handle.write(contentsOf: replacement[offset..<end])
            try handle.synchronize()
            try handle.close()
            offset = end
            if offset < replacement.count {
                // Gaps exceed debounce: even if PDFKit could repair a partial
                // page tree, the loader must retain the previous document.
                Thread.sleep(forTimeInterval: 0.3)
                #expect(recorder.loadedPageCounts == [])
                #expect(recorder.displayedPageCount == 24)
            }
        }
        #expect(completed.wait(timeout: .now() + 8) == .success)
        Thread.sleep(forTimeInterval: 0.8)
        #expect(recorder.loadedPageCounts == [29])
        #expect(recorder.displayedPageCount == 29)
    }

    @Test func testBurstWritesAreDebouncedIntoOneCallback() throws {
        let recorder = try ReloadRecorder(initialURL: file)
        let completed = DispatchSemaphore(value: 0)
        recorder.onLoad = { count in if count == 1 { completed.signal() } }
        let watcher = FileWatcher(url: file, debounceInterval: 0.3, onSnapshot: recorder.reload)
        try watcher.start()
        defer { watcher.stop() }

        for revision in 1...4 {
            try overwrite(makePDF(pageCount: 24 + revision, revision: "burst \(revision)"), at: file)
            Thread.sleep(forTimeInterval: 0.07)
        }
        #expect(completed.wait(timeout: .now() + 8) == .success)
        Thread.sleep(forTimeInterval: 0.8)
        #expect(recorder.loadedPageCounts == [28])
    }

    @Test func testStopPreventsFurtherCallbacks() throws {
        let recorder = try ReloadRecorder(initialURL: file)
        let watcher = FileWatcher(url: file, debounceInterval: 0.05, onSnapshot: recorder.reload)
        try watcher.start()
        watcher.stop()
        try overwrite(makePDF(pageCount: 25, revision: "after stop"), at: file)
        Thread.sleep(forTimeInterval: 0.5)
        #expect(recorder.loadedPageCounts.isEmpty)
    }

    @Test func testPolicyFiltersUnrelatedFileAndHandlesDroppedEvents() {
        let policy = FileChangePolicy(url: file)
        let modified = FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)
        #expect(policy.affectsFile(path: file.path, flags: modified))
        #expect(!policy.affectsFile(path: directory.appendingPathComponent("unrelated.pdf").path,
                                         flags: modified))
        #expect(policy.affectsFile(path: directory.path, flags: 0))
        #expect(policy.affectsFile(path: "/", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)))
        #expect(!policy.affectsFile(path: file.path, flags: FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone)))
    }

    @Test func testPolicyDeduplicatesByContentRatherThanInodeOrNotificationCount() {
        let first = Data([1, 2, 3])
        var policy = FileChangePolicy(url: file, fingerprint: first)
        let duplicateInitial = policy.accept(fingerprint: first)
        let changed = policy.accept(fingerprint: Data([4, 5, 6]))
        let duplicateChanged = policy.accept(fingerprint: Data([4, 5, 6]))
        let changedBack = policy.accept(fingerprint: first)
        #expect(!duplicateInitial)
        #expect(changed)
        #expect(!duplicateChanged)
        #expect(changedBack)
    }

}

private final class ReloadRecorder {
    private let lock = NSLock()
    private var pages: [Int] = []
    private var failures = 0
    private var displayedDocument: PDFDocument
    var onLoad: ((Int) -> Void)?

    init(initialURL: URL) throws {
        displayedDocument = try PDFDocumentLoader.load(url: initialURL)
    }

    var loadedPageCounts: [Int] { lock.withLock { pages } }
    var failedLoadCount: Int { lock.withLock { failures } }
    var displayedPageCount: Int { lock.withLock { displayedDocument.pageCount } }

    func reload(data: Data) {
        do {
            let document = try PDFDocumentLoader.load(data: data)
            let count = lock.withLock {
                displayedDocument = document
                pages.append(document.pageCount)
                return pages.count
            }
            onLoad?(count)
        } catch {
            lock.withLock { failures += 1 }
        }
    }
}

/// PDFKit creates the fixture directly. No TeX tools, app windows, or input
/// assets are needed to exercise the real macOS FSEvents integration.
func makePDF(pageCount: Int, revision: String) throws -> Data {
    let document = PDFDocument()
    document.documentAttributes = [PDFDocumentAttribute.titleAttribute: "LivePDF test \(revision)"]
    for index in 0..<pageCount {
        let page = PDFPage()
        page.setBounds(CGRect(x: 0, y: 0, width: 612, height: 792), for: .mediaBox)
        page.setBounds(CGRect(x: 0, y: 0, width: 612, height: 792), for: .cropBox)
        document.insert(page, at: index)
    }
    return try #require(document.dataRepresentation())
}

private func overwrite(_ data: Data, at url: URL) throws {
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.truncate(atOffset: 0)
    try handle.write(contentsOf: data)
    try handle.synchronize()
}
