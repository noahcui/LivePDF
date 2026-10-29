import CoreServices
import Foundation

/// Watches the containing directory, not a descriptor for the document's old inode.
/// Its callback runs on a private serial queue after the file becomes quiet.
/// Keep the watcher alive for the lifetime of the document window.
public final class FileWatcher {
    public enum WatchError: Error, LocalizedError {
        case cannotCreateStream
        case cannotStartStream

        public var errorDescription: String? {
            switch self {
            case .cannotCreateStream: return L10n.text("Could not create the document directory watcher.")
            case .cannotStartStream: return L10n.text("Could not start the document directory watcher.")
            }
        }
    }

    private let state: WatchState

    public convenience init(url: URL, debounceInterval: TimeInterval = 0.3,
                            onChange: @escaping () -> Void) {
        self.init(url: url, debounceInterval: debounceInterval, onSnapshot: { _ in onChange() })
    }

    /// Supplies the same stable bytes used for deduplication. Parse these bytes
    /// on the document's loader queue rather than reopening a moving filename.
    public init(url: URL, debounceInterval: TimeInterval = 0.3,
                onSnapshot: @escaping (Data) -> Void) {
        state = WatchState(url: url, debounceInterval: debounceInterval, onSnapshot: onSnapshot)
    }

    public func start() throws { try state.synchronously { try state.start() } }

    public func stop() { state.synchronously { state.stop() } }

    deinit { stop() }
}

/// Pure event filtering/deduplication; this has no AppKit or PDFView dependency.
struct FileChangePolicy {
    let filePath: String
    let directoryPath: String
    private(set) var lastFingerprint: Data?

    init(url: URL, fingerprint: Data? = nil) {
        filePath = url.standardizedFileURL.path
        directoryPath = url.deletingLastPathComponent().standardizedFileURL.path
        lastFingerprint = fingerprint
    }

    func affectsFile(path: String, flags: FSEventStreamEventFlags) -> Bool {
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) != 0 {
            return false
        }
        let recoveryFlags = kFSEventStreamEventFlagMustScanSubDirs
            | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
            | kFSEventStreamEventFlagEventIdsWrapped | kFSEventStreamEventFlagRootChanged
        if flags & FSEventStreamEventFlags(recoveryFlags) != 0 { return true }
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        // FSEvents may coalesce multiple file operations into a directory event.
        return normalizedPath == filePath || normalizedPath == directoryPath
    }

    mutating func accept(fingerprint: Data) -> Bool {
        guard fingerprint != lastFingerprint else { return false }
        lastFingerprint = fingerprint
        return true
    }

}

private final class WatchState {
    let url: URL
    let debounceInterval: TimeInterval
    let onSnapshot: (Data) -> Void
    let queue = DispatchQueue(label: "app.livepdf.file-watcher", qos: .utility)
    let queueKey = DispatchSpecificKey<UInt8>()
    var stream: FSEventStreamRef?
    var timer: DispatchSourceTimer?
    var policy: FileChangePolicy
    var isRunning = false

    init(url: URL, debounceInterval: TimeInterval, onSnapshot: @escaping (Data) -> Void) {
        // Resolve the directory's symlinks (including macOS /tmp -> /private/tmp)
        // without resolving the watched filename to an inode that may disappear.
        let directory = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
        self.url = directory.appendingPathComponent(url.lastPathComponent)
        self.debounceInterval = debounceInterval.isFinite ? max(0.01, debounceInterval) : 0.3
        self.onSnapshot = onSnapshot
        policy = FileChangePolicy(url: self.url)
        queue.setSpecific(key: queueKey, value: 1)
    }

    func synchronously<T>(_ operation: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil { return try operation() }
        return try queue.sync(execute: operation)
    }

    func start() throws {
        guard !isRunning else { return }
        policy = FileChangePolicy(url: url, fingerprint: (try? FileSnapshot.read(url: url))?.fingerprint)

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { pointer in
                guard let pointer else { return nil }
                _ = Unmanaged<WatchState>.fromOpaque(pointer).retain()
                return UnsafeRawPointer(pointer)
            },
            release: { pointer in
                guard let pointer else { return }
                Unmanaged<WatchState>.fromOpaque(pointer).release()
            },
            copyDescription: nil
        )
        let flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, count, paths, eventFlags, _ in
                guard let info else { return }
                let state = Unmanaged<WatchState>.fromOpaque(info).takeUnretainedValue()
                let eventPaths = unsafeBitCast(paths, to: NSArray.self)
                for index in 0..<count {
                    if let path = eventPaths[index] as? String,
                       state.policy.affectsFile(path: path, flags: eventFlags[index]) {
                        state.scheduleChange()
                        break
                    }
                }
            },
            &context,
            [url.deletingLastPathComponent().path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            min(debounceInterval / 4, 0.05),
            FSEventStreamCreateFlags(flags)
        ) else { throw FileWatcher.WatchError.cannotCreateStream }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            throw FileWatcher.WatchError.cannotStartStream
        }
        isRunning = true

        // Cover a replacement between the initial fingerprint and stream start.
        scheduleChange()
    }

    func stop() {
        isRunning = false
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    func scheduleChange() {
        guard isRunning else { return }
        if timer == nil {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.setEventHandler { [weak self] in self?.deliverChange() }
            timer.resume()
            self.timer = timer
        }
        timer?.schedule(deadline: .now() + debounceInterval, leeway: .milliseconds(10))
    }

    func deliverChange() {
        guard isRunning else { return }
        // A removed/mid-write file leaves the old document untouched. Its next event
        // retries naturally, while this directory stream stays alive.
        guard let snapshot = try? FileSnapshot.read(url: url),
              policy.accept(fingerprint: snapshot.fingerprint) else { return }
        onSnapshot(snapshot.data)
    }
}
