import XCTest
@testable import AIUsageMeter

final class AppLanguageTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AppLanguageTests")
        defaults.removePersistentDomain(forName: "AppLanguageTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AppLanguageTests")
        defaults = nil
        super.tearDown()
    }

    func testMissingPreferenceDefaultsToSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.load(from: defaults), .simplifiedChinese)
    }

    func testLanguagePreferenceRoundTrips() {
        AppLanguage.english.save(to: defaults)
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
    }

    func testInvalidPreferenceFallsBackToSimplifiedChinese() {
        defaults.set("fr", forKey: AppLanguage.storageKey)
        XCTAssertEqual(AppLanguage.load(from: defaults), .simplifiedChinese)
    }

    func testRefreshTimeUsesSelectedLanguage() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let refreshedAt = now.addingTimeInterval(-120)

        XCTAssertEqual(
            RefreshTimeFormatter.text(
                isRefreshing: false,
                lastRefreshTime: refreshedAt,
                now: now,
                locale: AppLanguage.simplifiedChinese.locale
            ),
            "2 分钟前"
        )
        XCTAssertEqual(
            RefreshTimeFormatter.text(
                isRefreshing: false,
                lastRefreshTime: refreshedAt,
                now: now,
                locale: AppLanguage.english.locale
            ),
            "2 min ago"
        )
    }

    func testJustUpdatedUsesCompactEnglishText() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)

        XCTAssertEqual(
            RefreshTimeFormatter.text(
                isRefreshing: false,
                lastRefreshTime: now.addingTimeInterval(-10),
                now: now,
                locale: AppLanguage.english.locale
            ),
            "Just now"
        )
    }

    func testQuotaResetDetailUsesSelectedLanguage() {
        let resetDate = Date(timeIntervalSinceReferenceDate: 10_000)
        let chinese = QuotaResetFormatter.weeklyWindowDetail(
            resetsAt: resetDate,
            locale: AppLanguage.simplifiedChinese.locale
        )
        let english = QuotaResetFormatter.weeklyWindowDetail(
            resetsAt: resetDate,
            locale: AppLanguage.english.locale
        )

        XCTAssertTrue(chinese.hasSuffix(" 重置"))
        XCTAssertTrue(english.hasPrefix("Resets "))
        XCTAssertNotEqual(chinese, english)
    }

    func testOnlyNotInstalledAppsNeedDownloadLinks() {
        XCTAssertTrue(SupportedAppStatus.notInstalled.needsDownloadLink)
        XCTAssertFalse(SupportedAppStatus.loggedIn.needsDownloadLink)
        XCTAssertFalse(SupportedAppStatus.detecting.needsDownloadLink)
        XCTAssertFalse(SupportedAppStatus.installed.needsDownloadLink)
        XCTAssertFalse(SupportedAppStatus.unavailable.needsDownloadLink)
    }
}

@MainActor
final class LaunchAtLoginSettingsTests: XCTestCase {
    func testUnregisteredLoginItemDefaultsToDisabled() {
        let service = MockLaunchAtLoginService(status: .disabled)
        let settings = LaunchAtLoginSettings(service: service)

        XCTAssertFalse(settings.isEnabled)
    }

    func testRegisteredLoginItemIsEnabled() {
        let service = MockLaunchAtLoginService(status: .enabled)
        let settings = LaunchAtLoginSettings(service: service)

        XCTAssertTrue(settings.isEnabled)
    }

    func testTemporaryInstallationIsNotSupportedForLaunchAtLogin() {
        XCTAssertFalse(
            LaunchAtLoginService.isSupportedInstallation(
                at: URL(fileURLWithPath: "/private/tmp/AI Usage Meter.app")
            )
        )
    }

    func testApplicationsInstallationSupportsLaunchAtLogin() {
        XCTAssertTrue(
            LaunchAtLoginService.isSupportedInstallation(
                at: URL(fileURLWithPath: "/Applications/AI Usage Meter.app")
            )
        )
    }

    func testNotFoundLoginItemIsTreatedAsDisabled() {
        XCTAssertEqual(
            LaunchAtLoginService.status(for: .notFound),
            .disabled
        )
    }

    func testEnablingRegistersTheLoginItem() {
        let service = MockLaunchAtLoginService(status: .disabled)
        let settings = LaunchAtLoginSettings(service: service)

        settings.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertTrue(settings.isEnabled)
    }

    func testDisablingUnregistersTheLoginItem() {
        let service = MockLaunchAtLoginService(status: .enabled)
        let settings = LaunchAtLoginSettings(service: service)

        settings.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertFalse(settings.isEnabled)
    }

    func testFailedUpdateRestoresSystemStateAndShowsError() {
        let service = MockLaunchAtLoginService(status: .disabled, registerError: MockError.failed)
        let settings = LaunchAtLoginSettings(service: service)

        settings.setEnabled(true)

        XCTAssertFalse(settings.isEnabled)
        XCTAssertTrue(settings.didFailLastUpdate)
    }

    func testApprovalRequiredIsExposedForSystemSettingsLink() {
        let service = MockLaunchAtLoginService(status: .requiresApproval)
        let settings = LaunchAtLoginSettings(service: service)

        XCTAssertTrue(settings.needsSystemApproval)
        XCTAssertEqual(
            LaunchAtLoginSettings.loginItemsSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        )
    }

    func testStartupStringsAreLocalized() {
        XCTAssertEqual(
            AppLanguage.localized("settings.launchAtLogin", locale: AppLanguage.simplifiedChinese.locale),
            "开机时启动"
        )
        XCTAssertEqual(
            AppLanguage.localized("settings.launchAtLogin", locale: AppLanguage.english.locale),
            "Launch at Login"
        )
    }
}

private final class MockLaunchAtLoginService: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus
    var registerCallCount = 0
    var unregisterCallCount = 0
    var registerError: Error?
    var unregisterError: Error?

    init(
        status: LaunchAtLoginStatus,
        registerError: Error? = nil,
        unregisterError: Error? = nil
    ) {
        self.status = status
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .disabled
    }
}

private enum MockError: Error {
    case failed
}
