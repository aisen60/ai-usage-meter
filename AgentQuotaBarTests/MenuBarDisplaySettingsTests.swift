import XCTest
@testable import AgentQuotaBar

final class MenuBarDisplaySettingsTests: XCTestCase {

    /// 独立的 UserDefaults suite，避免读写真实偏好。
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MenuBarDisplaySettingsTests")
        defaults.removePersistentDomain(forName: "MenuBarDisplaySettingsTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "MenuBarDisplaySettingsTests")
        defaults = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultIsAllVisible() {
        let settings = MenuBarDisplaySettings.default
        XCTAssertTrue(settings.showCursorModels)
        XCTAssertTrue(settings.showOtherModels)
        XCTAssertTrue(settings.showCodexWeeklyRemaining)
        XCTAssertEqual(
            settings.visibleItems,
            [.cursorModels, .otherModels, .codexWeeklyRemaining]
        )
    }

    // MARK: - Constraint

    func testTogglingOffSingleItemSucceeds() {
        let next = MenuBarDisplaySettings.default.toggling(.cursorModels, to: false)
        XCTAssertEqual(
            next,
            MenuBarDisplaySettings(
                showCursorModels: false,
                showOtherModels: true,
                showCodexWeeklyRemaining: true
            )
        )
    }

    func testTogglingOffLastVisibleItemIsRejected() throws {
        var settings = MenuBarDisplaySettings.default
        settings = try XCTUnwrap(settings.toggling(.cursorModels, to: false))
        settings = try XCTUnwrap(settings.toggling(.otherModels, to: false))

        XCTAssertTrue(settings.isLastVisible(.codexWeeklyRemaining))
        XCTAssertNil(settings.toggling(.codexWeeklyRemaining, to: false))
        // 被拒绝后原设置不变
        XCTAssertEqual(settings.visibleItems, [.codexWeeklyRemaining])
    }

    func testTogglingOnAlwaysSucceeds() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: false,
            showCodexWeeklyRemaining: true
        )
        let next = settings.toggling(.cursorModels, to: true)
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.visibleItems, [.cursorModels, .codexWeeklyRemaining])
    }

    // MARK: - Visibility Helpers

    func testVisibleItemsForEachCombination() {
        let onlyOther = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: true,
            showCodexWeeklyRemaining: false
        )
        XCTAssertEqual(onlyOther.visibleItems, [.otherModels])
        XCTAssertTrue(onlyOther.isLastVisible(.otherModels))
        XCTAssertFalse(onlyOther.isLastVisible(.cursorModels))

        let cursorAndCodex = MenuBarDisplaySettings(
            showCursorModels: true,
            showOtherModels: false,
            showCodexWeeklyRemaining: true
        )
        XCTAssertEqual(
            cursorAndCodex.visibleItems,
            [.cursorModels, .codexWeeklyRemaining]
        )
        XCTAssertFalse(cursorAndCodex.isLastVisible(.cursorModels))
        XCTAssertFalse(cursorAndCodex.isLastVisible(.codexWeeklyRemaining))
    }

    // MARK: - Persistence

    func testSaveThenLoadRoundTrips() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: true,
            showOtherModels: false,
            showCodexWeeklyRemaining: true
        )
        settings.save(to: defaults)
        XCTAssertEqual(MenuBarDisplaySettings.load(from: defaults), settings)
    }

    func testLoadWithoutStoredValueReturnsDefault() {
        XCTAssertEqual(
            MenuBarDisplaySettings.load(from: defaults),
            .default
        )
    }

    func testLoadWithCorruptedValueReturnsDefault() {
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: MenuBarDisplaySettings.storageKey)
        XCTAssertEqual(
            MenuBarDisplaySettings.load(from: defaults),
            .default
        )
    }

    func testLoadWithAllItemsHiddenReturnsDefault() throws {
        let invalidSettings = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: false,
            showCodexWeeklyRemaining: false
        )
        let data = try JSONEncoder().encode(invalidSettings)
        defaults.set(data, forKey: MenuBarDisplaySettings.storageKey)

        XCTAssertEqual(MenuBarDisplaySettings.load(from: defaults), .default)
    }
}

final class QuotaControllerStateTests: XCTestCase {
    func testStaleCursorStateCanDisplayCachedUsage() {
        XCTAssertTrue(QuotaController.ConnectionState.stale.canDisplayUsage)
        XCTAssertFalse(QuotaController.ConnectionState.disconnected.canDisplayUsage)
        XCTAssertFalse(QuotaController.ConnectionState.error("failure").canDisplayUsage)
    }
}
