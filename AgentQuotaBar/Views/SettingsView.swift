import SwiftUI

/// 设置页（设计稿 design/v0.2.0/settings-page.png）。
///
/// 与主视图共处于同一个 MenuBarExtra 弹层内，通过 onBack 回调返回。
/// 包含状态栏预览、显示项目开关，以及「至少保留一项」的约束提示。
struct SettingsView: View {
    @ObservedObject var controller: QuotaController
    let onBack: () -> Void

    @State private var showMinItemInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBar

            previewSection
                .padding(.top, 4)

            displayItemsSection
                .padding(.top, 16)

            footerHint
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .frame(width: MenuMetrics.width)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("显示项目", isPresented: $showMinItemInfo) {
            Button("好", role: .cancel) {}
        } message: {
            Text("菜单栏至少需要保留一个显示项目，最后一项开关不可关闭。")
        }
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Label("返回", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .help("返回")

            Text("设置")
                .font(.system(size: MenuMetrics.serviceTitle, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, MenuMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("状态栏预览")

            // 深色底板模拟菜单栏环境，浅/深色模式下观感一致
            StatusBarBadge(
                cursorText: cursorPercentText,
                otherText: otherPercentText,
                codexText: codexPercentText,
                cursorConnected: cursorConnected,
                otherConnected: otherConnected,
                codexConnected: codexConnected,
                settings: controller.displaySettings
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.12))
            )
            .padding(.horizontal, MenuMetrics.horizontalPadding)
        }
    }

    // MARK: - Display Items

    private var displayItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("显示项目")

            VStack(spacing: 0) {
                displayItemRow(
                    item: .cursorModels,
                    name: "Cursor Models",
                    subtitle: "Cursor",
                    percentText: cursorPercentText,
                    tint: Color(red: 0.04, green: 0.45, blue: 0.96),
                    connected: cursorConnected
                )
                rowDivider
                displayItemRow(
                    item: .otherModels,
                    name: "Other Models",
                    subtitle: "Cursor",
                    percentText: otherPercentText,
                    tint: Color(red: 0.39, green: 0.39, blue: 0.39),
                    connected: otherConnected
                )
                rowDivider
                displayItemRow(
                    item: .codexWeeklyRemaining,
                    name: "本周剩余",
                    subtitle: codexSubtitle,
                    percentText: codexPercentText,
                    tint: Color(red: 0.00, green: 0.62, blue: 0.32),
                    connected: codexConnected
                )
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.black.opacity(0.05))
            )
            .padding(.horizontal, MenuMetrics.horizontalPadding)
        }
    }

    private func displayItemRow(
        item: MenuBarDisplaySettings.Item,
        name: String,
        subtitle: String,
        percentText: String,
        tint: Color,
        connected: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: MenuMetrics.summaryText))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(percentText)
                .font(.system(size: MenuMetrics.cardTitle, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(connected ? tint : Color(nsColor: .tertiaryLabelColor))

            Toggle(
                name,
                isOn: Binding(
                    get: { controller.displaySettings.isVisible(item) },
                    set: { controller.setDisplayItem(item, visible: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(controller.displaySettings.isLastVisible(item))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 30)
    }

    // MARK: - Footer

    private var footerHint: some View {
        HStack(spacing: 6) {
            Text("至少保留一个显示项目")
                .font(.system(size: MenuMetrics.bodyText))
                .foregroundStyle(.secondary)

            Button {
                showMinItemInfo = true
            } label: {
                Label("为什么不能全部关闭？", systemImage: "info.circle")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("为什么不能全部关闭？")

            Spacer()
        }
        .padding(.horizontal, MenuMetrics.horizontalPadding)
    }

    // MARK: - Shared Bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: MenuMetrics.summaryText, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, MenuMetrics.horizontalPadding)
    }

    // MARK: - Data

    private var cursorConnected: Bool {
        controller.cursorConnectionState.canDisplayUsage && controller.cursorUsage != nil
    }

    private var otherConnected: Bool {
        cursorConnected
    }

    private var codexConnected: Bool {
        controller.codexConnectionState.isConnected && controller.codexUsage.isConnected
    }

    private var cursorPercentText: String {
        guard cursorConnected, let usage = controller.cursorUsage else { return "0%" }
        return "\(Int(usage.autoPercentUsed.rounded()))%"
    }

    private var otherPercentText: String {
        guard otherConnected, let usage = controller.cursorUsage else { return "0%" }
        return "\(Int(usage.apiPercentUsed.rounded()))%"
    }

    private var codexPercentText: String {
        guard codexConnected else { return "0%" }
        return "\(Int(controller.codexUsage.percentRemaining.rounded()))%"
    }

    private var codexSubtitle: String {
        codexConnected ? controller.codexUsage.planName : "Codex"
    }
}
