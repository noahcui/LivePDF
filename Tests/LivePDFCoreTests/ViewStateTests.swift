import Foundation
import Testing
@testable import LivePDFCore

struct ViewStateTests {
    @Test
    func testCaptureUsesViewportCornerInsteadOfPageCenter() {
        let frames = (0..<24).map { index in
            ViewState.PageFrame(
                pageIndex: index,
                frame: CGRect(x: 20, y: CGFloat(index) * 810, width: 600, height: 800)
            )
        }
        // The viewport is halfway down page 5 even if its center is on page 6.
        #expect(ViewState.anchorPageIndex(
            visibleTopLeft: CGPoint(x: 20, y: 4 * 810 + 400), pageFrames: frames
        ) == 4)
    }

    @Test
    func testCornerInMarginOrPageGapFindsNearestPage() {
        let frames = [
            ViewState.PageFrame(pageIndex: 0, frame: CGRect(x: 50, y: 0, width: 600, height: 800)),
            ViewState.PageFrame(pageIndex: 1, frame: CGRect(x: 50, y: 820, width: 600, height: 800))
        ]
        #expect(ViewState.anchorPageIndex(
            visibleTopLeft: CGPoint(x: 0, y: 400), pageFrames: frames
        ) == 0)
        #expect(ViewState.anchorPageIndex(
            visibleTopLeft: CGPoint(x: 0, y: 818), pageFrames: frames
        ) == 1)
    }

    @Test
    func testNonFlippedCoordinatesAndTwoPageSpreads() {
        let frames = [
            ViewState.PageFrame(pageIndex: 2, frame: CGRect(x: 0, y: 900, width: 600, height: 800)),
            ViewState.PageFrame(pageIndex: 3, frame: CGRect(x: 620, y: 900, width: 600, height: 800)),
            ViewState.PageFrame(pageIndex: 4, frame: CGRect(x: 0, y: 80, width: 600, height: 800))
        ]
        #expect(ViewState.anchorPageIndex(
            visibleTopLeft: CGPoint(x: 30, y: 1500), pageFrames: frames
        ) == 2)
        #expect(ViewState.anchorPageIndex(
            visibleTopLeft: CGPoint(x: 700, y: 1500), pageFrames: frames
        ) == 3)
    }

    @Test
    func testShorterReplacementClampsToLastPage() {
        let state = ViewState(pageIndex: 19, pagePoint: CGPoint(x: 42, y: 400), scaleFactor: 1.75)
        let position = state.resolvedPosition(pageBounds: Array(
            repeating: CGRect(x: 0, y: 0, width: 612, height: 792), count: 7
        ))
        #expect(position?.pageIndex == 6)
        #expect(position?.pagePoint == CGPoint(x: 42, y: 400))
        #expect(state.scaleFactor == 1.75)
    }

    @Test
    func testRemovedPagePointClampsToNewPageBoundsIncludingCropOrigin() {
        let state = ViewState(pageIndex: 19, pagePoint: CGPoint(x: -30, y: 900), scaleFactor: 2)
        let position = state.resolvedPosition(pageBounds: [CGRect(x: 10, y: 20, width: 500, height: 700)])
        #expect(position?.pageIndex == 0)
        #expect(position?.pagePoint == CGPoint(x: 10, y: 720))
    }

    @Test
    func testExistingPagePreservesGutterOffsetAndAllDisplayPreferences() {
        let state = ViewState(
            pageIndex: 4, pagePoint: CGPoint(x: -28, y: 401.25), scaleFactor: 1.625,
            displayMode: .twoUpContinuous, displayDirection: .horizontal,
            displaysPageBreaks: false, displaysAsBook: true, displayBoxRawValue: 0
        )
        let position = state.resolvedPosition(pageBounds: Array(
            repeating: CGRect(x: 0, y: 0, width: 612, height: 792), count: 24
        ))
        #expect(position?.pageIndex == 4)
        #expect(position?.pagePoint == state.pagePoint)
        #expect(state.displayMode == .twoUpContinuous)
        #expect(state.displayDirection == .horizontal)
        #expect(!state.displaysPageBreaks)
        #expect(state.displaysAsBook)
        #expect(state.displayBoxRawValue == 0)
        #expect(state.scaleFactor == 1.625)
    }

    @Test
    func testInvalidOrEmptyGeometryReturnsNoPosition() {
        let state = ViewState(pageIndex: 3, pagePoint: .zero, scaleFactor: 1)
        #expect(state.resolvedPosition(pageBounds: []) == nil)
        #expect(ViewState.anchorPageIndex(visibleTopLeft: .zero, pageFrames: []) == nil)
        #expect(ViewState.anchorPageIndex(
            visibleTopLeft: .zero,
            pageFrames: [ViewState.PageFrame(pageIndex: 0, frame: .zero)]
        ) == nil)
    }

    @Test
    func testInvalidZoomAndCoordinatesHaveFiniteFallbacks() {
        let state = ViewState(pageIndex: -1, pagePoint: CGPoint(x: CGFloat.nan, y: .infinity), scaleFactor: .nan)
        let position = state.resolvedPosition(pageBounds: [CGRect(x: 10, y: 20, width: 500, height: 700)])
        #expect(state.pageIndex == 0)
        #expect(state.scaleFactor == 1)
        #expect(position?.pagePoint == CGPoint(x: 10, y: 720))
    }
}
