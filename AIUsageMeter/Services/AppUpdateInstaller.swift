import AppKit
import CryptoKit
import Foundation

struct PreparedAppUpdate {
    let candidate: AppUpdateCandidate
    let stagedAppURL: URL
    let workingDirectory: URL
}

struct AppUpdateInstaller {
    private let loader: UpdateDataLoading
    private let fileManager: FileManager

    init(
        loader: UpdateDataLoading = URLSessionUpdateDataLoader(),
        fileManager: FileManager = .default
    ) {
        self.loader = loader
        self.fileManager = fileManager
    }

    func prepare(
        candidate: AppUpdateCandidate,
        currentBundleIdentifier: String,
        currentAppURL: URL
    ) async throws -> PreparedAppUpdate {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("AIUsageMeter-update-\(UUID().uuidString)")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            let archiveData = try await download(candidate.archiveURL)
            let checksumData = try await download(candidate.checksumURL)
            guard Self.verify(archiveData: archiveData, checksumData: checksumData) else {
                throw AppUpdateInstallerError.checksumMismatch
            }

            let archiveURL = directory.appendingPathComponent("update.zip")
            try archiveData.write(to: archiveURL, options: .atomic)
            try run("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, directory.path])

            let apps = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "app" }
            guard let appURL = apps.first,
                  let bundle = Bundle(url: appURL),
                  bundle.bundleIdentifier == currentBundleIdentifier,
                  let versionValue = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                  let version = AppVersion(versionValue),
                  version == candidate.version else {
                throw AppUpdateInstallerError.invalidApplication
            }

            _ = currentAppURL
            return PreparedAppUpdate(
                candidate: candidate,
                stagedAppURL: appURL,
                workingDirectory: directory
            )
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    func scheduleReplacement(
        preparedUpdate: PreparedAppUpdate,
        currentAppURL: URL
    ) throws {
        guard let executableURL = Bundle.main.executableURL else {
            throw AppUpdateInstallerError.helperUnavailable
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--ai-usage-meter-update-helper",
            "--parent-pid", String(ProcessInfo.processInfo.processIdentifier),
            "--source-app", preparedUpdate.stagedAppURL.path,
            "--destination-app", currentAppURL.path,
            "--fallback-url", preparedUpdate.candidate.releaseURL.absoluteString
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static func verify(archiveData: Data, checksumData: Data) -> Bool {
        let actual = SHA256.hash(data: archiveData)
            .map { String(format: "%02x", $0) }
            .joined()
            .lowercased()
        let checksumText = String(decoding: checksumData, as: UTF8.self)
        guard let expected = checksumText
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .first else { return false }
        return actual == expected.lowercased()
    }

    private func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        let (data, response) = try await loader.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw AppUpdateInstallerError.downloadFailed
        }
        return data
    }

    private func run(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateInstallerError.extractionFailed
        }
    }
}

enum AppUpdateInstallerError: Error {
    case downloadFailed
    case checksumMismatch
    case extractionFailed
    case invalidApplication
    case helperUnavailable
}

enum AppUpdateHelper {
    static var isInvocation: Bool {
        CommandLine.arguments.contains("--ai-usage-meter-update-helper")
    }

    static func runIfNeeded() {
        guard isInvocation,
              let parentPID = value(for: "--parent-pid").flatMap(Int32.init),
              let sourcePath = value(for: "--source-app"),
              let destinationPath = value(for: "--destination-app"),
              let fallback = value(for: "--fallback-url").flatMap(URL.init(string:)) else {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            waitForExit(parentPID)
            do {
                try replace(
                    source: URL(fileURLWithPath: sourcePath),
                    destination: URL(fileURLWithPath: destinationPath)
                )
                _ = NSWorkspace.shared.open(URL(fileURLWithPath: destinationPath))
            } catch {
                _ = NSWorkspace.shared.open(fallback)
                _ = NSWorkspace.shared.open(URL(fileURLWithPath: destinationPath))
            }
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private static func value(for key: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: key),
              index + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[index + 1]
    }

    private static func waitForExit(_ pid: Int32) {
        for _ in 0..<600 {
            if kill(pid, 0) != 0 { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    private static func replace(source: URL, destination: URL) throws {
        let fileManager = FileManager.default
        let staged = destination.deletingLastPathComponent()
            .appendingPathComponent(".AIUsageMeter-new-\(UUID().uuidString).app")
        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent(".AIUsageMeter-old-\(UUID().uuidString).app")
        try run("/usr/bin/ditto", arguments: [source.path, staged.path])
        try fileManager.moveItem(at: destination, to: backup)
        do {
            try fileManager.moveItem(at: staged, to: destination)
        } catch {
            try? fileManager.moveItem(at: backup, to: destination)
            throw error
        }
        try? fileManager.removeItem(at: backup)
    }

    private static func run(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppUpdateInstallerError.extractionFailed }
    }
}
