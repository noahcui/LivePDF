import AppKit
import Foundation
import PDFKit

/// Converts a PowerPoint file to PDF by scripting an installed presentation
/// application. LivePDF then shows the result through its normal PDF pipeline,
/// so page, zoom, and display mode survive every reload.
///
/// Call this on a background queue: an export takes seconds and may launch the
/// application.
public enum PresentationConverter {
    public enum Engine: String, CaseIterable {
        case powerPoint = "powerpoint"
        case keynote

        public var displayName: String {
            switch self {
            case .powerPoint: return "Microsoft PowerPoint"
            case .keynote: return "Keynote"
            }
        }

        var bundleIdentifiers: [String] {
            switch self {
            case .powerPoint: return ["com.microsoft.Powerpoint"]
            case .keynote: return ["com.apple.Keynote", "com.apple.iWork.Keynote"]
            }
        }

        var installedBundleIdentifier: String? {
            bundleIdentifiers.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        }
    }

    public enum ConvertError: Error, LocalizedError, Equatable {
        case incompletePresentation
        case noConverterInstalled
        case notAuthorized(String)
        case timedOut(String)
        case failed(String, String)

        public var errorDescription: String? {
            switch self {
            case .incompletePresentation:
                return L10n.text("The presentation has not finished writing.")
            case .noConverterInstalled:
                return L10n.text("Showing presentations requires Microsoft PowerPoint or Keynote.")
            case .notAuthorized(let app):
                return L10n.format("Allow LivePDF to control %@ in System Settings → Privacy & Security → Automation.", app)
            case .timedOut(let app):
                return L10n.format("%@ did not respond. It may be showing a dialog.", app)
            case .failed(let app, let detail):
                return L10n.format("%@ could not export the presentation: %@", app, detail)
            }
        }
    }

    /// PowerPoint converts whenever it is installed. Set
    /// `defaults write com.noah.LivePDF PresentationConverter keynote` to use
    /// Keynote instead.
    public static let preferredEngineDefaultsKey = "PresentationConverter"
    public static let timeoutDefaultsKey = "PresentationConversionTimeout"

    /// The one application that converts: the first installed engine in order.
    /// A failure in it is reported, never retried in the other application.
    public static func selectedEngine(preferred: String? = UserDefaults.standard.string(forKey: preferredEngineDefaultsKey)) -> Engine? {
        selectEngine(preferred: preferred) { $0.installedBundleIdentifier != nil }
    }

    static func selectEngine(preferred: String?, isInstalled: (Engine) -> Bool) -> Engine? {
        order(preferred: preferred).first(where: isInstalled)
    }

    static func order(preferred: String?) -> [Engine] {
        guard let preferred = preferred.flatMap({ Engine(rawValue: $0.lowercased()) }) else { return Engine.allCases }
        return [preferred] + Engine.allCases.filter { $0 != preferred }
    }

    /// Returns PDF bytes for the exact presentation snapshot supplied.
    public static func convert(data: Data, fileExtension: String) throws -> Data {
        guard hasCompleteEnvelope(data, fileExtension: fileExtension) else {
            throw ConvertError.incompletePresentation
        }
        guard let engine = selectedEngine() else { throw ConvertError.noConverterInstalled }
        let configured = UserDefaults.standard.double(forKey: timeoutDefaultsKey)
        let timeout = configured.isFinite && configured >= 5 ? configured : 60
        return try convert(data: data, fileExtension: fileExtension, engine: engine, timeout: timeout)
    }

    static func convert(data: Data, fileExtension: String, engine: Engine, timeout: TimeInterval) throws -> Data {
        guard let bundleIdentifier = engine.installedBundleIdentifier else {
            throw ConvertError.noConverterInstalled
        }
        // The application opens a private copy: the user's file may be open for
        // editing in the same application, and its bytes may change at any time.
        let directory = workDirectory(for: engine).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("LivePDF-\(UUID().uuidString.prefix(8)).\(fileExtension.lowercased())")
        let output = directory.appendingPathComponent("export.pdf")
        try data.write(to: input)

        try runScript(script(for: engine, bundleIdentifier: bundleIdentifier),
                      arguments: [input.path, output.path, input.lastPathComponent, String(Int(timeout))],
                      engine: engine, timeout: timeout)
        guard let pdf = try? Data(contentsOf: output), !pdf.isEmpty else {
            throw ConvertError.failed(engine.displayName, L10n.text("No PDF was produced."))
        }
        return pdf
    }

    /// PowerPoint is sandboxed and asks the user to grant access to files outside
    /// its containers, so its copy lives in the Office group container.
    static func workDirectory(for engine: Engine) -> URL {
        let fileManager = FileManager.default
        if engine == .powerPoint {
            let container = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/UBF8T346G9.Office", isDirectory: true)
            if fileManager.isWritableFile(atPath: container.path) {
                return container.appendingPathComponent("LivePDF", isDirectory: true)
            }
        }
        return fileManager.temporaryDirectory.appendingPathComponent("LivePDF-presentations", isDirectory: true)
    }

    /// The bundle identifier comes from the fixed list above, never from a file.
    static func script(for engine: Engine, bundleIdentifier: String) -> String {
        switch engine {
        case .powerPoint:
            return """
            on run argv
                set inFile to POSIX file (item 1 of argv)
                set outPath to (POSIX file (item 2 of argv)) as text
                set docName to item 3 of argv
                with timeout of ((item 4 of argv) as integer) seconds
                    tell application id "\(bundleIdentifier)"
                        open inFile
                        set doc to presentation docName
                        try
                            save doc in outPath as save as PDF
                        on error message number code
                            close doc saving no
                            error message number code
                        end try
                        close doc saving no
                    end tell
                end timeout
            end run
            """
        case .keynote:
            return """
            on run argv
                set inFile to POSIX file (item 1 of argv)
                set outFile to POSIX file (item 2 of argv)
                with timeout of ((item 4 of argv) as integer) seconds
                    tell application id "\(bundleIdentifier)"
                        set doc to open inFile
                        try
                            export doc to outFile as PDF
                        on error message number code
                            close doc saving no
                            error message number code
                        end try
                        close doc saving no
                    end tell
                end timeout
            end run
            """
        }
    }

    private static func runScript(_ script: String, arguments: [String], engine: Engine, timeout: TimeInterval) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"] + arguments
        let input = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            throw ConvertError.failed(engine.displayName, error.localizedDescription)
        }
        input.fileHandleForWriting.write(Data(script.utf8))
        try? input.fileHandleForWriting.close()
        // AppleScript enforces the timeout itself; the margin covers a stuck osascript.
        if finished.wait(timeout: .now() + timeout + 5) == .timedOut {
            process.terminate()
            throw ConvertError.timedOut(engine.displayName)
        }
        guard process.terminationStatus != 0 else { return }
        let data = (try? errors.fileHandleForReading.readToEnd()) ?? nil
        let message = String(decoding: data ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        throw classify(message: message, engine: engine)
    }

    static func classify(message: String, engine: Engine) -> ConvertError {
        if message.contains("(-1712)") { return .timedOut(engine.displayName) }
        if message.contains("(-1743)") { return .notAuthorized(engine.displayName) }
        return .failed(engine.displayName, message)
    }

    /// A half-written file must never reach the converter: .pptx/.ppsx are ZIP
    /// archives ending in a central directory record, .ppt/.pps are OLE files.
    static func hasCompleteEnvelope(_ data: Data, fileExtension: String) -> Bool {
        switch fileExtension.lowercased() {
        case "ppt", "pps":
            return data.count >= 512 && data.prefix(8).elementsEqual([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        default:
            guard data.count >= 22, data.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04]) else { return false }
            // The end record is 22 bytes plus a comment of at most 65535 bytes.
            return data.suffix(22 + 65_535).range(of: Data([0x50, 0x4B, 0x05, 0x06])) != nil
        }
    }
}

/// Loads a presentation as the PDF document produced by PresentationConverter.
public enum PresentationDocumentLoader {
    public static func load(url: URL) throws -> PDFDocument {
        try load(data: FileSnapshot.read(url: url).data, fileExtension: url.pathExtension)
    }

    public static func load(data: Data, fileExtension: String) throws -> PDFDocument {
        try PDFDocumentLoader.load(data: PresentationConverter.convert(data: data, fileExtension: fileExtension))
    }
}
