import AppKit
import PDFKit
import Testing
@testable import LivePDFCore

@Suite(.serialized)
@MainActor
struct PDFViewStateAdapterTests {
    @Test
    func testActualPDFViewPreservesPageFiveMiddleAfterPrecedingPagesGrow() throws {
        let view = makeView(document: makeDocument(pageCount: 24))
        let page = try #require(view.document?.page(at: 4))
        view.go(to: PDFDestination(page: page, at: CGPoint(x: 80, y: 500)))
        view.layoutDocumentView()
        let saved = try #require(PDFViewStateAdapter.capture(from: view))
        #expect(saved.pageIndex == 4)
        #expect(abs(saved.scaleFactor - 1.8) <= 0.001)

        // A changed first-page height makes a saved absolute scroll offset
        // incorrect while page-relative coordinates still restore correctly.
        view.document = makeDocument(pageCount: 24, firstPageExtraHeight: 180)
        PDFViewStateAdapter.restore(saved, in: view)
        let restored = try #require(PDFViewStateAdapter.capture(from: view))
        assertSamePosition(saved, restored)
        #expect(restored.displayMode == saved.displayMode)
        #expect(!view.autoScales)
    }

    @Test
    func testActualPDFViewPreservesRotatedCropBoxCoordinates() throws {
        let document = makeDocument(pageCount: 24, rotatedCropPageIndex: 4)
        let view = makeView(document: document)
        let page = try #require(document.page(at: 4))
        view.go(to: PDFDestination(page: page, at: CGPoint(x: 250, y: 400)))
        view.layoutDocumentView()
        let saved = try #require(PDFViewStateAdapter.capture(from: view))
        #expect(saved.pageIndex == 4)

        view.document = makeDocument(
            pageCount: 24, firstPageExtraHeight: 130, rotatedCropPageIndex: 4
        )
        PDFViewStateAdapter.restore(saved, in: view)
        let restored = try #require(PDFViewStateAdapter.capture(from: view))
        assertSamePosition(saved, restored)
    }

    @Test
    func testActualPDFViewClampsPageTwentyToLastPageOfShorterDocument() throws {
        let view = makeView(document: makeDocument(pageCount: 24))
        let page = try #require(view.document?.page(at: 19))
        view.go(to: PDFDestination(page: page, at: CGPoint(x: 80, y: 500)))
        view.layoutDocumentView()
        let saved = try #require(PDFViewStateAdapter.capture(from: view))
        #expect(saved.pageIndex == 19)

        view.document = makeDocument(pageCount: 7)
        PDFViewStateAdapter.restore(saved, in: view)
        let restored = try #require(PDFViewStateAdapter.capture(from: view))
        #expect(restored.pageIndex == 6)
        #expect(abs(restored.scaleFactor - saved.scaleFactor) <= 0.001)
    }

    private func makeView(document: PDFDocument) -> PDFView {
        _ = NSApplication.shared
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displayBox = .cropBox
        view.displaysPageBreaks = true
        view.autoScales = false
        view.document = document
        view.scaleFactor = 1.8
        view.layoutSubtreeIfNeeded()
        view.layoutDocumentView()
        return view
    }

    /// Generate a real multi-page PDF using PDFKit, without TeX or fixture files.
    private func makeDocument(
        pageCount: Int,
        firstPageExtraHeight: CGFloat = 0,
        rotatedCropPageIndex: Int? = nil
    ) -> PDFDocument {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let page = PDFPage()
            let height = 792 + (index == 0 ? firstPageExtraHeight : 0)
            let bounds = CGRect(x: 0, y: 0, width: 612, height: height)
            page.setBounds(bounds, for: .mediaBox)
            page.setBounds(bounds, for: .cropBox)
            if index == rotatedCropPageIndex {
                page.setBounds(CGRect(x: 17, y: 23, width: 540, height: 700), for: .cropBox)
                page.rotation = 90
            }
            document.insert(page, at: index)
        }
        return document
    }

    private func assertSamePosition(
        _ expected: ViewState, _ actual: ViewState,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.pageIndex == expected.pageIndex, sourceLocation: sourceLocation)
        // Clip origins can be rounded to physical pixels by AppKit.
        #expect(abs(actual.pagePoint.x - expected.pagePoint.x) <= 1, sourceLocation: sourceLocation)
        #expect(abs(actual.pagePoint.y - expected.pagePoint.y) <= 1, sourceLocation: sourceLocation)
        #expect(abs(actual.scaleFactor - expected.scaleFactor) <= 0.001, sourceLocation: sourceLocation)
    }
}
