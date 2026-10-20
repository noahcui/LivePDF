import AppKit
import PDFKit
import QuartzCore

/// The only UI bridge for ViewState. Capture and restore must run on the main
/// thread, immediately before and after replacing PDFView.document.
public enum PDFViewStateAdapter {
    public static func capture(from pdfView: PDFView) -> ViewState? {
        precondition(Thread.isMainThread)
        guard let document = pdfView.document, document.pageCount > 0,
              let scrollView = enclosingScrollView(in: pdfView) else { return nil }
        let clipView = scrollView.contentView
        let topLeft = CGPoint(
            x: clipView.bounds.minX,
            y: clipView.isFlipped ? clipView.bounds.minY : clipView.bounds.maxY
        )
        let viewPoint = pdfView.convert(topLeft, from: clipView)
        let pageIndex: Int
        if pdfView.displayMode == .singlePage || pdfView.displayMode == .twoUp {
            // Hidden pages have no meaningful layout frame in noncontinuous modes.
            guard let page = pdfView.page(for: viewPoint, nearest: true) ?? pdfView.currentPage else {
                return nil
            }
            pageIndex = document.index(for: page)
        } else {
            let pageFrames = (0..<document.pageCount).compactMap { index -> ViewState.PageFrame? in
                guard let page = document.page(at: index) else { return nil }
                return ViewState.PageFrame(
                    pageIndex: index,
                    frame: pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
                )
            }
            guard let selectedIndex = ViewState.anchorPageIndex(
                visibleTopLeft: viewPoint, pageFrames: pageFrames
            ) else { return nil }
            pageIndex = selectedIndex
        }
        guard pageIndex >= 0, pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else { return nil }
        return ViewState(
            pageIndex: pageIndex,
            pagePoint: pdfView.convert(viewPoint, to: page),
            scaleFactor: pdfView.scaleFactor,
            displayMode: ViewState.DisplayMode(rawValue: pdfView.displayMode.rawValue) ?? .singlePageContinuous,
            displayDirection: ViewState.DisplayDirection(rawValue: pdfView.displayDirection.rawValue) ?? .vertical,
            displaysPageBreaks: pdfView.displaysPageBreaks,
            displaysAsBook: pdfView.displaysAsBook,
            displayBoxRawValue: pdfView.displayBox.rawValue
        )
    }

    public static func restore(_ state: ViewState, in pdfView: PDFView) {
        precondition(Thread.isMainThread)
        guard let document = pdfView.document, document.pageCount > 0 else { return }
        let displayBox = PDFDisplayBox(rawValue: state.displayBoxRawValue) ?? .cropBox
        let bounds = (0..<document.pageCount).map { index in
            document.page(at: index)?.bounds(for: displayBox) ?? .zero
        }
        guard let position = state.resolvedPosition(pageBounds: bounds),
              let page = document.page(at: position.pageIndex) else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        pdfView.displayBox = displayBox
        pdfView.displayMode = PDFDisplayMode(rawValue: state.displayMode.rawValue) ?? .singlePageContinuous
        pdfView.displayDirection = PDFDisplayDirection(rawValue: state.displayDirection.rawValue) ?? .vertical
        pdfView.displaysPageBreaks = state.displaysPageBreaks
        pdfView.displaysAsBook = state.displaysAsBook
        // A saved numerical zoom wins over an automatic fit recalculation.
        pdfView.autoScales = false
        pdfView.scaleFactor = state.scaleFactor
        pdfView.layoutDocumentView()
        pdfView.go(to: page)
        pdfView.layoutDocumentView()

        guard let scrollView = enclosingScrollView(in: pdfView) else {
            pdfView.go(to: PDFDestination(page: page, at: position.pagePoint))
            return
        }
        let clipView = scrollView.contentView
        // Use PDFKit's conversions for crop boxes and rotated pages, then move
        // the clip view so this exact page point returns to the upper-left.
        let viewPoint = pdfView.convert(position.pagePoint, from: page)
        let clipPoint = clipView.convert(viewPoint, from: pdfView)
        let origin = CGPoint(
            x: clipPoint.x,
            y: clipView.isFlipped ? clipPoint.y : clipPoint.y - clipView.bounds.height
        )
        clipView.scroll(to: origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private static func enclosingScrollView(in pdfView: PDFView) -> NSScrollView? {
        if let scrollView = pdfView.documentView?.enclosingScrollView { return scrollView }
        func find(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView { return scrollView }
            for child in view.subviews {
                if let scrollView = find(in: child) { return scrollView }
            }
            return nil
        }
        return find(in: pdfView)
    }
}
