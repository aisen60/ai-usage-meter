import SwiftUI

/// 支持应用页：说明本产品可读取哪些客户端，并展示各自的安装与读取状态。
struct SupportedAppsView: View {
    @ObservedObject var controller: QuotaController
    let onBack: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBar

            Text("supportedApps.description")
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
                    status: status(
                        installed: controller.isCursorInstalled,
                        connectionState: controller.cursorConnectionState
                    ),
                    downloadURL: URL(string: "https://cursor.com/download")
                )

                SupportedAppRow(
                    name: "ChatGPT",
                    resourceName: "CodexIcon",
                    fallbackSymbol: "terminal.fill",
                    status: status(
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
                Label("navigation.back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .help(AppLanguage.localized("navigation.back", locale: locale))

            Text("supportedApps.title")
                .font(.system(size: 17, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, MenuMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func status(
        installed: Bool,
        connectionState: QuotaController.ConnectionState
    ) -> SupportedAppStatus {
        guard installed else { return .notInstalled }
        switch connectionState {
        case .connected, .stale:
            return .loggedIn
        case .unknown:
            return .detecting
        case .disconnected:
            return .installed
        case .error:
            return .unavailable
        }
    }
}

enum SupportedAppStatus: Equatable {
    case notInstalled
    case loggedIn
    case detecting
    case installed
    case unavailable

    var needsDownloadLink: Bool {
        self == .notInstalled
    }

    private var localizationKey: String {
        switch self {
        case .notInstalled: return "supportedApps.status.notInstalled"
        case .loggedIn: return "supportedApps.status.loggedIn"
        case .detecting: return "supportedApps.status.detecting"
        case .installed: return "supportedApps.status.installed"
        case .unavailable: return "supportedApps.status.unavailable"
        }
    }

    func localizedDescription(locale: Locale) -> String {
        AppLanguage.localized(localizationKey, locale: locale)
    }
}

struct SupportedAppRow: View {
    let name: String
    let resourceName: String
    let fallbackSymbol: String
    let status: SupportedAppStatus
    let downloadURL: URL?
    @Environment(\.locale) private var locale

    @ViewBuilder
    var body: some View {
        if status.needsDownloadLink, let downloadURL {
            Link(destination: downloadURL) {
                rowContent
            }
            .buttonStyle(.plain)
            .help(AppLanguage.localized(
                "supportedApps.downloadHelp",
                locale: locale,
                arguments: name
            ))
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

            Text(status.localizedDescription(locale: locale))
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
        .accessibilityLabel(AppLanguage.localized(
            "supportedApps.rowLabel",
            locale: locale,
            arguments: name,
            status.localizedDescription(locale: locale)
        ))
    }
}
