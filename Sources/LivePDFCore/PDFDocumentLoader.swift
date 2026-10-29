import CryptoKit
import Darwin
import Foundation
import PDFKit

/// Reads a complete, immutable snapshot before asking PDFKit to parse it.
///
/// Call this on a background queue. The returned document owns its bytes, so a
/// compiler can truncate, unlink, or replace the original file immediately.
public enum PDFDocumentLoader {
    public enum LoadError: Error, LocalizedError, Equatable {
        case fileChangedDuringRead
        case incompletePDF
        case invalidPDF
        case noPages

        public var errorDescription: String? {
            switch self {
            case .fileChangedDuringRead: return L10n.text("The file changed while it was being read.")
            case .incompletePDF: return L10n.text("The PDF has not finished writing.")
            case .invalidPDF: return L10n.text("The file could not be read as a PDF.")
            case .noPages: return L10n.text("The PDF does not contain any pages.")
            }
        }
    }

    public static func load(url: URL) throws -> PDFDocument {
        let snapshot = try FileSnapshot.read(url: url)
        return try load(data: snapshot.data)
    }

    /// Parses the exact immutable snapshot supplied by FileWatcher. Do not
    /// reopen the path after hashing: a compiler might already be replacing it.
    public static func load(data: Data) throws -> PDFDocument {
        guard hasCompleteEnvelope(data) else {
            throw LoadError.incompletePDF
        }
        guard let document = PDFDocument(data: data) else {
            throw LoadError.invalidPDF
        }
        try validate(document)
        return document
    }

    /// Kept separate from byte parsing so PDFKit's refusal to parse a zero-page
    /// file cannot prevent testing the empty-document replacement guard.
    static func validate(_ document: PDFDocument) throws {
        guard document.pageCount > 0 else {
            throw LoadError.noPages
        }
        // PDFKit can lazily resolve pages. Resolve every page against our private
        // data now; a broken page tree must not replace the displayed document.
        for index in 0..<document.pageCount {
            guard document.page(at: index) != nil else {
                throw LoadError.invalidPDF
            }
        }
    }

    /// PDFKit repairs many truncated PDFs. Require the final EOF marker instead
    /// so that a syntactically repairable half-written file is never installed.
    static func hasCompleteEnvelope(_ data: Data) -> Bool {
        guard data.count >= 8,
              data.prefix(1024).range(of: Data("%PDF-".utf8)) != nil else {
            return false
        }
        let whitespace: Set<UInt8> = [0, 9, 10, 12, 13, 32]
        var end = data.endIndex
        while end > data.startIndex, whitespace.contains(data[data.index(before: end)]) {
            end = data.index(before: end)
        }
        let marker = Data("%%EOF".utf8)
        guard end >= marker.count else { return false }
        return data[(end - marker.count)..<end].elementsEqual(marker)
    }
}

/// A fingerprint includes nanosecond timestamps and the inode, catching both an
/// in-place write and a rename between opening a file and finishing its read.
struct FileMetadata: Equatable {
    let device: Int32
    let inode: UInt64
    let size: Int64
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int

    init(_ value: stat) {
        device = value.st_dev
        inode = value.st_ino
        size = value.st_size
        modifiedSeconds = value.st_mtimespec.tv_sec
        modifiedNanoseconds = value.st_mtimespec.tv_nsec
        changedSeconds = value.st_ctimespec.tv_sec
        changedNanoseconds = value.st_ctimespec.tv_nsec
    }

    static func read(url: URL) throws -> FileMetadata {
        var value = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return Darwin.fstatat(AT_FDCWD, path, &value, 0)
        }
        guard result == 0 else { throw posixError() }
        return FileMetadata(value)
    }
}

struct FileSnapshot {
    let data: Data
    let metadata: FileMetadata

    var fingerprint: Data { Data(SHA256.hash(data: data)) }

    static func read(url: URL) throws -> FileSnapshot {
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return Darwin.open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK)
        }
        guard descriptor >= 0 else { throw posixError() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }

        var before = stat()
        guard fstat(descriptor, &before) == 0 else { throw posixError() }
        guard (before.st_mode & S_IFMT) == S_IFREG else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let data = try handle.readToEnd() ?? Data()
        var after = stat()
        guard fstat(descriptor, &after) == 0 else { throw posixError() }
        let metadata = FileMetadata(before)
        guard metadata == FileMetadata(after),
              Int64(data.count) == metadata.size,
              metadata == (try FileMetadata.read(url: url)) else {
            throw PDFDocumentLoader.LoadError.fileChangedDuringRead
        }
        return FileSnapshot(data: data, metadata: metadata)
    }
}

private func posixError() -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
}
