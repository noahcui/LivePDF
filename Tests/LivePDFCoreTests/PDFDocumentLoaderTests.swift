import Foundation
import PDFKit
import Testing
@testable import LivePDFCore

@Suite(.serialized)
struct PDFDocumentLoaderTests {
    @Test func testLoadsPDFKitGeneratedTwentyFourPageDocument() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LivePDF-loader-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try makePDF(pageCount: 24, revision: "loader").write(to: url)

        let document = try PDFDocumentLoader.load(url: url)
        #expect(document.pageCount == 24)
        // The loaded PDF must survive deleting its backing file.
        try FileManager.default.removeItem(at: url)
        #expect(document.page(at: 23) != nil)
        #expect(document.page(at: 23)?.bounds(for: .mediaBox).height == 792)
        #expect(document.dataRepresentation() != nil)
    }

    @Test func testRejectsTruncatedPDFFromWhichPDFKitMightRecoverPages() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LivePDF-truncated-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try makePDF(pageCount: 24, revision: "truncated")
        try data.dropLast(20).write(to: url)
        #expect(throws: (any Error).self) { try PDFDocumentLoader.load(url: url) }
    }

    @Test func testRejectsEmptyAndGarbageData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LivePDF-invalid-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data().write(to: url)
        #expect(throws: (any Error).self) { try PDFDocumentLoader.load(url: url) }
        try Data("not a PDF\n%%EOF".utf8).write(to: url)
        #expect(throws: (any Error).self) { try PDFDocumentLoader.load(url: url) }
    }

    @Test func testRejectsZeroPageDocument() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LivePDF-zero-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        // PDFKit will not serialize an empty PDFDocument, so provide a valid
        // explicit page tree with Count 0 and a correctly indexed xref table.
        let data = zeroPagePDF()
        try data.write(to: url)
        #expect(throws: (any Error).self) { try PDFDocumentLoader.load(url: url) }
        // Some PDFKit versions reject Count 0 during parsing. Independently
        // exercise our replacement guard with PDFKit's own empty document.
        #expect(throws: PDFDocumentLoader.LoadError.noPages) {
            try PDFDocumentLoader.validate(PDFDocument())
        }
    }

    @Test func testEOFValidationAllowsPDFWhitespaceButRejectsTrailingPartialData() throws {
        let data = try makePDF(pageCount: 24, revision: "envelope")
        #expect(PDFDocumentLoader.hasCompleteEnvelope(data + Data([0, 9, 10, 12, 13, 32])))
        #expect(!PDFDocumentLoader.hasCompleteEnvelope(data + Data("unfinished revision".utf8)))
        #expect(!PDFDocumentLoader.hasCompleteEnvelope(Data("%%EOF".utf8)))
    }
}

private func zeroPagePDF() -> Data {
    var pdf = "%PDF-1.4\n"
    var offsets = [Int]()
    let objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [] /Count 0 >>"
    ]
    for (index, object) in objects.enumerated() {
        offsets.append(pdf.utf8.count)
        pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
    }
    let xrefOffset = pdf.utf8.count
    pdf += "xref\n0 3\n0000000000 65535 f \n"
    for offset in offsets {
        pdf += String(format: "%010d 00000 n \n", offset)
    }
    pdf += "trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n"
    return Data(pdf.utf8)
}
