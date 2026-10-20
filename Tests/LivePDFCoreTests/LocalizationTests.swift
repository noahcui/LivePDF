import Foundation
import Testing
@testable import LivePDFCore

@Suite(.serialized)
struct LocalizationTests {
    private let errorKey = "The PDF has not finished writing."

    @Test func englishRegionalPreferencesReadShippedEnglishTable() throws {
        let bundle = try resourceBundle()
        let expected = try shippedStrings(language: "en")
        let value = try #require(expected[errorKey])
        for preference in ["en", "en-US", "en-GB"] {
            let localization = Localization(bundle: bundle, preferredLanguages: [preference])
            #expect(localization.selectedLanguage == "en")
            #expect(localization.text(errorKey) == value)
        }
    }

    @Test func simplifiedChinesePreferencesReadShippedChineseTable() throws {
        let bundle = try resourceBundle()
        let expected = try shippedStrings(language: "zh-Hans")
        let value = try #require(expected[errorKey])
        #expect(value != errorKey)
        for preference in ["zh-Hans", "zh-CN", "zh-SG"] {
            let localization = Localization(bundle: bundle, preferredLanguages: [preference])
            #expect(localization.selectedLanguage == "zh-Hans")
            #expect(localization.text(errorKey) == value)
        }
    }

    @Test func unsupportedLanguagesFallBackToEnglish() throws {
        let bundle = try resourceBundle()
        for preferences in [["fr-FR"], ["de-DE", "ja-JP"], []] {
            let localization = Localization(bundle: bundle, preferredLanguages: preferences)
            #expect(localization.selectedLanguage == "en")
            #expect(localization.text(errorKey) == errorKey)
        }
    }

    @Test func laterSupportedPreferenceWinsOverEnglishFallback() throws {
        let localization = Localization(
            bundle: try resourceBundle(), preferredLanguages: ["fr-FR", "zh-CN", "en-GB"]
        )
        #expect(localization.selectedLanguage == "zh-Hans")
    }

    @Test func localizedPlaceholdersPreserveUnicodePathsAndPageCounts() throws {
        let bundle = try resourceBundle()
        let path = "/论文 α/有 空格的文档.pdf"
        let english = Localization(bundle: bundle, preferredLanguages: ["en-GB"])
        let chinese = Localization(bundle: bundle, preferredLanguages: ["zh-CN"])
        #expect(english.format("Page %ld of %ld", 5, 24) == "Page 5 of 24")
        #expect(chinese.format("Page %ld of %ld", 5, 24) == "第 5 页，共 24 页")
        #expect(english.format("Could not open %@", path) == "Could not open \(path)")
        #expect(chinese.format("Could not open %@", path) == "无法打开 \(path)")
    }

    @Test func formattingUsesExplicitLocale() throws {
        let localization = Localization(
            bundle: try resourceBundle(), preferredLanguages: ["en"],
            locale: Locale(identifier: "fr_FR")
        )
        // A missing English format key is still a usable fallback format.
        #expect(localization.format("%.2f", 1.5) == "1,50")
    }

    @Test func missingChineseKeyUsesEnglishTableThenReadableKey() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePDF-localization-\(UUID().uuidString).bundle", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeStrings(["fallback.key": "English-only fallback"], language: "en", in: root)
        try writeStrings(["present.key": "已有翻译"], language: "zh-Hans", in: root)
        let bundle = try #require(Bundle(url: root))
        let localization = Localization(bundle: bundle, preferredLanguages: ["zh-CN"])
        #expect(localization.text("present.key") == "已有翻译")
        #expect(localization.text("fallback.key") == "English-only fallback")
        #expect(localization.text("A missing English sentence.") == "A missing English sentence.")
    }

    private func resourceBundle() throws -> Bundle {
        try #require(Bundle(url: resourcesURL))
    }

    private var resourcesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Localizations", isDirectory: true)
    }

    private func shippedStrings(language: String) throws -> [String: String] {
        let url = resourcesURL.appendingPathComponent("\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        return try #require(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String])
    }

    private func writeStrings(_ strings: [String: String], language: String, in root: URL) throws {
        let directory = root.appendingPathComponent("\(language).lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: strings, format: .binary, options: 0)
        try data.write(to: directory.appendingPathComponent("Localizable.strings"))
    }
}
