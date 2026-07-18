import Foundation

/// Codex 用量数据
/// MVP 阶段支持手动录入 + 自动获取 (如果找到数据源)
struct CodexUsage: Codable, Equatable {
    /// 套餐类型描述 (如 "Pro", "Plus")
    let planName: String

    /// 剩余额度百分比 (0-100)，手动录入或自动获取
    let percentRemaining: Double

    /// 账期结束时间 (可选)
    let cycleEndDate: Date?

    /// 数据来源
    let source: Source

    /// 数据获取时间
    let fetchedAt: Date

    /// 备注信息
    let note: String?

    enum Source: String, Codable {
        /// 自动从 API 或本地数据源获取
        case automatic
        /// 用户手动录入
        case manual
        /// 尚未连接
        case disconnected
    }

    /// 剩余百分比 (0-100)
    var percentUsed: Double {
        max(0, min(100, 100 - percentRemaining))
    }

    /// 是否已连接
    var isConnected: Bool {
        source != .disconnected
    }

    /// 空状态 (未连接)
    static var disconnected: CodexUsage {
        CodexUsage(
            planName: "Codex",
            percentRemaining: 0,
            cycleEndDate: nil,
            source: .disconnected,
            fetchedAt: Date(),
            note: nil
        )
    }
}
