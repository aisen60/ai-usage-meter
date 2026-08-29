import Foundation

/// 单个配额窗口：剩余百分比与重置时间。
struct QuotaWindow: Codable, Equatable {
    /// 剩余额度百分比 (0-100)
    let percentRemaining: Double

    /// 重置时间 (可选)
    let resetsAt: Date?

    /// 断开回退：中性 `0%` 且无重置时间。
    static let disconnected = QuotaWindow(percentRemaining: 0, resetsAt: nil)
}

/// ChatGPT 额度数据。内部保留 Codex 命名以避免无关重构，
/// 面向用户的可见文字统一为 ChatGPT。
///
/// 包含短周期（5 小时）与周周期（1 周）两个窗口。
struct CodexUsage: Codable, Equatable {
    /// 套餐类型描述 (如 "ChatGPT Plus")
    let planName: String

    /// 5 小时窗口额度
    let shortWindow: QuotaWindow

    /// 1 周窗口额度
    let weeklyWindow: QuotaWindow

    /// 数据来源
    let source: Source

    /// 数据获取时间
    let fetchedAt: Date

    /// 备注信息
    let note: String?

    enum Source: String, Codable {
        /// 自动从 API 或本地数据源获取
        case automatic
        /// 尚未连接
        case disconnected
    }

    /// 是否已连接
    var isConnected: Bool {
        source != .disconnected
    }

    /// 空状态 (未连接)。两个窗口均以中性 `0%` 回退，避免状态栏为空。
    static var disconnected: CodexUsage {
        CodexUsage(
            planName: "ChatGPT",
            shortWindow: .disconnected,
            weeklyWindow: .disconnected,
            source: .disconnected,
            fetchedAt: Date(),
            note: nil
        )
    }
}
