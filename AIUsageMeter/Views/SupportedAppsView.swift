import SwiftUI

/// 支持应用页：说明本产品可读取哪些客户端，并展示各自的安装与读取状态。
struct SupportedAppsView: View {
    @ObservedObject var controller: QuotaController
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBar

            Text("安装并登录后，应用会自动读取可用的用量信息。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MenuMetrics.horizontalPadding)
                .padding(.top, 4)

            VStack(spacing: 10) {
                SupportedAppRow(
                    name: "Cursor",
                    resourceName: "CursorIcon",
                    fallbackSymbol: "cursorarrow.rays",
                    status: statusText(
                        installed: controller.isCursorInstalled,
                        connectionState: controller.cursorConnectionState
                    ),
                    downloadURL: URL(string: "https://cursor.com/download")
                )

                SupportedAppRow(
                    name: "ChatGPT",
                    resourceName: "CodexIcon",
                    fallbackSymbol: "terminal.fill",
                    status: statusText(
                        installed: controller.isChatGPTInstalled,
                        connectionState: controller.codexConnectionState
                    ),
                    downloadURL: URL(string: "https://chatgpt.com/download/")
                )
            }
            .padding(.horizontal, MenuMetrics.horizontalPadding)
            .padding(.top, 20)

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, minHeight: 318, alignment: .topLeading)
        .padding(.top, 2)
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Label("返回", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .help("返回")

            Text("支持的 AI 编程助手")
                .font(.system(size: 17, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, MenuMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func statusText(
        installed: Bool,
        connectionState: QuotaController.ConnectionState
    ) -> String {
        guard installed else { return "未安装" }
        switch connectionState {
        case .connected, .stale:
            return "已登录"
        case .unknown:
            return "检测中"
        case .disconnected:
            return "已安装"
        case .error:
            return "无法读取"
        }
    }
}

private struct SupportedAppRow: View {
    let name: String
    let resourceName: String
    let fallbackSymbol: String
    let status: String
    let downloadURL: URL?

    @ViewBuilder
    var body: some View {
        if status == "未安装", let downloadURL {
            Link(destination: downloadURL) {
                rowContent
            }
            .buttonStyle(.plain)
            .help("打开 \(name) 下载页面")
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            ServiceLogo(
                resourceName: resourceName,
                fallbackSymbol: fallbackSymbol,
                size: 38
            )
            .accessibilityHidden(true)

            Text(name)
                .font(.system(size: 16, weight: .bold))

            Spacer()

            Text(status)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 74)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(MenuMetrics.groupBorderOpacity))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)，\(status)")
    }
}
