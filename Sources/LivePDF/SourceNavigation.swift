import Foundation

/// Phase-two boundary for SyncTeX. Keep source navigation independent of file
/// watching and view restoration; a future adapter can invoke synctex here.
protocol SourceNavigationProvider {
    func sourceLocation(forPDF url: URL, pageIndex: Int, point: CGPoint) async throws -> SourceLocation?
    func pdfLocation(forSource location: SourceLocation, pdfURL: URL) async throws -> PDFSourceLocation?
}

struct SourceLocation {
    let url: URL
    let line: Int
    let column: Int
}

struct PDFSourceLocation {
    let pageIndex: Int
    let point: CGPoint
}
