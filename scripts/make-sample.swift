import CoreGraphics
import CoreText
import Darwin
import Foundation
import PDFKit

// Run with: swift scripts/make-sample.swift build/sample.pdf [pageCount] [revision]
enum SampleError: Error, CustomStringConvertible {
    case usage
    case invalidPageCount
    case cannotCreateContext
    case invalidGeneratedPDF

    var description: String {
        switch self {
        case .usage:
            return "Usage: swift scripts/make-sample.swift OUTPUT.pdf [pageCount=24] [revision=v1]"
        case .invalidPageCount:
            return "pageCount must be a positive integer."
        case .cannotCreateContext:
            return "Could not create the PDF graphics context."
        case .invalidGeneratedPDF:
            return "The generated document did not pass PDFKit validation."
        }
    }
}

func draw(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat,
          in context: CGContext, color: CGColor = CGColor(gray: 0.16, alpha: 1)) {
    let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let string = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
    ])
    let line = CTLineCreateWithAttributedString(string as CFAttributedString)
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
}

func makeSample(at url: URL, pageCount: Int, revision: String) throws {
    guard let storage = CFDataCreateMutable(kCFAllocatorDefault, 0),
          let consumer = CGDataConsumer(data: storage) else {
        throw SampleError.cannotCreateContext
    }
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw SampleError.cannotCreateContext
    }
    for page in 1...pageCount {
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(mediaBox)
        context.textMatrix = .identity
        draw("LivePDF sample — page \(page) of \(pageCount)", x: 48, y: 735, size: 22, in: context)
        draw("Revision: \(revision)", x: 48, y: 705, size: 14, in: context)
        draw("Search for: LivePDF, reload, position, or page \(page)", x: 48, y: 678, size: 11, in: context)
        context.setStrokeColor(CGColor(gray: 0.8, alpha: 1))
        context.move(to: CGPoint(x: 48, y: 662))
        context.addLine(to: CGPoint(x: 564, y: 662))
        context.strokePath()
        for line in 1...26 {
            let y = CGFloat(636 - (line - 1) * 21)
            draw("Page \(page), line \(String(format: "%02d", line)): LivePDF keeps the reading position after reload.",
                 x: 48, y: y, size: 10, in: context)
        }
        draw("Page \(page) / \(pageCount)  |  \(revision)", x: 48, y: 45, size: 10, in: context,
             color: CGColor(gray: 0.4, alpha: 1))
        context.endPDFPage()
    }
    context.closePDF()

    // Round-trip through PDFKit so the sample exercises the same document type
    // as the reader and the automated fixtures, while retaining searchable text.
    guard let document = PDFDocument(data: storage as Data),
          document.pageCount == pageCount,
          document.page(at: 0)?.string?.contains("LivePDF") == true,
          let data = document.dataRepresentation() else {
        throw SampleError.invalidGeneratedPDF
    }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard (1...3).contains(arguments.count) else { throw SampleError.usage }
    let pageCount: Int
    if arguments.count >= 2 {
        guard let parsed = Int(arguments[1]), parsed > 0 else { throw SampleError.invalidPageCount }
        pageCount = parsed
    } else {
        pageCount = 24
    }
    let revision = arguments.count >= 3 ? arguments[2] : "v1"
    let url = URL(fileURLWithPath: arguments[0]).standardizedFileURL
    try makeSample(at: url, pageCount: pageCount, revision: revision)
    print("Created \(pageCount)-page searchable PDF: \(url.path) (\(revision))")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
