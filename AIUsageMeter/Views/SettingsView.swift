import SwiftUI

/// 设置页（设计稿 design/v0.3.2/setting.png）。
///
/// 与主视图共处于同一个 MenuBarExtra 弹层内，通过 onBack 回调返回。
/// 包含已安装服务对应的显示项目开关。
struct SettingsView: View {
    @ObservedObject var controller: QuotaController
    @ObservedObject var appUpdateController: AppUpdateController
    @Binding var appLanguage: AppLanguage
    let onBack: () -> Void
    @Environment(\.locale) private var locale
    @StateObject private var launchAtLoginSettings = LaunchAtLoginSettings()

    var body: some View {
        settingsContent
    }

    /// 设置页主体。
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBar

            languageSection
                .padding(.top, 16)

            launchAtLoginSection
                .padding(.top, 16)

            updateSection
                .padding(.top, 16)

            displayItemsSection
                .padding(.top, 16)
                .padding(.bottom, 12)
        }
        .frame(width: MenuMetrics.width)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Label("navigation.back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .help(AppLanguage.localized("navigation.back", locale: locale))

            Text("settings.title")
                .font(.system(size: MenuMetrics.serviceTitle, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, MenuMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("settings.language")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("settings.appLanguage")
                        .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))

                    Spacer(minLength: 12)

                    Picker("settings.appLanguage", selection: $appLanguage) {
                        Text("language.simplifiedChinese")
                            .tag(AppLanguage.simplifiedChinese)
                        Text("language.english")
                            .tag(AppLanguage.english)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityLabel(Text("settings.appLanguage"))
                }

                Text("settings.languageDescription")
                    .font(.system(size: MenuMetrics.summaryText))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.black.opacity(0.05))
            )
            .padding(.horizontal, MenuMetrics.horizontalPadding)
        }
    }

    // MARK: - Updates

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("settings.updates")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appUpdateController.currentVersionName)
                        .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))
                    Text(appUpdateController.description(locale: locale))
                        .font(.system(size: MenuMetrics.summaryText))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(appUpdateController.buttonTitle(locale: locale)) {
                    appUpdateController.activate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appUpdateController.status.isBusy)
                .accessibilityLabel(appUpdateController.buttonTitle(locale: locale))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.black.opacity(0.05))
            )
            .padding(.horizontal, MenuMetrics.horizontalPadding)
        }
    }

    // MARK: - Launch at Login

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("settings.startup")

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("settings.launchAtLogin")
                            .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))

                        Spacer(minLength: 12)

                        Toggle(
                            isOn: Binding(
                                get: { launchAtLoginSettings.isEnabled },
                                set: { launchAtLoginSettings.setEnabled($0) }
                            )
                        ) {
                            Text("settings.launchAtLogin")
                        }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(!launchAtLoginSettings.canChange)
                        .accessibilityLabel(Text("settings.launchAtLogin"))
                    }

                    Text("settings.launchAtLoginDescription")
                        .font(.system(size: MenuMetrics.summaryText))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if launchAtLoginSettings.status == .requiresInstallation {
                    launchAtLoginMessage(messageKey: "settings.launchAtLoginRequiresInstallation")
                } else if launchAtLoginSettings.needsSystemApproval {
                    launchAtLoginMessage(
                        messageKey: "settings.launchAtLoginNeedsApproval",
                        actionKey: "settings.openLoginItems"
                    )
                } else if launchAtLoginSettings.status == .unavailable {
                    launchAtLoginMessage(messageKey: "settings.launchAtLoginUnavailable")
                } else if launchAtLoginSettings.didFailLastUpdate {
                    launchAtLoginMessage(messageKey: "settings.launchAtLoginUpdateFailed")
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
        .onAppear {
            launchAtLoginSettings.refresh()
        }
    }

    @ViewBuilder
    private func launchAtLoginMessage(
        messageKey: LocalizedStringKey,
        actionKey: LocalizedStringKey? = nil
    ) -> some View {
        Divider()
        VStack(alignment: .leading, spacing: 6) {
            Text(messageKey)
                .font(.system(size: MenuMetrics.summaryText))
                .foregroundStyle(.secondary)

            if let actionKey {
                Link(destination: LaunchAtLoginSettings.loginItemsSettingsURL) {
                    Text(actionKey)
                        .font(.system(size: MenuMetrics.summaryText, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Display Items

    /// 设置页中仅列出已安装服务可配置的项目。
    private var availableItems: [MenuBarDisplaySettings.Item] {
        var items: [MenuBarDisplaySettings.Item] = []
        if controller.shouldShowCursor {
            items.append(.cursorModels)
            items.append(.otherModels)
        }
        if controller.shouldShowOnDemand {
            items.append(.onDemand)
        }
        if controller.shouldShowChatGPT {
            items.append(.chatgptFiveHour)
            items.append(.chatgptWeekly)
        }
        return items
    }

    private var displayItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("settings.displayItems")

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
                Text(nameKey(for: item))
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
                isOn: Binding(
                    get: { controller.displaySettings.isVisible(item) },
                    set: { controller.setDisplayItem(item, visible: $0) }
                )
            ) {
                Text(nameKey(for: item))
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 30)
    }

    // MARK: - Shared Bits

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: MenuMetrics.summaryText, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, MenuMetrics.horizontalPadding)
    }

    // MARK: - Data

    private var cursorConnected: Bool {
        controller.cursorConnectionState.canDisplayUsage && controller.cursorUsage != nil
    }

    private var codexConnected: Bool {
        controller.codexConnectionState.isConnected && controller.codexUsage.isConnected
    }

    private func nameKey(for item: MenuBarDisplaySettings.Item) -> LocalizedStringKey {
        switch item {
        case .cursorModels: return "quota.cursorModels"
        case .otherModels: return "quota.otherModels"
        case .onDemand: return "quota.onDemand"
        case .chatgptFiveHour: return "quota.fiveHours"
        case .chatgptWeekly: return "quota.week"
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
        case .onDemand: return controller.cursorUsage?.onDemandUsedAmountText ?? "$0"
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
