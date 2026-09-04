import SwiftUI

/// 当 Cursor 与 ChatGPT 均未安装时显示的主面板空状态。
struct EmptyAssistantStateView: View {
    let onLearnSupportedApps: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)

            title

            Text("安装并登录 Cursor 或 ChatGPT 后，\n这里会自动显示你的用量。")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.top, 20)

            Button(action: onLearnSupportedApps) {
                Text("了解支持的应用")
                    .font(.system(size: 14, weight: .medium))
                    .frame(minWidth: 150)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 24)
            .help("了解支持的 AI 编程助手")

            Spacer(minLength: 34)
        }
        .frame(maxWidth: .infinity, minHeight: 270)
    }

    private var title: some View {
        (
            Text("还没有可用的 ")
            + Text("AI 编程助手 ").foregroundColor(.blue)
            + Text("应用")
        )
        .font(.system(size: 18, weight: .bold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("还没有可用的 AI 编程助手应用")
    }
}
