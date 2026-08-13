import Darwin
import XCTest
@testable import AgentQuotaBar

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
                "individualRemaining": 400
            ],
            "displayMessage": "usage summary"
        ]

        let usage = try XCTUnwrap(CursorUsage.from(json: json, fetchedAt: fetchedAt))
        XCTAssertEqual(usage.totalPercentUsed, 10.5)
        XCTAssertEqual(usage.autoPercentUsed, 15)
        XCTAssertEqual(usage.apiPercentUsed, 2)
        XCTAssertEqual(usage.autoPercentRemaining, 85)
        XCTAssertEqual(usage.individualRemaining, 400)
        XCTAssertEqual(usage.fetchedAt, fetchedAt)
    }

    func testCodexUsesLongestWindowAndConvertsRemainingPercent() throws {
        let response = codexResponse(
            planType: "pro",
            primary: [
                "usedPercent": 65,
                "windowDurationMins": 300,
                "resetsAt": 1_800_000_000
            ],
            secondary: [
                "usedPercent": 20,
                "windowDurationMins": 10_080,
                "resetsAt": 1_800_500_000
            ]
        )

        let usage = try CodexIntegration.parseResponse(response)
        XCTAssertEqual(usage.planName, "Codex Pro")
        XCTAssertEqual(usage.percentRemaining, 80)
        XCTAssertEqual(usage.cycleEndDate, Date(timeIntervalSince1970: 1_800_500_000))
    }

    func testCodexPlanMappingThroughResponse() throws {
        let business = try CodexIntegration.parseResponse(
            codexResponse(planType: "business")
        )
        let unknown = try CodexIntegration.parseResponse(
            codexResponse(planType: "future_plan")
        )

        XCTAssertEqual(business.planName, "Codex Business")
        XCTAssertEqual(unknown.planName, "Codex")
    }

    func testCodexRemainingPercentIsClamped() throws {
        let belowZero = try CodexIntegration.parseResponse(
            codexResponse(planType: "plus", usedPercent: 120)
        )
        let aboveHundred = try CodexIntegration.parseResponse(
            codexResponse(planType: "plus", usedPercent: -10)
        )

        XCTAssertEqual(belowZero.percentRemaining, 0)
        XCTAssertEqual(aboveHundred.percentRemaining, 100)
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

    private func codexResponse(
        planType: String,
        usedPercent: Double = 15,
        primary: [String: Any]? = nil,
        secondary: [String: Any]? = nil
    ) -> [String: Any] {
        var limits: [String: Any] = [
            "planType": planType,
            "primary": primary ?? [
                "usedPercent": usedPercent,
                "windowDurationMins": 10_080,
                "resetsAt": 1_800_000_000
            ]
        ]
        if let secondary {
            limits["secondary"] = secondary
        }

        return [
            "id": 2,
            "result": [
                "rateLimitsByLimitId": ["codex": limits]
            ]
        ]
    }
}
