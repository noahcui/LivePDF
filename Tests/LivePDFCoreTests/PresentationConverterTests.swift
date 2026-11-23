import Foundation
import Testing
@testable import LivePDFCore

struct PresentationConverterTests {
    @Test func classifiesPresentationExtensions() {
        for ext in ["pptx", "PPTX", "ppt", "ppsx", "pps"] {
            #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/尚未创建.\(ext)")) == .presentation)
        }
        #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/deck.key")) == nil)
    }

    @Test func rejectsIncompleteFilesBeforeConverting() {
        let header = Data([0x50, 0x4B, 0x03, 0x04])
        let end = Data([0x50, 0x4B, 0x05, 0x06]) + Data(count: 18)
        let body = Data(count: 100)
        #expect(PresentationConverter.hasCompleteEnvelope(header + body + end, fileExtension: "pptx"))
        #expect(PresentationConverter.hasCompleteEnvelope(header + body + end, fileExtension: "PPSX"))
        #expect(!PresentationConverter.hasCompleteEnvelope(header + body, fileExtension: "pptx"))
        #expect(!PresentationConverter.hasCompleteEnvelope(body + end, fileExtension: "pptx"))
        #expect(!PresentationConverter.hasCompleteEnvelope(Data(), fileExtension: "pptx"))

        let ole = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        #expect(PresentationConverter.hasCompleteEnvelope(ole + Data(count: 504), fileExtension: "ppt"))
        #expect(!PresentationConverter.hasCompleteEnvelope(ole, fileExtension: "ppt"))
        #expect(!PresentationConverter.hasCompleteEnvelope(header + body + end, fileExtension: "pps"))

        #expect(throws: PresentationConverter.ConvertError.incompletePresentation) {
            try PresentationConverter.convert(data: header + body, fileExtension: "pptx")
        }
    }

    @Test func keynoteConvertsOnlyWhenPowerPointIsMissing() {
        typealias Engine = PresentationConverter.Engine
        let both: (Engine) -> Bool = { _ in true }
        let keynoteOnly: (Engine) -> Bool = { $0 == .keynote }
        let powerPointOnly: (Engine) -> Bool = { $0 == .powerPoint }
        #expect(PresentationConverter.selectEngine(preferred: nil, isInstalled: both) == .powerPoint)
        #expect(PresentationConverter.selectEngine(preferred: "libreoffice", isInstalled: both) == .powerPoint)
        #expect(PresentationConverter.selectEngine(preferred: nil, isInstalled: keynoteOnly) == .keynote)
        #expect(PresentationConverter.selectEngine(preferred: nil, isInstalled: { _ in false }) == nil)
        // The explicit override still picks Keynote, unless it is not installed.
        #expect(PresentationConverter.selectEngine(preferred: "Keynote", isInstalled: both) == .keynote)
        #expect(PresentationConverter.selectEngine(preferred: "keynote", isInstalled: powerPointOnly) == .powerPoint)
    }

    @Test func classifiesAppleScriptFailures() {
        #expect(PresentationConverter.classify(message: "execution error: AppleEvent timed out. (-1712)", engine: .keynote) == .timedOut("Keynote"))
        #expect(PresentationConverter.classify(message: "Not authorized to send Apple events to Keynote. (-1743)", engine: .keynote) == .notAuthorized("Keynote"))
        #expect(PresentationConverter.classify(message: "boom", engine: .powerPoint) == .failed("Microsoft PowerPoint", "boom"))
    }
}
