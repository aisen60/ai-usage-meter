import Foundation
import AppKit

/// Codex 数据接入
/// MVP 策略:
/// 1. 调研 ChatGPT 桌面应用本地存储
/// 2. 尝试通过 session cookie 调用 OpenAI 内部用量接口
/// 3. 降级为手动录入
enum CodexIntegration {

    /// OpenAI / Codex 用量页面 URL
    static let usagePageURL = "https://chat.openai.com/codex/usage"

    /// 尝试自动获取 Codex 用量
    /// MVP 阶段先返回 nil，后续迭代加入实际逻辑
    static func fetchUsage() async -> CodexUsage? {
        // TODO: 调研 ChatGPT 桌面应用本地存储中是否有用量数据
        // TODO: 尝试 OpenAI 内部用量 API
        // MVP 阶段返回 nil，UI 层会显示"未连接"
        return nil
    }

    /// 打开 Codex 用量页面 (浏览器)
    static func openUsagePage() {
        if let url = URL(string: usagePageURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
