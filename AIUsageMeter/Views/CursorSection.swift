import SwiftUI
import AppKit

/// Cursor 服务组卡片：header 与最多三条额度行共处同一圆角容器，
/// 行之间使用组内细分隔线（design/v0.3.0/home.png）。
struct CursorSection: View {
    let usage: CursorUsage?
    let planName: String
    let connectionState: QuotaController.ConnectionState

    var body: some View {
        ServiceGroupCard {
            VStack(alignment: .leading, spacing: 0) {
                header
                rows
            }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ServiceLogo(resourceName: "CursorIcon", fallbackSymbol: "cursorarrow.rays")
            Text(canDisplayUsage ? planName : "Cursor")
                .font(.system(size: MenuMetrics.serviceTitle, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 8)
            ConnectionStatus(state: connectionState)
                .layoutPriority(2)
        }
        .padding(.horizontal, MenuMetrics.groupInset)
        .padding(.top, MenuMetrics.groupHeaderTop)
        .padding(.bottom, MenuMetrics.groupHeaderBottom)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(
                Array(cursorRowKinds(onDemandAvailable: onDemandAvailable).enumerated()),
                id: \.element
            ) { index, kind in
                if index > 0 {
                    rowDivider
                }
                row(for: kind)
            }
        }
        .padding(.horizontal, MenuMetrics.groupInset)
        .padding(.bottom, MenuMetrics.groupContentBottom)
    }

    private var rowDivider: some View {
        Divider()
    }

    private func row(for kind: CursorRowKind) -> some View {
        switch kind {
        case .cursorModels:
            return QuotaRow(
                label: "Cursor Models",
                percent: autoPercent,
                tint: canDisplayUsage ? QuotaPalette.cursorModels : .gray,
                detail: nil
            )
        case .otherModels:
            return QuotaRow(
                label: "Other Models",
                percent: apiPercent,
                tint: canDisplayUsage ? QuotaPalette.otherModels : .gray,
                detail: nil
            )
        case .onDemand:
            return QuotaRow(
                label: "On Demand",
                percent: onDemandPercent,
                tint: QuotaPalette.onDemand,
                detail: onDemandDetail,
                trailingText: onDemandText
            )
        }
    }

    private var canDisplayUsage: Bool {
        connectionState.canDisplayUsage && usage != nil
    }
    private var autoPercent: Double { canDisplayUsage ? usage?.autoPercentUsed ?? 0 : 0 }
    private var apiPercent: Double { canDisplayUsage ? usage?.apiPercentUsed ?? 0 : 0 }

    /// On Demand 仅在存在有效个人上限时展示（由模型层判定）。
    private var onDemandAvailable: Bool {
        canDisplayUsage && (usage?.onDemandAvailable ?? false)
    }
    private var onDemandPercent: Double {
        canDisplayUsage ? usage?.onDemandPercentUsed ?? 0 : 0
    }
    private var onDemandText: String {
        usage?.onDemandAmountText ?? "$0 / $0"
    }

    private var onDemandDetail: String {
        "超出套餐额度的使用将按需计费。"
    }
}

/// Cursor 服务组内的行类型。
enum CursorRowKind: Equatable, Hashable {
    case cursorModels
    case otherModels
    case onDemand
}

/// 按 On Demand 可用性构建 Cursor 行序列（不含分隔线）。
/// 纯辅助逻辑：无有效上限时不生成第三行，也就不会产生多余分隔线。
func cursorRowKinds(onDemandAvailable: Bool) -> [CursorRowKind] {
    var kinds: [CursorRowKind] = [.cursorModels, .otherModels]
    if onDemandAvailable {
        kinds.append(.onDemand)
    }
    return kinds
}

/// 相邻行之间的分隔线数量 = max(0, 行数 - 1)。
func rowDividerCount(for rowCount: Int) -> Int {
    max(0, rowCount - 1)
}

/// 服务组卡片：统一圆角、描边与内容容器；header 与额度行共处同一容器。
struct ServiceGroupCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: MenuMetrics.groupCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MenuMetrics.groupCornerRadius, style: .continuous)
                .stroke(.black.opacity(MenuMetrics.groupBorderOpacity))
        )
    }
}

/// 服务组内的一条额度内容行：标签、右侧数值、单色进度条与可选说明。
/// 无独立圆角卡片背景或边框；行间分隔由所属服务组容器绘制。
struct QuotaRow: View {
    let label: String
    let percent: Double
    let tint: Color
    let detail: String?
    var trailingText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MenuMetrics.rowSpacing) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: MenuMetrics.cardTitle, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(.system(size: MenuMetrics.cardTitle, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(nsColor: .separatorColor).opacity(0.55))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, proxy.size.width * clampedPercent / 100))
                }
            }
            .frame(height: MenuMetrics.rowBarHeight)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: MenuMetrics.bodyText))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, MenuMetrics.rowVerticalPadding)
    }

    private var valueText: String {
        trailingText ?? "\(Int(clampedPercent.rounded()))%"
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
                .lineLimit(1)
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
