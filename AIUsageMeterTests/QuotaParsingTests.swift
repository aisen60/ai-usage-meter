import Darwin
import XCTest
@testable import AIUsageMeter

final class QuotaParsingTests: XCTestCase {

    func testCursorInstallationDetectionUsesApplicationBundle() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cursorApplication = temporaryDirectory
            .appendingPathComponent("Cursor.app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        XCTAssertFalse(
            CursorTokenReader.isCursorInstalled(applicationURLs: [cursorApplication])
        )

        try FileManager.default.createDirectory(
            at: cursorApplication,
            withIntermediateDirectories: true
        )
        XCTAssertTrue(
            CursorTokenReader.isCursorInstalled(applicationURLs: [cursorApplication])
        )
    }

    func testChatGPTInstallationDetectionUsesApplicationBundle() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let chatGPTApplication = temporaryDirectory
            .appendingPathComponent("ChatGPT.app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        XCTAssertFalse(
            CodexIntegration.isChatGPTInstalled(applicationURLs: [chatGPTApplication])
        )

        try FileManager.default.createDirectory(
            at: chatGPTApplication,
            withIntermediateDirectories: true
        )
        XCTAssertTrue(
            CodexIntegration.isChatGPTInstalled(applicationURLs: [chatGPTApplication])
        )
    }

    func testCodexBundledExecutableDiscoveryUsesCodexCLILayout() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let chatGPTApplication = temporaryDirectory
            .appendingPathComponent("ChatGPT.app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let executable = chatGPTApplication
            .appendingPathComponent("Contents/Resources/codex-cli/bin/codex")
        try makeExecutable(at: executable)

        let candidates = CodexIntegration.bundledExecutableCandidates(
            inApplicationAt: chatGPTApplication
        )
        XCTAssertEqual(
            CodexIntegration.firstExecutable(in: candidates)?.standardizedFileURL,
            executable.standardizedFileURL
        )
    }

    func testCodexBundledExecutableDiscoveryUsesPackageManifestEntrypoint() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let chatGPTApplication = temporaryDirectory
            .appendingPathComponent("ChatGPT.app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let codexCLI = chatGPTApplication
            .appendingPathComponent("Contents/Resources/codex-cli", isDirectory: true)
        let executable = codexCLI.appendingPathComponent("custom/codex-bin")
        try makeExecutable(at: executable)
        try FileManager.default.createDirectory(
            at: codexCLI,
            withIntermediateDirectories: true
        )
        let manifest = ["entrypoint": "custom/codex-bin"]
        try JSONSerialization.data(withJSONObject: manifest)
            .write(to: codexCLI.appendingPathComponent("codex-package.json"))

        let candidates = CodexIntegration.bundledExecutableCandidates(
            inApplicationAt: chatGPTApplication
        )
        XCTAssertEqual(
            CodexIntegration.firstExecutable(in: candidates)?.standardizedFileURL,
            executable.standardizedFileURL
        )
    }

    func testCodexBundledExecutableDiscoveryFallsBackToLegacyLayout() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let chatGPTApplication = temporaryDirectory
            .appendingPathComponent("ChatGPT.app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let executable = chatGPTApplication
            .appendingPathComponent("Contents/Resources/codex")
        try makeExecutable(at: executable)

        let candidates = CodexIntegration.bundledExecutableCandidates(
            inApplicationAt: chatGPTApplication
        )
        XCTAssertEqual(
            CodexIntegration.firstExecutable(in: candidates)?.standardizedFileURL,
            executable.standardizedFileURL
        )
    }

    func testCursorPlanMapping() {
        XCTAssertEqual(CursorTokenReader.displayPlanName(for: "free"), "Cursor Hobby")
        XCTAssertEqual(CursorTokenReader.displayPlanName(for: "pro"), "Cursor Pro")
        XCTAssertEqual(CursorTokenReader.displayPlanName(for: "pro_plus"), "Cursor Pro+")
        XCTAssertEqual(CursorTokenReader.displayPlanName(for: "ultra"), "Cursor Ultra")
        XCTAssertEqual(CursorTokenReader.displayPlanName(for: "enterprise"), "Cursor Enterprise")
        XCTAssertEqual(CursorTokenReader.displayPlanName(for: "future_plan"), "Cursor")
    }

    func testCursorUsageParsing() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let json: [String: Any] = [
            "billingCycleStart": "1784207779000",
            "billingCycleEnd": "1786886179000",
            "planUsage": [
                "totalPercentUsed": 10.5,
                "autoPercentUsed": 15,
                "apiPercentUsed": 2,
                "totalSpend": 3622,
                "includedSpend": 2000,
                "bonusSpend": 1622,
                "limit": 2000
            ],
            "spendLimitUsage": [
                "individualLimit": 600,
                "individualUsed": 200,
                "individualRemaining": 400
            ],
            "displayMessage": "usage summary"
        ]

        let usage = try XCTUnwrap(CursorUsage.from(json: json, fetchedAt: fetchedAt))
        XCTAssertEqual(usage.totalPercentUsed, 10.5)
        XCTAssertEqual(usage.autoPercentUsed, 15)
        XCTAssertEqual(usage.apiPercentUsed, 2)
        XCTAssertEqual(usage.autoPercentRemaining, 85)
        XCTAssertEqual(usage.individualUsed, 200)
        XCTAssertEqual(usage.individualRemaining, 400)
        XCTAssertEqual(usage.fetchedAt, fetchedAt)
    }

    // MARK: - Cursor On Demand

    func testCursorOnDemandAmountAndPercent() throws {
        let usage = try XCTUnwrap(
            CursorUsage.from(json: cursorOnDemandJSON(individualUsed: 392, individualLimit: 1000))
        )

        XCTAssertTrue(usage.onDemandAvailable)
        XCTAssertEqual(usage.onDemandUsedAmountText, "$3.92")
        XCTAssertEqual(usage.onDemandAmountText, "$3.92 / $10")
        XCTAssertEqual(usage.onDemandPercentUsed, 39.2, accuracy: 0.001)
        XCTAssertEqual(usage.onDemandUsedDollars, 3.92, accuracy: 0.001)
        XCTAssertEqual(usage.onDemandLimitDollars, 10.0, accuracy: 0.001)
    }

    func testCursorOnDemandZeroLimitIsUnavailable() throws {
        let usage = try XCTUnwrap(
            CursorUsage.from(json: cursorOnDemandJSON(individualUsed: 50, individualLimit: 0))
        )
        XCTAssertFalse(usage.onDemandAvailable)
    }

    func testCursorOnDemandMissingFieldsIsUnavailable() throws {
        let usage = try XCTUnwrap(CursorUsage.from(json: cursorOnDemandJSON()))
        XCTAssertFalse(usage.onDemandAvailable)
    }

    func testCursorOnDemandOverLimitClampsToHundred() throws {
        let usage = try XCTUnwrap(
            CursorUsage.from(json: cursorOnDemandJSON(individualUsed: 1500, individualLimit: 1000))
        )
        XCTAssertEqual(usage.onDemandPercentUsed, 100)
    }

    func testCursorOnDemandParsesNumericStrings() throws {
        let usage = try XCTUnwrap(
            CursorUsage.from(json: cursorOnDemandJSON(individualUsed: "392", individualLimit: "1000"))
        )
        XCTAssertTrue(usage.onDemandAvailable)
        XCTAssertEqual(usage.onDemandUsedAmountText, "$3.92")
        XCTAssertEqual(usage.onDemandAmountText, "$3.92 / $10")
    }

    func testCursorUsageDecodesLegacyCacheWithoutIndividualUsed() throws {
        // v0.2.0 缓存的 CursorUsage 不含 individualUsed，应由 limit - remaining 反推。
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let legacyJSON: [String: Any] = [
            "billingCycleStart": 0,
            "billingCycleEnd": 0,
            "totalPercentUsed": 10,
            "autoPercentUsed": 15,
            "apiPercentUsed": 2,
            "totalSpend": 0,
            "includedSpend": 0,
            "bonusSpend": 0,
            "limit": 0,
            "individualLimit": 1000,
            "individualRemaining": 400,
            "fetchedAt": fetchedAt.timeIntervalSinceReferenceDate,
            "isUnlimited": false
        ]

        let data = try JSONSerialization.data(withJSONObject: legacyJSON)
        let usage = try JSONDecoder().decode(CursorUsage.self, from: data)

        XCTAssertEqual(usage.individualUsed, 600)
        XCTAssertEqual(usage.fetchedAt, fetchedAt)
    }

    // MARK: - ChatGPT 额度窗口

    func testCodexParsesBothWindowsByDuration() throws {
        let usage = try CodexIntegration.parseResponse(codexResponse(planType: "pro"))

        XCTAssertEqual(usage.planName, "ChatGPT Pro")
        XCTAssertEqual(usage.shortWindow?.percentRemaining, 80)
        XCTAssertEqual(
            usage.shortWindow?.resetsAt,
            Date(timeIntervalSince1970: 1_800_000_000)
        )
        XCTAssertEqual(usage.weeklyWindow?.percentRemaining, 35)
        XCTAssertEqual(
            usage.weeklyWindow?.resetsAt,
            Date(timeIntervalSince1970: 1_800_500_000)
        )
    }

    func testCodexParsesWeeklyOnlyWindow() throws {
        // 当前 Pro Lite 账号的真实响应：primary 为 1 周，secondary 为 null。
        let usage = try CodexIntegration.parseResponse(codexResponse(
            planType: "prolite",
            primary: [
                "usedPercent": 100,
                "windowDurationMins": 10_080,
                "resetsAt": 1_793_082_769
            ],
            includeSecondary: false
        ))

        XCTAssertEqual(usage.planName, "ChatGPT Pro Lite")
        XCTAssertNil(usage.shortWindow)
        XCTAssertEqual(usage.weeklyWindow?.percentRemaining, 0)
        XCTAssertEqual(
            usage.weeklyWindow?.resetsAt,
            Date(timeIntervalSince1970: 1_793_082_769)
        )
    }

    func testCodexParsesShortOnlyWindow() throws {
        let usage = try CodexIntegration.parseResponse(codexResponse(
            planType: "plus",
            includeSecondary: false
        ))

        XCTAssertEqual(usage.shortWindow?.percentRemaining, 80)
        XCTAssertNil(usage.weeklyWindow)
    }

    func testCodexClassifiesWindowsRegardlessOfFieldOrder() throws {
        // primary 是周窗口、secondary 是短窗口，仍应按时长正确归类。
        let usage = try CodexIntegration.parseResponse(codexResponse(
            planType: "plus",
            primary: ["usedPercent": 30, "windowDurationMins": 10_080, "resetsAt": 1_800_500_000],
            secondary: ["usedPercent": 10, "windowDurationMins": 300, "resetsAt": 1_800_000_000]
        ))

        XCTAssertEqual(usage.shortWindow?.percentRemaining, 90)
        XCTAssertEqual(usage.weeklyWindow?.percentRemaining, 70)
        XCTAssertEqual(usage.shortWindow?.resetsAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(usage.weeklyWindow?.resetsAt, Date(timeIntervalSince1970: 1_800_500_000))
    }

    func testCodexPlanMappingThroughResponse() throws {
        let business = try CodexIntegration.parseResponse(
            codexResponse(planType: "business")
        )
        let unknown = try CodexIntegration.parseResponse(
            codexResponse(planType: "future_plan")
        )

        XCTAssertEqual(business.planName, "ChatGPT Business")
        XCTAssertEqual(unknown.planName, "ChatGPT")
    }

    func testCodexRemainingPercentIsClamped() throws {
        let usage = try CodexIntegration.parseResponse(codexResponse(
            planType: "plus",
            primary: ["usedPercent": 120, "windowDurationMins": 300, "resetsAt": 1_800_000_000],
            secondary: ["usedPercent": -10, "windowDurationMins": 10_080, "resetsAt": 1_800_500_000]
        ))

        XCTAssertEqual(usage.shortWindow?.percentRemaining, 0)
        XCTAssertEqual(usage.weeklyWindow?.percentRemaining, 100)
    }

    func testCodexMissingBothWindowsThrows() {
        XCTAssertThrowsError(
            try CodexIntegration.parseResponse(codexResponse(
                planType: "plus",
                includePrimary: false,
                includeSecondary: false
            ))
        )
    }

    func testCodexUnknownWindowDurationThrows() {
        // 1 天 = 1440 分钟，既不是约 300 分钟也不是约 10080 分钟。
        XCTAssertThrowsError(
            try CodexIntegration.parseResponse(codexResponse(
                planType: "plus",
                primary: ["usedPercent": 20, "windowDurationMins": 1440, "resetsAt": 1_800_000_000]
            ))
        )
    }

    func testCodexDuplicateWindowClassificationThrows() {
        // 两个窗口都是短周期，无法映射为 5 小时 + 1 周。
        XCTAssertThrowsError(
            try CodexIntegration.parseResponse(codexResponse(
                planType: "plus",
                secondary: ["usedPercent": 65, "windowDurationMins": 300, "resetsAt": 1_800_500_000]
            ))
        )
    }

    func testCodexMissingUsedPercentThrows() {
        XCTAssertThrowsError(
            try CodexIntegration.parseResponse(codexResponse(
                planType: "plus",
                primary: ["windowDurationMins": 300, "resetsAt": 1_800_000_000]
            ))
        )
    }

    func testCodexMalformedResponseThrows() {
        XCTAssertThrowsError(
            try CodexIntegration.parseResponse(["id": 2, "result": [:]])
        )
        XCTAssertThrowsError(
            try CodexIntegration.parseResponse([
                "id": 2,
                "error": ["message": "not logged in"]
            ])
        )
    }

    func testCodexProcessFailureDoesNotLeaveAChildProcess() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("fake-codex")
        let pidFile = directory.appendingPathComponent("pid")
        let script = """
        #!/bin/sh
        echo $$ > "\(pidFile.path)"
        exec /bin/sleep 60
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        XCTAssertEqual(chmod(executable.path, 0o700), 0)

        do {
            _ = try await CodexIntegration.fetchUsage(
                executableURL: executable,
                requestTimeout: .seconds(1)
            )
            XCTFail("Expected timeout")
        } catch let error as CodexIntegration.IntegrationError {
            guard case .timedOut = error else {
                return XCTFail("Expected timeout, got \(error)")
            }
        }

        let pidText = try String(contentsOf: pidFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = try XCTUnwrap(Int32(pidText))

        for _ in 0..<20 where kill(pid, 0) == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNotEqual(kill(pid, 0), 0, "Codex child process is still running")
    }

    // MARK: - Helpers

    private func makeExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(chmod(url.path, 0o700), 0)
    }

    private func cursorOnDemandJSON(
        individualUsed: Any? = nil,
        individualLimit: Any? = nil,
        individualRemaining: Any? = nil
    ) -> [String: Any] {
        var spendLimit: [String: Any] = [:]
        if let individualUsed {
            spendLimit["individualUsed"] = individualUsed
        }
        if let individualLimit {
            spendLimit["individualLimit"] = individualLimit
        }
        if let individualRemaining {
            spendLimit["individualRemaining"] = individualRemaining
        }
        return [
            "planUsage": [
                "totalPercentUsed": 10,
                "autoPercentUsed": 15,
                "apiPercentUsed": 2,
                "totalSpend": 0,
                "includedSpend": 0,
                "bonusSpend": 0,
                "limit": 0
            ],
            "spendLimitUsage": spendLimit
        ]
    }

    private func codexResponse(
        planType: String,
        primary: [String: Any]? = nil,
        secondary: [String: Any]? = nil,
        includePrimary: Bool = true,
        includeSecondary: Bool = true
    ) -> [String: Any] {
        var limits: [String: Any] = [
            "planType": planType
        ]
        if includePrimary {
            limits["primary"] = primary ?? [
                "usedPercent": 20,
                "windowDurationMins": 300,
                "resetsAt": 1_800_000_000
            ]
        }
        if includeSecondary {
            limits["secondary"] = secondary ?? [
                "usedPercent": 65,
                "windowDurationMins": 10_080,
                "resetsAt": 1_800_500_000
            ]
        }

        return [
            "id": 2,
            "result": [
                "rateLimitsByLimitId": ["codex": limits]
            ]
        ]
    }
}
