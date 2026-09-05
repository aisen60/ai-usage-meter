import SwiftUI

/// 当 Cursor 与 ChatGPT 均未安装时显示的主面板空状态。
struct EmptyAssistantStateView: View {
    let onLearnSupportedApps: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)

            title

            Text("empty.description")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.top, 20)

            Button(action: onLearnSupportedApps) {
                Text("empty.learnSupportedApps")
                    .font(.system(size: 14, weight: .medium))
                    .frame(minWidth: 150)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 24)
            .help(AppLanguage.localized("empty.learnSupportedApps", locale: locale))

            Spacer(minLength: 34)
        }
        .frame(maxWidth: .infinity, minHeight: 270)
    }

    private var title: some View {
        Text("empty.title")
            .font(.system(size: 18, weight: .bold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text("empty.title"))
    }
}
