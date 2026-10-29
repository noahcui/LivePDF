import Foundation
import Testing
@testable import LivePDFCore

struct MarkdownRendererTests {
    @Test func headingsEmphasisCodeAndQuotes() {
        let html = MarkdownRenderer.render("# Hello 中文\n\n**bold** and *emphasis* and ~~removed~~ and `a < b`\n\n> A quotation\n\n```swift\nlet x = \"<script>\"\n```\n")
        #expect(html.contains("<h1"))
        #expect(html.contains("Hello 中文</h1>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>emphasis</em>"))
        #expect(html.contains("<del>removed</del>"))
        #expect(html.contains("<code>a &lt; b</code>"))
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("<pre><code"))
        #expect(!html.contains("<script>"))
    }

    @Test func tablesListsAndRelativeLinks() {
        let html = MarkdownRenderer.render("| Name | Value |\n| --- | --- |\n| **Alpha** | 12 |\n\n- [x] Complete\n- [ ] Pending\n\n3. Third\n4. Fourth\n\n[Next](notes.md) ![图](assets/图.png)\n")
        #expect(html.contains("<table>"))
        #expect(html.contains("<th"))
        #expect(html.contains("<strong>Alpha</strong>"))
        #expect(html.contains("<ul"))
        #expect(html.contains("type=\"checkbox\""))
        #expect(html.contains("disabled"))
        #expect(html.contains("checked"))
        #expect(html.contains("<ol"))
        #expect(html.contains("href=\"notes.md\""))
        #expect(html.contains("src=\"assets/"))
    }

    @Test func documentCannotInjectHTMLAttributesOrExecutableLinks() {
        let html = MarkdownRenderer.render(#"""
        <script>window.pwned=true</script>
        <img src=x onerror=alert(1)>
        [bad](javascript:alert(1))
        [bad](JaVaScRiPt:alert(1))
        [bad](data:text/html,evil)
        ![quote" onerror="evil](image.png)
        [good](https://example.com/?a=1&b=2)
        """#)
        #expect(!html.contains("<script>"))
        #expect(!html.contains("<img src=x"))
        #expect(!html.contains("href=\"javascript:"))
        #expect(!html.contains("href=\"JaVaScRiPt:"))
        #expect(!html.contains("href=\"data:"))
        #expect(!html.contains(" onerror=\"evil\""))
        #expect(html.contains("href=\"https://example.com/"))
        #expect(html.contains("&amp;"))
    }

    @Test func codePreservesMarkdownLiterallyAndLineEndingsWork() {
        let html = MarkdownRenderer.render("# CRLF\r\n\r\n```\r\n**literal** <tag>\r\n```\r\n")
        #expect(html.contains("CRLF</h1>"))
        #expect(html.contains("**literal** &lt;tag&gt;"))
        #expect(!html.contains("<strong>literal</strong>"))
        #expect(MarkdownRenderer.render("").isEmpty)
    }

    @Test func nestedListsAndUniqueUnicodeHeadingAnchors() {
        let html = MarkdownRenderer.render("# 开始使用\n\n# 开始使用\n\n- Parent\n  - Child\n  - Another\n- Sibling\n\nAfter the list.\n")
        #expect(html.contains("id=\"开始使用\""))
        #expect(html.contains("id=\"开始使用-1\""))
        #expect(html.contains("<li>Parent\n<ul>"))
        #expect(html.contains("<li>Child</li>"))
        #expect(html.hasSuffix("<p>After the list.</p>"))
    }

    @Test func incompleteFenceAndEscapedDelimitersRemainReadableWhileTyping() {
        let html = MarkdownRenderer.render("\\*literal\\*\n\n```swift\nlet unfinished = \"<tag>\"")
        #expect(html.contains("<p>*literal*</p>"))
        #expect(html.contains("language-swift"))
        #expect(html.contains("&lt;tag&gt;"))
        #expect(html.hasSuffix("</code></pre>"))
    }
}
