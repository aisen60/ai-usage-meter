import XCTest
@testable import AgentQuotaBar

final class AdaptiveRefreshPolicyTests: XCTestCase {
    private let policy = AdaptiveRefreshPolicy()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testRecentInteractionUsesTwoMinuteInterval() {
        let schedule = policy.schedule(
            now: now,
            lastInteractionTime: now.addingTimeInterval(-4 * 60),
            isSystemConstrained: false
        )

        XCTAssertEqual(schedule, .init(interval: 2 * 60, reason: .recentInteraction))
    }

    func testWarmInteractionUsesFiveMinuteInterval() {
        let schedule = policy.schedule(
            now: now,
            lastInteractionTime: now.addingTimeInterval(-30 * 60),
            isSystemConstrained: false
        )

        XCTAssertEqual(schedule, .init(interval: 5 * 60, reason: .warm))
    }

    func testIdleAndLongIdleBackOff() {
        XCTAssertEqual(
            policy.schedule(
                now: now,
                lastInteractionTime: now.addingTimeInterval(-2 * 60 * 60),
                isSystemConstrained: false
            ),
            .init(interval: 15 * 60, reason: .idle)
        )
        XCTAssertEqual(
            policy.schedule(
                now: now,
                lastInteractionTime: now.addingTimeInterval(-5 * 60 * 60),
                isSystemConstrained: false
            ),
            .init(interval: 30 * 60, reason: .longIdle)
        )
    }

    func testMissingInteractionStartsInLongIdleMode() {
        XCTAssertEqual(
            policy.schedule(
                now: now,
                lastInteractionTime: nil,
                isSystemConstrained: false
            ),
            .init(interval: 30 * 60, reason: .longIdle)
        )
    }

    func testSystemConstraintAlwaysUsesThirtyMinuteInterval() {
        XCTAssertEqual(
            policy.schedule(
                now: now,
                lastInteractionTime: now,
                isSystemConstrained: true
            ),
            .init(interval: 30 * 60, reason: .systemConstrained)
        )
    }

    func testInteractiveRefreshOnlyRunsForStaleOrMissingData() {
        XCTAssertTrue(policy.shouldRefresh(now: now, lastRefreshTime: nil))
        XCTAssertFalse(
            policy.shouldRefresh(
                now: now,
                lastRefreshTime: now.addingTimeInterval(-119)
            )
        )
        XCTAssertTrue(
            policy.shouldRefresh(
                now: now,
                lastRefreshTime: now.addingTimeInterval(-120)
            )
        )
    }
}
