import Foundation

/// Resolves a language once, then reads that language's actual .strings table.
/// English keys remain readable when a translation or resource is missing.
public struct Localization {
    public let selectedLanguage: String
    public let locale: Locale

    private let languageBundle: Bundle?
    private let englishBundle: Bundle?

    public init(bundle: Bundle, preferredLanguages: [String], locale: Locale? = nil) {
        // Foundation handles regional/script matching, e.g. en-GB -> en and
        // zh-CN/zh-SG -> zh-Hans. Put English first for unsupported preferences.
        let available = ["en"] + bundle.localizations
            .filter { $0 != "en" && $0 != "Base" }
            .sorted()
        let preferences = preferredLanguages.isEmpty ? ["en"] : preferredLanguages
        selectedLanguage = Bundle.preferredLocalizations(
            from: available, forPreferences: preferences
        ).first ?? "en"
        self.locale = locale ?? Locale(identifier: selectedLanguage)
        languageBundle = Self.localizedBundle(in: bundle, language: selectedLanguage)
        englishBundle = Self.localizedBundle(in: bundle, language: "en")
    }

    public func text(_ key: String) -> String {
        Self.lookup(key, in: languageBundle)
            ?? Self.lookup(key, in: englishBundle)
            ?? key
    }

    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(key, arguments: arguments)
    }

    fileprivate func formatted(_ key: String, arguments: [CVarArg]) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private static func localizedBundle(in bundle: Bundle, language: String) -> Bundle? {
        guard let path = bundle.path(forResource: language, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    private static func lookup(_ key: String, in bundle: Bundle?) -> String? {
        guard let bundle else { return nil }
        let missing = "\u{1F}LivePDF.MissingLocalization\u{1F}"
        let value = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
        return value == missing ? nil : value
    }
}

/// Application-facing localization uses Foundation's per-app language choice.
public enum L10n {
    private static let current = Localization(
        bundle: .main,
        preferredLanguages: Bundle.main.preferredLocalizations,
        locale: .current
    )

    public static func text(_ key: String) -> String { current.text(key) }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        current.formatted(key, arguments: arguments)
    }
}
