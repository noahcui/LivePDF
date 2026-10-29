import Foundation

/// An offline Markdown subset renderer. Raw HTML is always escaped.
public enum MarkdownRenderer {
    public static func render(_ source: String) -> String {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var parser = Parser(lines: normalized.components(separatedBy: "\n"), context: Context(), depth: 0)
        return parser.render()
    }

    private final class Context { var headingIDs = Set<String>() }
    private struct Marker {
        let indent: Int
        let contentIndent: Int
        let ordered: Bool
        let start: Int
        let content: String
    }

    private struct Parser {
        typealias R = MarkdownRenderer
        let lines: [String]
        let context: Context
        let depth: Int
        var index = 0

        mutating func render(tight: Bool = false) -> String {
            guard depth < 64 else {
                return "<pre><code>\(R.escape(lines.joined(separator: "\n")))</code></pre>"
            }
            var output: [String] = []
            while index < lines.count {
                let line = lines[index]
                if R.trim(line).isEmpty { index += 1; continue }
                if let fence = R.fence(line) {
                    index += 1
                    var code: [String] = []
                    while index < lines.count {
                        let candidate = R.trim(lines[index])
                        let run = candidate.prefix { $0 == fence.mark }.count
                        if R.spaces(lines[index]) <= 3, run >= fence.length,
                           R.trim(String(candidate.dropFirst(run))).isEmpty { break }
                        code.append(String(lines[index].dropFirst(min(fence.indent, R.spaces(lines[index])))))
                        index += 1
                    }
                    if index < lines.count { index += 1 }
                    let language = fence.info.split(whereSeparator: { $0.isWhitespace }).first
                    let attribute = language.map { " class=\"language-\(R.escape(String($0)))\"" } ?? ""
                    let text = code.joined(separator: "\n") + (code.isEmpty ? "" : "\n")
                    output.append("<pre><code\(attribute)>\(R.escape(text))</code></pre>")
                    continue
                }
                if R.spaces(line) >= 4 {
                    var code: [String] = []
                    while index < lines.count, R.trim(lines[index]).isEmpty || R.spaces(lines[index]) >= 4 {
                        code.append(String(lines[index].dropFirst(min(4, R.spaces(lines[index])))))
                        index += 1
                    }
                    while code.last == "" { code.removeLast() }
                    output.append("<pre><code>\(R.escape(code.joined(separator: "\n")))\n</code></pre>")
                    continue
                }
                if let heading = R.heading(line) {
                    output.append(renderHeading(heading.text, level: heading.level))
                    index += 1
                    continue
                }
                if R.rule(line) { output.append("<hr>"); index += 1; continue }
                if R.quote(line) != nil {
                    var quoted: [String] = []
                    while index < lines.count {
                        if let content = R.quote(lines[index]) {
                            quoted.append(content)
                            index += 1
                        } else if R.trim(lines[index]).isEmpty, index + 1 < lines.count, R.quote(lines[index + 1]) != nil {
                            quoted.append("")
                            index += 1
                        } else { break }
                    }
                    var child = Parser(lines: quoted, context: context, depth: depth + 1)
                    output.append("<blockquote>\n\(child.render())\n</blockquote>")
                    continue
                }
                if let marker = R.marker(line) { output.append(renderList(marker)); continue }
                if index + 1 < lines.count, line.contains("|"),
                   let alignment = R.tableAlignment(lines[index + 1]), R.cells(line).count == alignment.count {
                    let headers = R.cells(line)
                    index += 2
                    func row(_ values: [String], tag: String) -> String {
                        let cells = alignment.indices.map { column -> String in
                            let style = alignment[column].isEmpty ? "" : " style=\"text-align: \(alignment[column])\""
                            let value = column < values.count ? values[column] : ""
                            return "<\(tag)\(style)>\(R.inline(value))</\(tag)>"
                        }.joined()
                        return "<tr>\(cells)</tr>"
                    }
                    var rows: [String] = []
                    while index < lines.count, !R.trim(lines[index]).isEmpty,
                          lines[index].contains("|"), !R.startsBlock(lines[index]) {
                        rows.append(row(R.cells(lines[index]), tag: "td"))
                        index += 1
                    }
                    output.append("<table>\n<thead>\(row(headers, tag: "th"))</thead>\n"
                        + "<tbody>\n\(rows.joined(separator: "\n"))\n</tbody>\n</table>")
                    continue
                }
                var paragraph = [line]
                index += 1
                var headingLevel: Int?
                while index < lines.count, !R.trim(lines[index]).isEmpty {
                    if let level = R.setext(lines[index]) { headingLevel = level; index += 1; break }
                    if R.startsBlock(lines[index]) { break }
                    paragraph.append(lines[index])
                    index += 1
                }
                let text = paragraph.joined(separator: "\n")
                if let level = headingLevel { output.append(renderHeading(text, level: level)) }
                else {
                    let html = R.inline(text)
                    output.append(tight ? html : "<p>\(html)</p>")
                }
            }
            return output.joined(separator: "\n")
        }

        private func renderHeading(_ text: String, level: Int) -> String {
            let html = R.inline(text)
            var plain = html.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
            for (entity, character) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] {
                plain = plain.replacingOccurrences(of: entity, with: character)
            }
            var slug = ""
            for character in plain.lowercased() {
                if character.isLetter || character.isNumber || character == "_" { slug.append(character) }
                else if character.isWhitespace || character == "-" {
                    if !slug.isEmpty && !slug.hasSuffix("-") { slug.append("-") }
                }
            }
            while slug.hasSuffix("-") { slug.removeLast() }
            if slug.isEmpty { slug = "section" }
            let base = slug
            var suffix = 1
            while context.headingIDs.contains(slug) { slug = "\(base)-\(suffix)"; suffix += 1 }
            context.headingIDs.insert(slug)
            return "<h\(level) id=\"\(R.escape(slug))\">\(html)</h\(level)>"
        }

        private mutating func renderList(_ first: Marker) -> String {
            var items: [(lines: [String], checked: Bool?)] = []
            var loose = false
            while index < lines.count, let current = R.marker(lines[index]),
                  current.indent == first.indent, current.ordered == first.ordered {
                var body = [current.content]
                var checked: Bool?
                let characters = Array(current.content)
                if characters.count >= 3, characters[0] == "[", characters[2] == "]",
                   [" ", "x", "X"].contains(characters[1]),
                   characters.count == 3 || characters[3].isWhitespace {
                    checked = characters[1] != " "
                    body[0] = String(characters.dropFirst(3).drop(while: { $0.isWhitespace }))
                }
                index += 1
                var pendingBlanks = 0
                while index < lines.count {
                    let next = lines[index]
                    if R.trim(next).isEmpty { pendingBlanks += 1; index += 1; continue }
                    if let sibling = R.marker(next), sibling.indent == first.indent {
                        if sibling.ordered == first.ordered && pendingBlanks > 0 { loose = true }
                        break
                    }
                    if R.spaces(next) <= first.indent, pendingBlanks > 0 || R.startsBlock(next) { break }
                    if pendingBlanks > 0 {
                        body.append(contentsOf: repeatElement("", count: pendingBlanks))
                        loose = true
                        pendingBlanks = 0
                    }
                    body.append(String(next.dropFirst(min(current.contentIndent, R.spaces(next)))))
                    index += 1
                }
                items.append((body, checked))
            }
            let tag = first.ordered ? "ol" : "ul"
            let start = first.ordered && first.start != 1 ? " start=\"\(first.start)\"" : ""
            let taskClass = items.contains { $0.checked != nil } ? " class=\"task-list\"" : ""
            let html = items.map { item -> String in
                var child = Parser(lines: item.lines, context: context, depth: depth + 1)
                var content = child.render(tight: !loose)
                var itemClass = ""
                if let checked = item.checked {
                    itemClass = " class=\"task-list-item\""
                    let checkbox = "<input type=\"checkbox\" disabled" + (checked ? " checked" : "") + "> "
                    if content.hasPrefix("<p>") { content = "<p>" + checkbox + String(content.dropFirst(3)) }
                    else { content = checkbox + content }
                }
                return "<li\(itemClass)>\(content)</li>"
            }.joined(separator: "\n")
            return "<\(tag)\(start)\(taskClass)>\n\(html)\n</\(tag)>"
        }
    }

    private static func trim(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static func spaces(_ value: String) -> Int { value.prefix { $0 == " " }.count }
    private static func escape(_ value: String) -> String {
        var result = ""
        for character in value {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    private static func fence(_ line: String) -> (mark: Character, length: Int, info: String, indent: Int)? {
        let indent = spaces(line)
        guard indent <= 3 else { return nil }
        let text = String(line.dropFirst(indent))
        guard let mark = text.first, mark == "`" || mark == "~" else { return nil }
        let length = text.prefix { $0 == mark }.count
        let info = trim(String(text.dropFirst(length)))
        guard length >= 3, !(mark == "`" && info.contains("`")) else { return nil }
        return (mark, length, info, indent)
    }
    private static func heading(_ line: String) -> (level: Int, text: String)? {
        guard spaces(line) <= 3 else { return nil }
        let text = trim(line)
        let level = text.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let remainder = text.dropFirst(level)
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else { return nil }
        var body = trim(String(remainder))
        let characters = Array(body)
        var end = characters.count
        while end > 0 && characters[end - 1] == "#" { end -= 1 }
        if end < characters.count, end == 0 || characters[end - 1].isWhitespace { body = trim(String(characters[..<end])) }
        return (level, body)
    }
    private static func setext(_ line: String) -> Int? {
        guard spaces(line) <= 3 else { return nil }
        let text = trim(line)
        guard !text.isEmpty else { return nil }
        if text.allSatisfy({ $0 == "=" }) { return 1 }
        if text.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }
    private static func rule(_ line: String) -> Bool {
        guard spaces(line) <= 3 else { return false }
        let text = line.filter { !$0.isWhitespace }
        guard text.count >= 3, let mark = text.first, mark == "-" || mark == "*" || mark == "_" else { return false }
        return text.allSatisfy { $0 == mark }
    }
    private static func quote(_ line: String) -> String? {
        guard spaces(line) <= 3 else { return nil }
        let text = line.dropFirst(spaces(line))
        guard text.first == ">" else { return nil }
        var body = text.dropFirst()
        if body.first == " " { body = body.dropFirst() }
        return String(body)
    }
    private static func marker(_ line: String) -> Marker? {
        let characters = Array(line)
        let indent = spaces(line)
        guard indent < characters.count else { return nil }
        var i = indent
        var ordered = false
        var start = 1
        if ["-", "+", "*"].contains(characters[i]) { i += 1 }
        else {
            let begin = i
            while i < characters.count, "0123456789".contains(characters[i]) { i += 1 }
            guard i > begin, i - begin <= 9, i < characters.count,
                  characters[i] == "." || characters[i] == ")" else { return nil }
            ordered = true
            start = Int(String(characters[begin..<i])) ?? 1
            i += 1
        }
        guard i == characters.count || characters[i].isWhitespace else { return nil }
        let markerEnd = i
        while i < characters.count, characters[i].isWhitespace { i += 1 }
        return Marker(indent: indent, contentIndent: max(markerEnd + 1, i), ordered: ordered,
                      start: start, content: String(characters[i...]))
    }
    private static func startsBlock(_ line: String) -> Bool {
        spaces(line) >= 4 || fence(line) != nil || heading(line) != nil || rule(line) || quote(line) != nil || marker(line) != nil
    }
    private static func cells(_ line: String) -> [String] {
        let characters = Array(trim(line))
        var result = [""]
        var i = 0
        var codeRun = 0
        var leading = false
        var trailing = false
        while i < characters.count {
            let character = characters[i]
            if character == "\\", i + 1 < characters.count {
                result[result.count - 1] += String(characters[i...i + 1])
                i += 2
                trailing = false
                continue
            }
            if character == "`" {
                let length = run(characters, at: i, mark: "`")
                if codeRun == 0 { codeRun = length }
                else if codeRun == length { codeRun = 0 }
                result[result.count - 1] += String(repeating: "`", count: length)
                i += length
                trailing = false
                continue
            }
            if character == "|" && codeRun == 0 {
                if i == 0 { leading = true }
                result.append("")
                trailing = true
            } else {
                result[result.count - 1].append(character)
                trailing = false
            }
            i += 1
        }
        if leading { result.removeFirst() }
        if trailing && !result.isEmpty { result.removeLast() }
        return result.map { trim($0) }
    }
    private static func tableAlignment(_ line: String) -> [String]? {
        let values = cells(line)
        guard !values.isEmpty else { return nil }
        var alignment: [String] = []
        for value in values {
            var body = value
            let left = body.hasPrefix(":")
            let right = body.hasSuffix(":")
            if left { body.removeFirst() }
            if right && !body.isEmpty { body.removeLast() }
            guard body.count >= 3, body.allSatisfy({ $0 == "-" }) else { return nil }
            alignment.append(left && right ? "center" : left ? "left" : right ? "right" : "")
        }
        return alignment
    }
    private static func safeURL(_ raw: String) -> String? {
        let value = trim(raw)
        guard !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return nil }
        if let colon = value.firstIndex(of: ":") {
            let prefix = value[..<colon]
            if !prefix.contains("/"), !prefix.contains("?"), !prefix.contains("#") {
                guard ["http", "https", "mailto", "file"].contains(prefix.lowercased()) else { return nil }
            }
        }
        return value
    }
    private static func run(_ characters: [Character], at index: Int, mark: Character) -> Int {
        var end = index
        while end < characters.count && characters[end] == mark { end += 1 }
        return end - index
    }
    private static func closingRun(_ characters: [Character], from start: Int, mark: Character,
                                   length: Int, flanking: Bool) -> Int? {
        var i = start
        while i < characters.count {
            if characters[i] == "\\", mark != "`" { i += 2; continue }
            if characters[i] == "`", mark != "`" {
                let count = run(characters, at: i, mark: "`")
                if let close = closingRun(characters, from: i + count, mark: "`", length: count, flanking: false) {
                    i = close + count
                    continue
                }
            }
            if characters[i] == mark {
                let count = run(characters, at: i, mark: mark)
                if count == length, !flanking || (i > start && !characters[i - 1].isWhitespace) { return i }
                i += count
            } else { i += 1 }
        }
        return nil
    }
    private static func closingBracket(_ characters: [Character], from start: Int) -> Int? {
        var depth = 1
        var i = start + 1
        while i < characters.count {
            if characters[i] == "\\" { i += 2; continue }
            if characters[i] == "[" { depth += 1 }
            if characters[i] == "]" { depth -= 1; if depth == 0 { return i } }
            i += 1
        }
        return nil
    }
    private static func destination(_ characters: [Character], from start: Int) -> (url: String, title: String?, end: Int)? {
        guard start < characters.count, characters[start] == "(" else { return nil }
        var i = start + 1
        while i < characters.count && characters[i].isWhitespace { i += 1 }
        var url = ""
        if i < characters.count, characters[i] == "<" {
            i += 1
            let begin = i
            while i < characters.count && characters[i] != ">" && characters[i] != "\n" { i += 1 }
            guard i < characters.count, characters[i] == ">" else { return nil }
            url = String(characters[begin..<i])
            i += 1
        } else {
            let begin = i
            var depth = 0
            while i < characters.count {
                if characters[i] == "\\", i + 1 < characters.count { i += 2; continue }
                if characters[i] == "(" { depth += 1 }
                if characters[i] == ")" { if depth == 0 { break }; depth -= 1 }
                if characters[i].isWhitespace && depth == 0 { break }
                i += 1
            }
            url = String(characters[begin..<i])
        }
        let urlEnd = i
        while i < characters.count && characters[i].isWhitespace { i += 1 }
        var title: String?
        if i < characters.count, characters[i] != ")" {
            guard i > urlEnd, characters[i] == "\"" || characters[i] == "'" || characters[i] == "(" else { return nil }
            let end: Character = characters[i] == "(" ? ")" : characters[i]
            i += 1
            let begin = i
            while i < characters.count && characters[i] != end {
                if characters[i] == "\\" && i + 1 < characters.count { i += 1 }
                i += 1
            }
            guard i < characters.count else { return nil }
            title = unescape(String(characters[begin..<i]))
            i += 1
            while i < characters.count && characters[i].isWhitespace { i += 1 }
        }
        guard i < characters.count, characters[i] == ")" else { return nil }
        return (unescape(url), title, i + 1)
    }
    private static let escapable = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
    private static func unescape(_ value: String) -> String {
        let characters = Array(value)
        var output = ""
        var i = 0
        while i < characters.count {
            if characters[i] == "\\", i + 1 < characters.count, escapable.contains(characters[i + 1]) { i += 1 }
            output.append(characters[i])
            i += 1
        }
        return output
    }
    private static func inline(_ source: String, depth: Int = 0, links: Bool = true) -> String {
        guard depth < 32 else { return escape(source) }
        let characters = Array(source)
        var output = ""
        var i = 0
        while i < characters.count {
            let character = characters[i]
            if character == "\\", i + 1 < characters.count {
                if characters[i + 1] == "\n" { output += "<br>\n"; i += 2; continue }
                if escapable.contains(characters[i + 1]) { output += escape(String(characters[i + 1])); i += 2; continue }
            }
            if character == "\n" {
                if output.hasSuffix("  ") {
                    while output.last == " " { output.removeLast() }
                    output += "<br>\n"
                } else { output += "\n" }
                i += 1
                continue
            }
            if character == "`" {
                let length = run(characters, at: i, mark: "`")
                if let close = closingRun(characters, from: i + length, mark: "`", length: length, flanking: false) {
                    var code = String(characters[i + length..<close]).replacingOccurrences(of: "\n", with: " ")
                    if code.hasPrefix(" "), code.hasSuffix(" "), code.contains(where: { $0 != " " }) {
                        code.removeFirst()
                        code.removeLast()
                    }
                    output += "<code>\(escape(code))</code>"
                    i = close + length
                    continue
                }
                output += String(repeating: "`", count: length)
                i += length
                continue
            }
            let image = character == "!" && i + 1 < characters.count && characters[i + 1] == "["
            if image || (character == "[" && links) {
                let opening = image ? i + 1 : i
                if let close = closingBracket(characters, from: opening), let target = destination(characters, from: close + 1) {
                    let label = String(characters[opening + 1..<close])
                    if let url = safeURL(target.url) {
                        let title = target.title.map { " title=\"\(escape($0))\"" } ?? ""
                        if image { output += "<img src=\"\(escape(url))\" alt=\"\(escape(unescape(label)))\"\(title)>" }
                        else { output += "<a href=\"\(escape(url))\"\(title)>" + inline(label, depth: depth + 1, links: false) + "</a>" }
                    } else { output += image ? escape(label) : inline(label, depth: depth + 1, links: false) }
                    i = target.end
                    continue
                }
            }
            if character == "<", links, let close = characters[(i + 1)...].firstIndex(of: ">") {
                let value = String(characters[i + 1..<close])
                if !value.contains(where: { $0.isWhitespace }), value.contains(":"), let url = safeURL(value) {
                    output += "<a href=\"\(escape(url))\">\(escape(value))</a>"
                    i = close + 1
                    continue
                }
            }
            if character == "*" || character == "_" || character == "~" {
                let count = run(characters, at: i, mark: character)
                let width = character == "~" ? 2 : min(3, count)
                let intraword = character == "_" && i > 0 && (characters[i - 1].isLetter || characters[i - 1].isNumber)
                if count >= width, !intraword, i + width < characters.count, !characters[i + width].isWhitespace,
                   let close = closingRun(characters, from: i + width, mark: character, length: width, flanking: true) {
                    let content = inline(String(characters[i + width..<close]), depth: depth + 1, links: links)
                    if character == "~" { output += "<del>\(content)</del>" }
                    else if width == 3 { output += "<em><strong>\(content)</strong></em>" }
                    else {
                        let tag = width == 2 ? "strong" : "em"
                        output += "<\(tag)>\(content)</\(tag)>"
                    }
                    i = close + width
                    continue
                }
            }
            output += escape(String(character))
            i += 1
        }
        return output
    }
}
