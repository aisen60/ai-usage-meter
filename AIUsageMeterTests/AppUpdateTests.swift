import Foundation
import XCTest
@testable import AIUsageMeter

final class AppUpdateTests: XCTestCase {
    func testVersionNormalizesVPrefixAndComparesSemVerComponents() {
        XCTAssertEqual(AppVersion("v0.3.2")?.displayName, "v0.3.2")
        XCTAssertEqual(AppVersion("0.3.2+build.1")?.rawValue, "0.3.2")
        XCTAssertTrue(AppVersion("0.3.10")! > AppVersion("0.3.2")!)
        XCTAssertEqual(AppVersion("v0.3.2"), AppVersion("0.3.2"))
    }

    func testPrereleaseVersionIsNotAcceptedAsStable() {
        XCTAssertNil(AppVersion("v0.4.0-beta.1"))
    }

    func testStableReleaseRequiresMatchingArchiveAndChecksum() throws {
        let candidate = try XCTUnwrap(AppUpdateCandidateFixture.makeCandidate())
        let release = GitHubUpdateService.Release(
            tagName: "v0.3.2",
            htmlURL: candidate.releaseURL,
            draft: false,
            prerelease: false,
            assets: [
                .init(name: "AIUsageMeter-0.3.2.zip", browserDownloadURL: candidate.archiveURL),
                .init(name: "AIUsageMeter-0.3.2.zip.sha256", browserDownloadURL: candidate.checksumURL)
            ]
        )

        let result = GitHubUpdateService.selectResult(
            releases: [release],
            tags: [.init(name: "v0.3.2")],
            currentVersion: AppVersion("0.3.1")!
        )

        XCTAssertEqual(result.candidate, candidate)
        XCTAssertEqual(result.latestVersion, AppVersion("0.3.2"))
    }

    func testPrereleaseAndNewerTagDoNotProduceInstallableCandidate() {
        let release = GitHubUpdateService.Release(
            tagName: "v0.4.0-beta.1",
            htmlURL: URL(string: "https://github.com/aisen60/ai-usage-meter/releases/tag/v0.4.0-beta.1")!,
            draft: false,
            prerelease: false,
            assets: []
        )
        let result = GitHubUpdateService.selectResult(
            releases: [release],
            tags: [.init(name: "v0.3.3")],
            currentVersion: AppVersion("0.3.1")!
        )

        XCTAssertEqual(result.latestVersion, AppVersion("0.3.3"))
        XCTAssertNil(result.candidate)
    }

    func testReleaseWithoutArchiveOrChecksumIsNotInstallable() {
        let release = GitHubUpdateService.Release(
            tagName: "v0.3.2",
            htmlURL: URL(string: "https://github.com/aisen60/ai-usage-meter/releases/tag/v0.3.2")!,
            draft: false,
            prerelease: false,
            assets: [
                .init(
                    name: "AIUsageMeter-0.3.2.zip",
                    browserDownloadURL: URL(string: "https://example.com/app.zip")!
                )
            ]
        )

        let result = GitHubUpdateService.selectResult(
            releases: [release],
            tags: [.init(name: "v0.3.2")],
            currentVersion: AppVersion("0.3.1")!
        )

        XCTAssertNil(result.candidate)
    }

    func testUsableStableReleaseRemainsAvailableWhenNewerTagHasNoReleaseAssets() throws {
        let candidate = try XCTUnwrap(AppUpdateCandidateFixture.makeCandidate())
        let release = GitHubUpdateService.Release(
            tagName: "v0.3.2",
            htmlURL: candidate.releaseURL,
            draft: false,
            prerelease: false,
            assets: [
                .init(name: "AIUsageMeter-0.3.2.zip", browserDownloadURL: candidate.archiveURL),
                .init(name: "AIUsageMeter-0.3.2.zip.sha256", browserDownloadURL: candidate.checksumURL)
            ]
        )

        let result = GitHubUpdateService.selectResult(
            releases: [release],
            tags: [.init(name: "v0.3.3")],
            currentVersion: AppVersion("0.3.1")!
        )

        XCTAssertEqual(result.candidate, candidate)
        XCTAssertEqual(result.latestVersion, AppVersion("0.3.3"))
    }

    func testChecksumVerificationAcceptsSha256FileAndRejectsMismatch() {
        let archive = Data("hello".utf8)
        let checksum = Data("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824  update.zip\n".utf8)

        XCTAssertTrue(AppUpdateInstaller.verify(archiveData: archive, checksumData: checksum))
        XCTAssertFalse(AppUpdateInstaller.verify(archiveData: archive, checksumData: Data("bad  update.zip".utf8)))
    }

    @MainActor
    func testControllerTransitionsToAvailableAndPersistsResult() async throws {
        let defaults = UserDefaults(suiteName: "AppUpdateTests.controller")!
        defaults.removePersistentDomain(forName: "AppUpdateTests.controller")
        defer { defaults.removePersistentDomain(forName: "AppUpdateTests.controller") }

        let loader = MockUpdateDataLoader(
            releaseData: Data("""
            [{"tag_name":"v0.3.2","html_url":"https://github.com/aisen60/ai-usage-meter/releases/tag/v0.3.2","draft":false,"prerelease":false,"assets":[{"name":"AIUsageMeter-0.3.2.zip","browser_download_url":"https://example.com/app.zip"},{"name":"AIUsageMeter-0.3.2.zip.sha256","browser_download_url":"https://example.com/app.zip.sha256"}]}]
            """.utf8),
            tagData: Data("[{\"name\":\"v0.3.2\"}]".utf8)
        )
        let controller = AppUpdateController(
            service: GitHubUpdateService(loader: loader),
            defaults: defaults,
            currentVersion: AppVersion("0.3.1")!,
            autoStart: false
        )

        controller.checkNow()
        while controller.status == .checking {
            await Task.yield()
        }

        guard case .available(let candidate) = controller.status else {
            return XCTFail("Expected an available update")
        }
        XCTAssertEqual(candidate.version, AppVersion("0.3.2"))
        XCTAssertNotNil(defaults.data(forKey: "appUpdate.candidate"))
        XCTAssertNotNil(defaults.object(forKey: "appUpdate.lastCheckDate"))
    }

    func testUpdateCopyIsLocalized() {
        XCTAssertEqual(
            AppLanguage.localized("settings.updates", locale: AppLanguage.simplifiedChinese.locale),
            "更新"
        )
        XCTAssertEqual(
            AppLanguage.localized("settings.updates", locale: AppLanguage.english.locale),
            "Updates"
        )
        XCTAssertEqual(
            AppLanguage.localized("settings.update.download", locale: AppLanguage.english.locale),
            "Download Latest"
        )
    }

    @MainActor
    func testRecentSavedCandidateIsRestoredWithoutNetworkCheck() throws {
        let defaults = UserDefaults(suiteName: "AppUpdateTests.restore")!
        defaults.removePersistentDomain(forName: "AppUpdateTests.restore")
        defer { defaults.removePersistentDomain(forName: "AppUpdateTests.restore") }

        let candidate = try XCTUnwrap(AppUpdateCandidateFixture.makeCandidate())
        defaults.set(Date(), forKey: "appUpdate.lastCheckDate")
        defaults.set(try JSONEncoder().encode(candidate), forKey: "appUpdate.candidate")

        let controller = AppUpdateController(
            defaults: defaults,
            currentVersion: AppVersion("0.3.1")!,
            autoStart: false
        )

        guard case .available(let restored) = controller.status else {
            return XCTFail("Expected the recent candidate to be restored")
        }
        XCTAssertEqual(restored, candidate)
    }
}

private enum AppUpdateCandidateFixture {
    static func makeCandidate() -> AppUpdateCandidate? {
        AppUpdateCandidate(
            version: AppVersion("0.3.2")!,
            releaseURL: URL(string: "https://github.com/aisen60/ai-usage-meter/releases/tag/v0.3.2")!,
            archiveURL: URL(string: "https://example.com/AIUsageMeter-0.3.2.zip")!,
            checksumURL: URL(string: "https://example.com/AIUsageMeter-0.3.2.zip.sha256")!
        )
    }
}

private struct MockUpdateDataLoader: UpdateDataLoading {
    let releaseData: Data
    let tagData: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let data = request.url?.path.contains("/releases") == true ? releaseData : tagData
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
