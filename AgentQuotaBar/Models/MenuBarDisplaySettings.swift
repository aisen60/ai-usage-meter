import Foundation

/// 菜单栏标签的显示项目设置。
///
/// 纯数据 + 纯逻辑模型：不含 UI、不依赖服务层。
/// 持久化走 UserDefaults（非机密偏好设置），读取失败一律回退默认全开。
struct MenuBarDisplaySettings: Codable, Equatable {

    /// 可切换的显示项目。
    enum Item: String, Codable, CaseIterable {
        /// Cursor Models（Cursor 已用百分比）
        case cursorModels
        /// Other Models（Cursor API 模型已用百分比）
        case otherModels
        /// 本周剩余（Codex 周额度剩余百分比）
        case codexWeeklyRemaining
    }

    /// 是否显示 Cursor Models 胶囊
    var showCursorModels: Bool

    /// 是否显示 Other Models 胶囊
    var showOtherModels: Bool

    /// 是否显示 Codex 本周剩余胶囊
    var showCodexWeeklyRemaining: Bool

    /// 默认设置：三项全开
    static let `default` = MenuBarDisplaySettings(
        showCursorModels: true,
        showOtherModels: true,
        showCodexWeeklyRemaining: true
    )

    /// UserDefaults 存储键
    static let storageKey = "menuBarDisplaySettings"

    // MARK: - Derived

    /// 单个项目的开关值
    func isVisible(_ item: Item) -> Bool {
        switch item {
        case .cursorModels: return showCursorModels
        case .otherModels: return showOtherModels
        case .codexWeeklyRemaining: return showCodexWeeklyRemaining
        }
    }

    /// 当前可见的项目（按菜单栏从左到右的顺序）
    var visibleItems: [Item] {
        Item.allCases.filter { isVisible($0) }
    }

    /// 当前环境中实际可展示的项目。Cursor 集成不可用时仅临时过滤其项目，
    /// 不修改用户偏好，集成恢复后可自动恢复原有设置。
    func visibleItems(cursorAvailable: Bool) -> [Item] {
        visibleItems.filter { item in
            switch item {
            case .cursorModels, .otherModels:
                return cursorAvailable
            case .codexWeeklyRemaining:
                return true
            }
        }
    }

    /// 该项目是否是唯一仍开启的项目（视图据此将其开关置灰）
    func isLastVisible(_ item: Item) -> Bool {
        isVisible(item) && visibleItems.count == 1
    }

    /// 该项目是否是当前环境中唯一仍开启且可用的项目。
    func isLastVisible(_ item: Item, cursorAvailable: Bool) -> Bool {
        isVisible(item) && visibleItems(cursorAvailable: cursorAvailable) == [item]
    }

    // MARK: - Mutation

    /// 返回切换某项目后的新设置。
    ///
    /// 约束：至少保留一个显示项目。若本次操作会导致三项全关，返回 nil 表示拒绝。
    func toggling(_ item: Item, to value: Bool) -> MenuBarDisplaySettings? {
        var next = self
        switch item {
        case .cursorModels: next.showCursorModels = value
        case .otherModels: next.showOtherModels = value
        case .codexWeeklyRemaining: next.showCodexWeeklyRemaining = value
        }
        guard !next.visibleItems.isEmpty else { return nil }
        return next
    }

    /// 返回切换项目后的新设置，并保证当前环境至少有一项可展示。
    func toggling(
        _ item: Item,
        to value: Bool,
        cursorAvailable: Bool
    ) -> MenuBarDisplaySettings? {
        guard let next = toggling(item, to: value),
              !next.visibleItems(cursorAvailable: cursorAvailable).isEmpty else {
            return nil
        }
        return next
    }

    // MARK: - Persistence

    /// 从 UserDefaults 读取设置；无历史数据或数据损坏时回退默认全开。
    static func load(from defaults: UserDefaults = .standard) -> MenuBarDisplaySettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(
                MenuBarDisplaySettings.self, from: data
              ),
              !settings.visibleItems.isEmpty else {
            return .default
        }
        return settings
    }

    /// 写入 UserDefaults。写入失败时静默（内存状态仍然生效）。
    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
