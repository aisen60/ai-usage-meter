import XCTest
@testable import AIUsageMeter

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

    func testDefaultTurnsOnOnlyCursorModelsAndFiveHour() {
        let settings = MenuBarDisplaySettings.default
        XCTAssertTrue(settings.showCursorModels)
        XCTAssertFalse(settings.showOtherModels)
        XCTAssertFalse(settings.showOnDemand)
        XCTAssertTrue(settings.showChatGPTFiveHour)
        XCTAssertFalse(settings.showChatGPTWeekly)
        XCTAssertEqual(
            settings.visibleItems,
            [.cursorModels, .chatgptFiveHour]
        )
    }

    // MARK: - Toggling

    func testTogglingOffSingleItemSucceeds() {
        let next = MenuBarDisplaySettings.default.toggling(.cursorModels, to: false)
        XCTAssertEqual(
            next,
            MenuBarDisplaySettings(
                showCursorModels: false,
                showOtherModels: false,
                showOnDemand: false,
                showChatGPTFiveHour: true,
                showChatGPTWeekly: false
            )
        )
    }

    func testTogglingOffLastVisibleItemSucceeds() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: false,
            showOnDemand: false,
            showChatGPTFiveHour: false,
            showChatGPTWeekly: true
        )

        let next = settings.toggling(.chatgptWeekly, to: false)
        XCTAssertTrue(next.visibleItems.isEmpty)
    }

    func testTogglingOnAlwaysSucceeds() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: false,
            showOnDemand: false,
            showChatGPTFiveHour: false,
            showChatGPTWeekly: true
        )
        let next = settings.toggling(.cursorModels, to: true)
        XCTAssertEqual(next.visibleItems, [.cursorModels, .chatgptWeekly])
    }

    // MARK: - Visibility Helpers

    func testVisibleItemsForEachCombination() {
        let onlyOther = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: true,
            showOnDemand: false,
            showChatGPTFiveHour: false,
            showChatGPTWeekly: false
        )
        XCTAssertEqual(onlyOther.visibleItems, [.otherModels])

        let cursorAndChatGPT = MenuBarDisplaySettings(
            showCursorModels: true,
            showOtherModels: false,
            showOnDemand: false,
            showChatGPTFiveHour: true,
            showChatGPTWeekly: true
        )
        XCTAssertEqual(
            cursorAndChatGPT.visibleItems,
            [.cursorModels, .chatgptFiveHour, .chatgptWeekly]
        )
    }

    func testCursorItemsAreTemporarilyFilteredWhenIntegrationIsUnavailable() {
        let settings = MenuBarDisplaySettings.default

        // Cursor 不可用时 On Demand 也必然不可用（其依赖 Cursor 用量）。
        XCTAssertEqual(
            settings.visibleItems(cursorAvailable: false, onDemandAvailable: false),
            [.chatgptFiveHour]
        )
        XCTAssertEqual(
            settings.visibleItems(cursorAvailable: true, onDemandAvailable: true),
            settings.visibleItems
        )
    }

    func testOnDemandIsTemporarilyFilteredWithoutValidLimit() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: true,
            showOtherModels: true,
            showOnDemand: true,
            showChatGPTFiveHour: true,
            showChatGPTWeekly: true
        )

        XCTAssertEqual(
            settings.visibleItems(cursorAvailable: true, onDemandAvailable: false),
            [.cursorModels, .otherModels, .chatgptFiveHour, .chatgptWeekly]
        )
        XCTAssertEqual(
            settings.visibleItems(cursorAvailable: true, onDemandAvailable: true),
            settings.visibleItems
        )
    }

    func testCanHideOnlyAvailableChatGPTItem() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: false,
            showOnDemand: false,
            showChatGPTFiveHour: false,
            showChatGPTWeekly: true
        )

        XCTAssertTrue(settings.toggling(.chatgptWeekly, to: false).visibleItems.isEmpty)
    }

    // MARK: - Migration

    func testLegacyThreeFieldPayloadMigrates() throws {
        // v0.2.0 存储的三字段格式
        let legacy: [String: Any] = [
            "showCursorModels": true,
            "showOtherModels": false,
            "showCodexWeeklyRemaining": false
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let settings = try JSONDecoder().decode(MenuBarDisplaySettings.self, from: data)

        XCTAssertTrue(settings.showCursorModels)
        XCTAssertFalse(settings.showOtherModels)
        XCTAssertFalse(settings.showOnDemand)
        XCTAssertTrue(settings.showChatGPTFiveHour)
        XCTAssertFalse(settings.showChatGPTWeekly)
    }

    // MARK: - Persistence

    func testSaveThenLoadRoundTrips() {
        let settings = MenuBarDisplaySettings(
            showCursorModels: true,
            showOtherModels: false,
            showOnDemand: true,
            showChatGPTFiveHour: false,
            showChatGPTWeekly: true
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

    func testLoadWithAllItemsHiddenPreservesPreference() throws {
        let hiddenSettings = MenuBarDisplaySettings(
            showCursorModels: false,
            showOtherModels: false,
            showOnDemand: false,
            showChatGPTFiveHour: false,
            showChatGPTWeekly: false
        )
        let data = try JSONEncoder().encode(hiddenSettings)
        defaults.set(data, forKey: MenuBarDisplaySettings.storageKey)

        XCTAssertEqual(MenuBarDisplaySettings.load(from: defaults), hiddenSettings)
    }
}

final class QuotaControllerStateTests: XCTestCase {
    func testStaleCursorStateCanDisplayCachedUsage() {
        XCTAssertTrue(QuotaController.ConnectionState.stale.canDisplayUsage)
        XCTAssertFalse(QuotaController.ConnectionState.disconnected.canDisplayUsage)
        XCTAssertFalse(QuotaController.ConnectionState.error("failure").canDisplayUsage)
    }

    @MainActor
    func testInstalledCursorRemainsVisibleWithoutDisplayableUsage() {
        let controller = QuotaController(autoStart: false, cursorInstalled: true)

        controller.cursorConnectionState = .error("failure")

        XCTAssertTrue(controller.shouldShowCursor)
    }

    @MainActor
    func testCursorShowsCurrentUsage() {
        let controller = QuotaController(autoStart: false, cursorInstalled: true)
        controller.cursorUsage = makeCursorUsage()
        controller.cursorConnectionState = .connected

        XCTAssertTrue(controller.shouldShowCursor)
    }

    @MainActor
    func testCursorShowsExplicitlyStaleUsage() {
        let controller = QuotaController(autoStart: false, cursorInstalled: true)
        controller.cursorUsage = makeCursorUsage()
        controller.cursorConnectionState = .stale

        XCTAssertTrue(controller.shouldShowCursor)
    }

    @MainActor
    func testShouldShowOnDemandRequiresDisplayableUsageWithValidLimit() {
        let controller = QuotaController(autoStart: false, cursorInstalled: true)
        XCTAssertFalse(controller.shouldShowOnDemand)

        controller.cursorUsage = makeCursorUsage(individualUsed: 0, individualLimit: 0)
        controller.cursorConnectionState = .connected
        XCTAssertFalse(controller.shouldShowOnDemand)

        controller.cursorUsage = makeCursorUsage(individualUsed: 200, individualLimit: 1000)
        XCTAssertTrue(controller.shouldShowOnDemand)
    }

    func testChatGPTDisconnectedFallbackHasNeutralWindows() {
        let disconnected = CodexUsage.disconnected
        XCTAssertFalse(disconnected.isConnected)
        XCTAssertEqual(disconnected.planName, "ChatGPT")
        XCTAssertEqual(disconnected.shortWindow.percentRemaining, 0)
        XCTAssertEqual(disconnected.weeklyWindow.percentRemaining, 0)
    }

    @MainActor
    func testServiceCardsFollowApplicationInstallation() {
        let cursorOnly = QuotaController(
            autoStart: false,
            cursorInstalled: true,
            chatGPTInstalled: false
        )
        XCTAssertTrue(cursorOnly.shouldShowCursor)
        XCTAssertFalse(cursorOnly.shouldShowChatGPT)

        let chatGPTOnly = QuotaController(
            autoStart: false,
            cursorInstalled: false,
            chatGPTInstalled: true
        )
        XCTAssertFalse(chatGPTOnly.shouldShowCursor)
        XCTAssertTrue(chatGPTOnly.shouldShowChatGPT)
    }

    @MainActor
    func testPreviewOverrideTreatsBothAppsAsNotInstalled() {
        let controller = QuotaController(
            autoStart: false,
            cursorInstalled: true,
            chatGPTInstalled: true,
            forceNoAssistantApps: true
        )

        XCTAssertFalse(controller.isCursorInstalled)
        XCTAssertFalse(controller.isChatGPTInstalled)
        XCTAssertFalse(controller.shouldShowCursor)
        XCTAssertFalse(controller.shouldShowChatGPT)
        XCTAssertTrue(controller.shouldShowEmptyAssistantState)
    }

    @MainActor
    func testCursorOnlyPreviewKeepsCursorAndHidesChatGPT() {
        let controller = QuotaController(
            autoStart: false,
            cursorInstalled: true,
            chatGPTInstalled: true,
            forceCursorOnly: true
        )

        XCTAssertTrue(controller.isCursorInstalled)
        XCTAssertFalse(controller.isChatGPTInstalled)
        XCTAssertTrue(controller.shouldShowCursor)
        XCTAssertFalse(controller.shouldShowChatGPT)
        XCTAssertFalse(controller.shouldShowEmptyAssistantState)
    }

    @MainActor
    func testChatGPTOnlyPreviewHidesCursorAndKeepsChatGPT() {
        let controller = QuotaController(
            autoStart: false,
            cursorInstalled: true,
            chatGPTInstalled: true,
            forceChatGPTOnly: true
        )

        XCTAssertFalse(controller.isCursorInstalled)
        XCTAssertTrue(controller.isChatGPTInstalled)
        XCTAssertFalse(controller.shouldShowCursor)
        XCTAssertTrue(controller.shouldShowChatGPT)
        XCTAssertFalse(controller.shouldShowEmptyAssistantState)
    }
}

final class StatusBarPresentationTests: XCTestCase {
    func testFallbackTextUsesVisibleItemOrder() {
        let presentation = StatusBarPresentation(
            settings: allOnSettings(),
            cursorUsage: makeCursorUsage(
                autoPercentUsed: 39,
                apiPercentUsed: 100,
                individualUsed: 392,
                individualLimit: 1000
            ),
            cursorAvailable: true,
            cursorState: .connected,
            codexUsage: makeCodexUsage(short: 78, weekly: 85),
            codexState: .connected
        )

        XCTAssertEqual(
            presentation.entries.map(\.item),
            [.cursorModels, .otherModels, .onDemand, .chatgptFiveHour, .chatgptWeekly]
        )
        XCTAssertEqual(presentation.fallbackText, "AI 39% 100% $3.92 78% 85%")
    }

    func testDefaultPresentationShowsOnlyCursorModelsAndFiveHour() {
        let presentation = StatusBarPresentation(
            settings: .default,
            cursorUsage: makeCursorUsage(
                autoPercentUsed: 39,
                apiPercentUsed: 100,
                individualUsed: 392,
                individualLimit: 1000
            ),
            cursorAvailable: true,
            cursorState: .connected,
            codexUsage: makeCodexUsage(short: 78, weekly: 85),
            codexState: .connected
        )

        XCTAssertEqual(presentation.entries.map(\.item), [.cursorModels, .chatgptFiveHour])
        XCTAssertEqual(presentation.fallbackText, "AI 39% 78%")
    }

    func testDisconnectedChatGPTShowsNeutralZeroPercent() {
        let presentation = StatusBarPresentation(
            settings: allOnSettings(),
            cursorUsage: nil,
            cursorAvailable: false,
            cursorState: .disconnected,
            codexUsage: .disconnected,
            codexState: .disconnected
        )

        XCTAssertEqual(presentation.entries.map(\.item), [.chatgptFiveHour, .chatgptWeekly])
        XCTAssertEqual(presentation.fallbackText, "AI 0% 0%")
    }

    func testNoInstalledAppsShowsOnlyAIStatusLabel() {
        let presentation = StatusBarPresentation(
            settings: allOnSettings(),
            cursorUsage: nil,
            cursorAvailable: false,
            cursorState: .disconnected,
            codexUsage: .disconnected,
            codexState: .disconnected,
            codexAvailable: false
        )

        XCTAssertTrue(presentation.entries.isEmpty)
        XCTAssertEqual(presentation.fallbackText, "AI")
        XCTAssertEqual(presentation.accessibilityDescription, "")
    }

    func testAccessibilityDescriptionDistinguishesUsedAndRemaining() {
        let presentation = StatusBarPresentation(
            settings: allOnSettings(),
            cursorUsage: makeCursorUsage(
                autoPercentUsed: 39,
                apiPercentUsed: 100,
                individualUsed: 392,
                individualLimit: 1000
            ),
            cursorAvailable: true,
            cursorState: .connected,
            codexUsage: makeCodexUsage(short: 78, weekly: 85),
            codexState: .connected
        )

        XCTAssertEqual(
            presentation.accessibilityDescription,
            "Cursor Models 已用 39%，Other Models 已用 100%，On Demand 已用 $3.92，ChatGPT 5 小时剩余 78%，ChatGPT 1 周剩余 85%"
        )
    }
}

final class CursorRowLayoutTests: XCTestCase {
    func testCursorRowsWithoutOnDemandHaveNoThirdRowOrExtraDivider() {
        XCTAssertEqual(
            cursorRowKinds(onDemandAvailable: false),
            [.cursorModels, .otherModels]
        )
        XCTAssertEqual(rowDividerCount(for: 2), 1)
    }

    func testCursorRowsWithOnDemandIncludeThirdRowAndSecondDivider() {
        XCTAssertEqual(
            cursorRowKinds(onDemandAvailable: true),
            [.cursorModels, .otherModels, .onDemand]
        )
        // 三行只有两条行间分隔线，首尾不出现孤立分隔线。
        XCTAssertEqual(rowDividerCount(for: 3), 2)
    }

    func testRowDividerCountForDegenerateCases() {
        XCTAssertEqual(rowDividerCount(for: 0), 0)
        XCTAssertEqual(rowDividerCount(for: 1), 0)
    }
}

// MARK: - Shared Fixtures

private func allOnSettings() -> MenuBarDisplaySettings {
    MenuBarDisplaySettings(
        showCursorModels: true,
        showOtherModels: true,
        showOnDemand: true,
        showChatGPTFiveHour: true,
        showChatGPTWeekly: true
    )
}

private func makeCursorUsage(
    autoPercentUsed: Double = 10,
    apiPercentUsed: Double = 5,
    individualUsed: Double = 0,
    individualLimit: Double = 0
) -> CursorUsage {
    CursorUsage(
        billingCycleStart: 0,
        billingCycleEnd: 0,
        totalPercentUsed: 10,
        autoPercentUsed: autoPercentUsed,
        apiPercentUsed: apiPercentUsed,
        totalSpend: 0,
        includedSpend: 0,
        bonusSpend: 0,
        limit: 0,
        individualLimit: individualLimit,
        individualUsed: individualUsed,
        individualRemaining: individualLimit - individualUsed,
        displayMessage: nil,
        fetchedAt: Date(),
        isUnlimited: false
    )
}

private func makeCodexUsage(short: Double = 78, weekly: Double = 85) -> CodexUsage {
    CodexUsage(
        planName: "ChatGPT Plus",
        shortWindow: QuotaWindow(
            percentRemaining: short,
            resetsAt: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        weeklyWindow: QuotaWindow(
            percentRemaining: weekly,
            resetsAt: Date(timeIntervalSince1970: 1_800_500_000)
        ),
        source: .automatic,
        fetchedAt: Date(),
        note: nil
    )
}
