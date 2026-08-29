import Foundation

/// 根据用户交互和系统状态调整后台刷新频率。
///
/// 策略本身不读取系统环境，便于使用固定时间编写确定性测试。
struct AdaptiveRefreshPolicy {
    enum Reason: String, Equatable {
        case recentInteraction
        case warm
        case idle
        case longIdle
        case systemConstrained
    }

    struct Schedule: Equatable {
        let interval: TimeInterval
        let reason: Reason
    }

    static let interactiveMaximumAge: TimeInterval = 2 * 60

    private let recentInteractionWindow: TimeInterval = 5 * 60
    private let warmWindow: TimeInterval = 60 * 60
    private let longIdleThreshold: TimeInterval = 4 * 60 * 60

    func schedule(
        now: Date,
        lastInteractionTime: Date?,
        isSystemConstrained: Bool
    ) -> Schedule {
        if isSystemConstrained {
            return Schedule(interval: 30 * 60, reason: .systemConstrained)
        }

        guard let lastInteractionTime else {
            return Schedule(interval: 30 * 60, reason: .longIdle)
        }

        let idleTime = max(0, now.timeIntervalSince(lastInteractionTime))
        if idleTime <= recentInteractionWindow {
            return Schedule(interval: 2 * 60, reason: .recentInteraction)
        }
        if idleTime <= warmWindow {
            return Schedule(interval: 5 * 60, reason: .warm)
        }
        if idleTime < longIdleThreshold {
            return Schedule(interval: 15 * 60, reason: .idle)
        }
        return Schedule(interval: 30 * 60, reason: .longIdle)
    }

    func shouldRefresh(
        now: Date,
        lastRefreshTime: Date?,
        maximumAge: TimeInterval = interactiveMaximumAge
    ) -> Bool {
        guard let lastRefreshTime else { return true }
        return now.timeIntervalSince(lastRefreshTime) >= maximumAge
    }
}
