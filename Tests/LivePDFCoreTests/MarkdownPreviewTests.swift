import AppKit
import WebKit
import Testing
@testable import LivePDFCore

@Suite(.serialized)
@MainActor
struct MarkdownPreviewTests {
    @Test func rendersInWebKitAndKeepsVisibleParagraphWhenEarlierContentChanges() async throws {
        try await withPreview { web in
            let body = (0..<80).map { "<p id='p\($0)'>Paragraph \($0) with enough content to read.</p>" }.joined()
            _ = try await web.callAsyncJavaScript("return window.livePDF.render(body)", arguments: ["body": body], in: nil, contentWorld: .page)
            _ = try await web.evaluateJavaScript("document.getElementById('p30').scrollIntoView(); scrollBy(0, 7)")
            let before = try #require(try await web.evaluateJavaScript("document.getElementById('p30').getBoundingClientRect().top") as? Double)
            web.pageZoom = 1.2
            let enlarged = "<h1>New introduction</h1><p>Inserted above the visible paragraph.</p>" + body
            // Capture after zoom settles, then replace the article as a real reload does.
            try await Task.sleep(for: .milliseconds(100))
            let zoomed = try #require(try await web.evaluateJavaScript("document.getElementById('p30').getBoundingClientRect().top") as? Double)
            _ = try await web.callAsyncJavaScript("return window.livePDF.render(body)", arguments: ["body": enlarged], in: nil, contentWorld: .page)
            try await Task.sleep(for: .milliseconds(100))
            let after = try #require(try await web.evaluateJavaScript("document.getElementById('p30').getBoundingClientRect().top") as? Double)
            #expect(abs(before + 7) < 2)
            #expect(abs(after - zoomed) < 2)
            #expect(web.pageZoom == 1.2)
            #expect(try await web.evaluateJavaScript("document.querySelectorAll('p').length") as? Int == 81)
        }
    }

    @Test func searchWrapsInBothDirectionsAndClearingRemovesSelection() async throws {
        try await withPreview { web in
            let body = "<p id='first'>中文 <strong>Search</strong> text</p><p id='second'>中文 search text</p>"
            _ = try await web.callAsyncJavaScript("return window.livePDF.render(body)", arguments: ["body": body], in: nil, contentWorld: .page)
            func find(_ query: String, backwards: Bool = false) async throws -> Bool {
                try await web.callAsyncJavaScript("return window.livePDF.find(query, backwards)",
                    arguments: ["query": query, "backwards": backwards], in: nil, contentWorld: .page) as? Bool == true
            }
            func selectedParagraph() async throws -> String? {
                try await web.evaluateJavaScript("getSelection().anchorNode?.parentElement.closest('p')?.id || ''") as? String
            }
            #expect(try await find("中文 search text"))
            #expect(try await selectedParagraph() == "first")
            #expect(try await find("中文 search text"))
            #expect(try await selectedParagraph() == "second")
            #expect(try await find("中文 search text"))
            #expect(try await selectedParagraph() == "first")
            #expect(try await find("中文 search text", backwards: true))
            #expect(try await selectedParagraph() == "second")
            #expect(try await !find(""))
            #expect(try await web.evaluateJavaScript("getSelection().rangeCount") as? Int == 0)
            #expect(try await !find("Not present in this document"))
            #expect(try await web.evaluateJavaScript("getSelection().toString()") as? String == "")
        }
    }

    private func withPreview(_ test: (WKWebView) async throws -> Void) async throws {
        _ = NSApplication.shared
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(PreviewTestSchemeHandler(), forURLScheme: "livepdf-resource")
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let window = NSWindow(contentRect: web.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = web
        window.isReleasedWhenClosed = false
        defer { web.stopLoading(); window.close() }
        web.loadHTMLString(MarkdownPreviewPage.html, baseURL: URL(string: "livepdf-resource://document/"))
        var ready = false
        var lastError = ""
        for _ in 0..<400 {
            do {
                if try await web.evaluateJavaScript("typeof window.livePDF === 'object'") as? Bool == true {
                    ready = true
                    break
                }
            } catch { lastError = String(describing: error) }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(ready, "WebKit did not load preview shell: \(lastError), URL: \(web.url?.absoluteString ?? "nil"), loading: \(web.isLoading)")
        guard ready else { return }
        try await test(web)
    }
}

private final class PreviewTestSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        urlSchemeTask.didFailWithError(CocoaError(.fileNoSuchFile))
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
