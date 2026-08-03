import SwiftUI
import AppKit

/// Cursor 区域，采用设计稿中的标题、概览和两个额度卡片。
struct CursorSection: View {
    let usage: CursorUsage?
    let planName: String
    let connectionState: QuotaController.ConnectionState
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ServiceLogo(resourceName: "CursorIcon", fallbackSymbol: "cursorarrow.rays")
                Text(canDisplayUsage ? planName : "Cursor")
                    .font(.system(size: MenuMetrics.serviceTitle, weight: .bold))
                Spacer()
                ConnectionStatus(state: connectionState)
            }
            .padding(.horizontal, MenuMetrics.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 11)

            Divider()

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("用量概览")
                            .font(.system(size: MenuMetrics.sectionTitle, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("\(percent(autoPercent)) Cursor Models · \(percent(apiPercent)) Other Models")
                            .font(.system(size: MenuMetrics.summaryText))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, MenuMetrics.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, isExpanded ? 9 : 12)

            if isExpanded {
                VStack(spacing: 7) {
                    UsageBarCard(
                        label: "Cursor Models",
                        percent: autoPercent,
                        tint: canDisplayUsage ? .blue : .gray,
                        detail: nil
                    )
                    UsageBarCard(
                        label: "Other Models",
                        percent: apiPercent,
                        tint: canDisplayUsage ? Color(red: 0.39, green: 0.39, blue: 0.39) : .gray,
                        detail: nil
                    )
                }
                .padding(.horizontal, MenuMetrics.horizontalPadding)
                .padding(.bottom, 11)
            }
        }
    }

    private var canDisplayUsage: Bool {
        connectionState.canDisplayUsage && usage != nil
    }
    private var autoPercent: Double { canDisplayUsage ? usage?.autoPercentUsed ?? 0 : 0 }
    private var apiPercent: Double { canDisplayUsage ? usage?.apiPercentUsed ?? 0 : 0 }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private var apiDetail: String {
        if let usage, canDisplayUsage, usage.includedSpend > 0 {
            let amount = usage.includedSpend / 100
            return "超出限制的使用将按需计费。计划包含至少 $\(Int(amount)) 的 API 使用额度。"
        }
        return "超出限制的使用将按需额度计费。"
    }
}

/// 设计稿内的白色额度卡片。
struct UsageBarCard: View {
    let label: String
    let percent: Double
    let tint: Color
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))
                Spacer()
                Text("\(Int(clampedPercent.rounded()))%")
                    .font(.system(size: MenuMetrics.cardTitle, weight: .bold))
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(nsColor: .separatorColor).opacity(0.55))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, proxy.size.width * clampedPercent / 100))
                }
            }
            .frame(height: 6)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: MenuMetrics.bodyText))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.black.opacity(0.05)))
    }

    private var clampedPercent: Double { min(100, max(0, percent)) }
}

struct ServiceLogo: View {
    let resourceName: String
    let fallbackSymbol: String

    var body: some View {
        Group {
            if let image = bundledImage {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
            }
        }
        .frame(width: MenuMetrics.serviceIcon, height: MenuMetrics.serviceIcon)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var bundledImage: NSImage? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct ConnectionStatus: View {
    let state: QuotaController.ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: MenuMetrics.statusText, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    private var label: String {
        switch state {
        case .connected: return "已连接"
        case .stale: return "缓存数据"
        case .disconnected: return "未连接"
        case .error: return "连接异常"
        case .unknown: return "检测中"
        }
    }

    private var color: Color {
        switch state {
        case .connected: return .green
        case .stale: return .orange
        case .disconnected, .unknown: return .secondary
        case .error: return .orange
        }
    }
}
