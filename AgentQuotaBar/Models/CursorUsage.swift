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

    /// 额外付费额度剩余 (美分)
    let individualRemaining: Double

    /// 原始显示消息 (来自 API 的 displayMessage)
    let displayMessage: String?

    /// 数据获取时间
    let fetchedAt: Date

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

    /// 是否为无限套餐
    let isUnlimited: Bool

    /// 从 API JSON 解析
    static func from(
        json: [String: Any],
        fetchedAt: Date = Date()
    ) -> CursorUsage? {
        guard let planUsage = json["planUsage"] as? [String: Any] else {
            return nil
        }

        let spendLimit = json["spendLimitUsage"] as? [String: Any] ?? [:]

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
            individualLimit: number(spendLimit["individualLimit"]),
            individualRemaining: number(spendLimit["individualRemaining"]),
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
