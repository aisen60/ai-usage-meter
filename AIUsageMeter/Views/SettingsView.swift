import SwiftUI

/// 设置页（设计稿 design/v0.3.0/setting.png）。
///
/// 与主视图共处于同一个 MenuBarExtra 弹层内，通过 onBack 回调返回。
/// 包含状态栏预览、五个显示项目开关，以及「至少保留一项」的约束提示。
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
            StatusBarBadge(presentation: presentation)
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

    /// 设置页中实际可配置的项目：Cursor 未集成时隐藏两个 Cursor 百分比，
    /// On Demand 无有效上限时隐藏，ChatGPT 两项始终可配置。
    private var availableItems: [MenuBarDisplaySettings.Item] {
        var items: [MenuBarDisplaySettings.Item] = []
        if controller.shouldShowCursor {
            items.append(.cursorModels)
            items.append(.otherModels)
        }
        if controller.shouldShowOnDemand {
            items.append(.onDemand)
        }
        items.append(.chatgptFiveHour)
        items.append(.chatgptWeekly)
        return items
    }

    private var displayItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("显示项目")

            VStack(spacing: 0) {
                ForEach(Array(availableItems.enumerated()), id: \.element) { index, item in
                    displayItemRow(item: item)
                    if index < availableItems.count - 1 {
                        rowDivider
                    }
                }
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

    private func displayItemRow(item: MenuBarDisplaySettings.Item) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(QuotaPalette.tint(for: item))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(name(for: item))
                    .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))
                Text(subtitle(for: item))
                    .font(.system(size: MenuMetrics.summaryText))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(valueText(for: item))
                .font(.system(size: MenuMetrics.cardTitle, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(
                    isConnected(for: item)
                        ? QuotaPalette.tint(for: item)
                        : Color(nsColor: .tertiaryLabelColor)
                )

            Toggle(
                name(for: item),
                isOn: Binding(
                    get: { controller.displaySettings.isVisible(item) },
                    set: { controller.setDisplayItem(item, visible: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(
                controller.displaySettings.isLastVisible(
                    item,
                    cursorAvailable: controller.shouldShowCursor,
                    onDemandAvailable: controller.shouldShowOnDemand
                )
            )
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

    /// 状态栏预览与 MenuBarLabel 使用同一展示模型，避免数值或顺序不一致。
    private var presentation: StatusBarPresentation {
        StatusBarPresentation(
            settings: controller.displaySettings,
            cursorUsage: controller.cursorUsage,
            cursorAvailable: controller.shouldShowCursor,
            cursorState: controller.cursorConnectionState,
            codexUsage: controller.codexUsage,
            codexState: controller.codexConnectionState
        )
    }

    private var cursorConnected: Bool {
        controller.cursorConnectionState.canDisplayUsage && controller.cursorUsage != nil
    }

    private var codexConnected: Bool {
        controller.codexConnectionState.isConnected && controller.codexUsage.isConnected
    }

    private func name(for item: MenuBarDisplaySettings.Item) -> String {
        switch item {
        case .cursorModels: return "Cursor Models"
        case .otherModels: return "Other Models"
        case .onDemand: return "On Demand"
        case .chatgptFiveHour: return "5 小时"
        case .chatgptWeekly: return "1 周"
        }
    }

    private func subtitle(for item: MenuBarDisplaySettings.Item) -> String {
        switch item {
        case .cursorModels, .otherModels, .onDemand: return "Cursor"
        case .chatgptFiveHour, .chatgptWeekly: return "ChatGPT"
        }
    }

    private func valueText(for item: MenuBarDisplaySettings.Item) -> String {
        switch item {
        case .cursorModels: return percentText(cursorConnected ? controller.cursorUsage?.autoPercentUsed : nil)
        case .otherModels: return percentText(cursorConnected ? controller.cursorUsage?.apiPercentUsed : nil)
        case .onDemand: return controller.cursorUsage?.onDemandAmountText ?? "$0 / $0"
        case .chatgptFiveHour: return codexConnected ? percentText(controller.codexUsage.shortWindow.percentRemaining) : "0%"
        case .chatgptWeekly: return codexConnected ? percentText(controller.codexUsage.weeklyWindow.percentRemaining) : "0%"
        }
    }

    private func isConnected(for item: MenuBarDisplaySettings.Item) -> Bool {
        switch item {
        case .cursorModels, .otherModels, .onDemand: return cursorConnected
        case .chatgptFiveHour, .chatgptWeekly: return codexConnected
        }
    }

    private func percentText(_ value: Double?) -> String {
        "\(Int((value ?? 0).rounded()))%"
    }
}
