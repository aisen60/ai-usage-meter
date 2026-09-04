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
        /// On Demand（Cursor 个人按量付费预算）
        case onDemand
        /// ChatGPT 5 小时剩余额度
        case chatgptFiveHour
        /// ChatGPT 1 周剩余额度
        case chatgptWeekly
    }

    /// 是否显示 Cursor Models 胶囊
    var showCursorModels: Bool

    /// 是否显示 Other Models 胶囊
    var showOtherModels: Bool

    /// 是否显示 On Demand 胶囊
    var showOnDemand: Bool

    /// 是否显示 ChatGPT 5 小时胶囊
    var showChatGPTFiveHour: Bool

    /// 是否显示 ChatGPT 1 周胶囊
    var showChatGPTWeekly: Bool

    /// 默认设置：只开启 Cursor Models 与 ChatGPT 5 小时，其余关闭。
    static let `default` = MenuBarDisplaySettings(
        showCursorModels: true,
        showOtherModels: false,
        showOnDemand: false,
        showChatGPTFiveHour: true,
        showChatGPTWeekly: false
    )

    /// UserDefaults 存储键
    static let storageKey = "menuBarDisplaySettings"

    // MARK: - Derived

    /// 单个项目的开关值
    func isVisible(_ item: Item) -> Bool {
        switch item {
        case .cursorModels: return showCursorModels
        case .otherModels: return showOtherModels
        case .onDemand: return showOnDemand
        case .chatgptFiveHour: return showChatGPTFiveHour
        case .chatgptWeekly: return showChatGPTWeekly
        }
    }

    /// 当前可见的项目（按菜单栏从左到右的顺序）
    var visibleItems: [Item] {
        Item.allCases.filter { isVisible($0) }
    }

    /// 当前环境中实际可展示的项目。
    ///
    /// - Cursor 集成不可用时临时过滤两个 Cursor 百分比项目。
    /// - On Demand 无有效个人上限时临时过滤。
    /// - ChatGPT 未安装时临时过滤两项；已安装但断开时渲染中性 `0%`。
    ///
    /// 过滤只影响本次展示，不修改用户偏好，服务或额度恢复后自动恢复。
    func visibleItems(
        cursorAvailable: Bool,
        onDemandAvailable: Bool,
        chatGPTAvailable: Bool = true
    ) -> [Item] {
        visibleItems.filter { item in
            switch item {
            case .cursorModels, .otherModels:
                return cursorAvailable
            case .onDemand:
                return onDemandAvailable
            case .chatgptFiveHour, .chatgptWeekly:
                return chatGPTAvailable
            }
        }
    }

    // MARK: - Mutation

    /// 返回切换某项目后的新设置。
    /// 用户可以关闭全部项目；状态栏会回退为简洁的「AI」标签。
    func toggling(_ item: Item, to value: Bool) -> MenuBarDisplaySettings {
        var next = self
        switch item {
        case .cursorModels: next.showCursorModels = value
        case .otherModels: next.showOtherModels = value
        case .onDemand: next.showOnDemand = value
        case .chatgptFiveHour: next.showChatGPTFiveHour = value
        case .chatgptWeekly: next.showChatGPTWeekly = value
        }
        return next
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case showCursorModels
        case showOtherModels
        case showOnDemand
        case showChatGPTFiveHour
        case showChatGPTWeekly
        case legacyCodexWeeklyRemaining = "showCodexWeeklyRemaining"
    }

    init(
        showCursorModels: Bool,
        showOtherModels: Bool,
        showOnDemand: Bool,
        showChatGPTFiveHour: Bool,
        showChatGPTWeekly: Bool
    ) {
        self.showCursorModels = showCursorModels
        self.showOtherModels = showOtherModels
        self.showOnDemand = showOnDemand
        self.showChatGPTFiveHour = showChatGPTFiveHour
        self.showChatGPTWeekly = showChatGPTWeekly
    }

    /// 兼容 v0.2.0 三字段数据：保留旧开关（Cursor Models、Other Models、
    /// 旧 `showCodexWeeklyRemaining` 迁移为 `showChatGPTWeekly`）。
    /// 新增的 On Demand 与 ChatGPT 5 小时按新默认值（Off / On）补齐，
    /// 缺失字段同样回退为对应的默认值。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showCursorModels = try container.decodeIfPresent(
            Bool.self, forKey: .showCursorModels
        ) ?? true
        showOtherModels = try container.decodeIfPresent(
            Bool.self, forKey: .showOtherModels
        ) ?? false
        showOnDemand = try container.decodeIfPresent(
            Bool.self, forKey: .showOnDemand
        ) ?? false
        showChatGPTFiveHour = try container.decodeIfPresent(
            Bool.self, forKey: .showChatGPTFiveHour
        ) ?? true
        if let weekly = try container.decodeIfPresent(
            Bool.self, forKey: .showChatGPTWeekly
        ) {
            showChatGPTWeekly = weekly
        } else if let legacy = try container.decodeIfPresent(
            Bool.self, forKey: .legacyCodexWeeklyRemaining
        ) {
            showChatGPTWeekly = legacy
        } else {
            showChatGPTWeekly = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showCursorModels, forKey: .showCursorModels)
        try container.encode(showOtherModels, forKey: .showOtherModels)
        try container.encode(showOnDemand, forKey: .showOnDemand)
        try container.encode(showChatGPTFiveHour, forKey: .showChatGPTFiveHour)
        try container.encode(showChatGPTWeekly, forKey: .showChatGPTWeekly)
    }

    // MARK: - Persistence

    /// 从 UserDefaults 读取设置；无历史数据或数据损坏时回退默认设置。
    static func load(from defaults: UserDefaults = .standard) -> MenuBarDisplaySettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(
                MenuBarDisplaySettings.self, from: data
              ) else {
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
