import Foundation

/// 应用界面支持的语言。偏好仅保存语言标识，不含任何账户或服务数据。
enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static let storageKey = "appLanguage"
    static let defaultLanguage: AppLanguage = .simplifiedChinese

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: storageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return defaultLanguage
        }
        return language
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    /// 供不在 SwiftUI `Text` 上下文中的动态文案使用指定的应用语言。
    static func localized(
        _ key: String,
        locale: Locale,
        arguments: CVarArg...
    ) -> String {
        let format = localizationBundle(for: locale).localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private static func localizationBundle(for locale: Locale) -> Bundle {
        guard let path = Bundle.main.path(
            forResource: locale.identifier,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
