import Foundation

/// A PDF position expressed in page coordinates, independent of AppKit or PDFKit.
/// `pagePoint` may lie just outside the page when the viewport begins in a gutter.
/// Keeping that offset is necessary to restore a continuous scroll view exactly.
public struct ViewState: Equatable, Sendable {
    public enum DisplayMode: Int, Sendable {
        case singlePage = 0
        case singlePageContinuous = 1
        case twoUp = 2
        case twoUpContinuous = 3
    }

    public enum DisplayDirection: Int, Sendable {
        case vertical = 0
        case horizontal = 1
    }

    public struct PageFrame: Equatable, Sendable {
        public let pageIndex: Int
        public let frame: CGRect

        public init(pageIndex: Int, frame: CGRect) {
            self.pageIndex = pageIndex
            self.frame = frame.standardized
        }
    }

    public struct Position: Equatable, Sendable {
        public let pageIndex: Int
        public let pagePoint: CGPoint
    }

    public let pageIndex: Int
    public let pagePoint: CGPoint
    public let scaleFactor: CGFloat
    public let displayMode: DisplayMode
    public let displayDirection: DisplayDirection
    public let displaysPageBreaks: Bool
    public let displaysAsBook: Bool
    public let displayBoxRawValue: Int

    public init(
        pageIndex: Int,
        pagePoint: CGPoint,
        scaleFactor: CGFloat,
        displayMode: DisplayMode = .singlePageContinuous,
        displayDirection: DisplayDirection = .vertical,
        displaysPageBreaks: Bool = true,
        displaysAsBook: Bool = false,
        displayBoxRawValue: Int = 1
    ) {
        self.pageIndex = max(0, pageIndex)
        self.pagePoint = pagePoint
        self.scaleFactor = scaleFactor.isFinite && scaleFactor > 0 ? scaleFactor : 1
        self.displayMode = displayMode
        self.displayDirection = displayDirection
        self.displaysPageBreaks = displaysPageBreaks
        self.displaysAsBook = displaysAsBook
        self.displayBoxRawValue = displayBoxRawValue
    }

    /// Select the page nearest the actual upper-left of the clip view. This also
    /// handles the upper-left being in a page margin or the gap between pages.
    /// Frames and the point must use the same coordinate system; either y axis
    /// direction works because the caller supplies the actual upper-left point.
    public static func anchorPageIndex(
        visibleTopLeft: CGPoint,
        pageFrames: [PageFrame]
    ) -> Int? {
        guard visibleTopLeft.x.isFinite, visibleTopLeft.y.isFinite else { return nil }
        return pageFrames
            .filter { $0.pageIndex >= 0 && $0.frame.width > 0 && $0.frame.height > 0 }
            .min { lhs, rhs in
                let lhsDistance = squaredDistance(from: visibleTopLeft, to: lhs.frame)
                let rhsDistance = squaredDistance(from: visibleTopLeft, to: rhs.frame)
                return lhsDistance == rhsDistance
                    ? lhs.pageIndex < rhs.pageIndex
                    : lhsDistance < rhsDistance
            }?.pageIndex
    }

    /// Resolve against the replacement document. A removed page falls back to
    /// the last page, with its point constrained to that page's bounds. On an
    /// existing page preserve gutter coordinates rather than snapping to an edge.
    public func resolvedPosition(pageBounds: [CGRect]) -> Position? {
        guard !pageBounds.isEmpty else { return nil }
        let index = min(pageIndex, pageBounds.count - 1)
        let bounds = pageBounds[index].standardized
        var point = pagePoint
        if !point.x.isFinite { point.x = bounds.minX }
        if !point.y.isFinite { point.y = bounds.maxY }
        if index != pageIndex {
            point.x = min(max(point.x, bounds.minX), bounds.maxX)
            point.y = min(max(point.y, bounds.minY), bounds.maxY)
        }
        return Position(pageIndex: index, pagePoint: point)
    }

    private static func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
