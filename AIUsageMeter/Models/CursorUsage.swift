import Foundation

/// Cursor 当前账期用量数据
struct CursorUsage: Codable, Equatable {
    /// 账期开始时间戳 (毫秒)
    let billingCycleStart: Double

    /// 账期结束时间戳 (毫秒)
    let billingCycleEnd: Double

    /// 综合已用百分比 (0-100)
    let totalPercentUsed: Double

    /// Auto / Composer 已用百分比 (0-100)
    let autoPercentUsed: Double

    /// 指定模型 API 已用百分比 (0-100)
    let apiPercentUsed: Double

    /// 已花费金额 (美分)
    let totalSpend: Double

    /// 套餐内包含金额 (美分)
    let includedSpend: Double

    /// 额外奖励金额 (美分)
    let bonusSpend: Double

    /// 花费上限 (美分)
    let limit: Double

    /// 额外付费额度上限 (美分)
    let individualLimit: Double

    /// 额外付费额度已用 (美分)
    let individualUsed: Double

    /// 额外付费额度剩余 (美分)
    let individualRemaining: Double

    /// 原始显示消息 (来自 API 的 displayMessage)
    let displayMessage: String?

    /// 数据获取时间
    let fetchedAt: Date

    /// 是否为无限套餐
    let isUnlimited: Bool

    init(
        billingCycleStart: Double,
        billingCycleEnd: Double,
        totalPercentUsed: Double,
        autoPercentUsed: Double,
        apiPercentUsed: Double,
        totalSpend: Double,
        includedSpend: Double,
        bonusSpend: Double,
        limit: Double,
        individualLimit: Double,
        individualUsed: Double,
        individualRemaining: Double,
        displayMessage: String?,
        fetchedAt: Date,
        isUnlimited: Bool
    ) {
        self.billingCycleStart = billingCycleStart
        self.billingCycleEnd = billingCycleEnd
        self.totalPercentUsed = totalPercentUsed
        self.autoPercentUsed = autoPercentUsed
        self.apiPercentUsed = apiPercentUsed
        self.totalSpend = totalSpend
        self.includedSpend = includedSpend
        self.bonusSpend = bonusSpend
        self.limit = limit
        self.individualLimit = individualLimit
        self.individualUsed = individualUsed
        self.individualRemaining = individualRemaining
        self.displayMessage = displayMessage
        self.fetchedAt = fetchedAt
        self.isUnlimited = isUnlimited
    }

    /// 综合剩余百分比
    var totalPercentRemaining: Double {
        max(0, 100 - totalPercentUsed)
    }

    /// Auto / Composer 剩余百分比
    var autoPercentRemaining: Double {
        max(0, 100 - autoPercentUsed)
    }

    /// API 模型剩余百分比
    var apiPercentRemaining: Double {
        max(0, 100 - apiPercentUsed)
    }

    /// 账期开始日期
    var billingCycleStartDate: Date {
        Date(timeIntervalSince1970: billingCycleStart / 1000)
    }

    /// 账期结束日期
    var billingCycleEndDate: Date {
        Date(timeIntervalSince1970: billingCycleEnd / 1000)
    }

    // MARK: - On Demand

    /// On Demand 个人额度是否有有效上限（上限缺失或不超过零时不可用）。
    var onDemandAvailable: Bool {
        individualLimit.isFinite && individualLimit > 0
    }

    /// On Demand 已用百分比 (0-100)
    var onDemandPercentUsed: Double {
        guard onDemandAvailable else { return 0 }
        return max(0, min(100, individualUsed / individualLimit * 100))
    }

    /// On Demand 已用金额（美元）
    var onDemandUsedDollars: Double {
        individualUsed / 100
    }

    /// On Demand 上限金额（美元）
    var onDemandLimitDollars: Double {
        individualLimit / 100
    }

    /// On Demand 已用金额展示文本，例如 `$3.92`。
    /// 用于空间紧凑的菜单栏与设置页；首页卡片仍使用带上限的完整文本。
    var onDemandUsedAmountText: String {
        Self.dollarText(individualUsed)
    }

    /// On Demand 展示文本，例如 `$3.92 / $10`。
    var onDemandAmountText: String {
        "\(onDemandUsedAmountText) / \(Self.dollarText(individualLimit))"
    }

    private static func dollarText(_ cents: Double) -> String {
        let dollars = cents / 100
        if dollars.rounded() == dollars {
            return String(
                format: "$%.0f",
                locale: Locale(identifier: "en_US_POSIX"),
                dollars
            )
        }
        return String(
            format: "$%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            dollars
        )
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case billingCycleStart
        case billingCycleEnd
        case totalPercentUsed
        case autoPercentUsed
        case apiPercentUsed
        case totalSpend
        case includedSpend
        case bonusSpend
        case limit
        case individualLimit
        case individualUsed
        case individualRemaining
        case displayMessage
        case fetchedAt
        case isUnlimited
    }

    /// 兼容 v0.2.0 缓存：旧数据没有 `individualUsed`，由其上限与剩余反推。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        billingCycleStart = try container.decode(Double.self, forKey: .billingCycleStart)
        billingCycleEnd = try container.decode(Double.self, forKey: .billingCycleEnd)
        totalPercentUsed = try container.decode(Double.self, forKey: .totalPercentUsed)
        autoPercentUsed = try container.decode(Double.self, forKey: .autoPercentUsed)
        apiPercentUsed = try container.decode(Double.self, forKey: .apiPercentUsed)
        totalSpend = try container.decode(Double.self, forKey: .totalSpend)
        includedSpend = try container.decode(Double.self, forKey: .includedSpend)
        bonusSpend = try container.decode(Double.self, forKey: .bonusSpend)
        limit = try container.decode(Double.self, forKey: .limit)
        individualLimit = try container.decode(Double.self, forKey: .individualLimit)
        individualRemaining = try container.decode(Double.self, forKey: .individualRemaining)
        individualUsed = try container.decodeIfPresent(Double.self, forKey: .individualUsed)
            ?? max(0, individualLimit - individualRemaining)
        displayMessage = try container.decodeIfPresent(String.self, forKey: .displayMessage)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        isUnlimited = try container.decodeIfPresent(Bool.self, forKey: .isUnlimited) ?? false
    }

    // MARK: - Parsing

    /// 从 API JSON 解析
    static func from(
        json: [String: Any],
        fetchedAt: Date = Date()
    ) -> CursorUsage? {
        guard let planUsage = json["planUsage"] as? [String: Any] else {
            return nil
        }

        let spendLimit = json["spendLimitUsage"] as? [String: Any] ?? [:]
        let individualLimit = number(spendLimit["individualLimit"])
        let individualRemaining = number(spendLimit["individualRemaining"])
        let individualUsed: Double
        if spendLimit["individualUsed"] != nil {
            individualUsed = number(spendLimit["individualUsed"])
        } else {
            individualUsed = max(0, individualLimit - individualRemaining)
        }

        return CursorUsage(
            billingCycleStart: number(json["billingCycleStart"]),
            billingCycleEnd: number(json["billingCycleEnd"]),
            totalPercentUsed: number(planUsage["totalPercentUsed"]),
            autoPercentUsed: number(planUsage["autoPercentUsed"]),
            apiPercentUsed: number(planUsage["apiPercentUsed"]),
            totalSpend: number(planUsage["totalSpend"]),
            includedSpend: number(planUsage["includedSpend"]),
            bonusSpend: number(planUsage["bonusSpend"]),
            limit: number(planUsage["limit"]),
            individualLimit: individualLimit,
            individualUsed: individualUsed,
            individualRemaining: individualRemaining,
            displayMessage: json["displayMessage"] as? String,
            fetchedAt: fetchedAt,
            isUnlimited: (json["isUnlimited"] as? Bool) ?? false
        )
    }

    private static func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String, let number = Double(string) { return number }
        return 0
    }
}
