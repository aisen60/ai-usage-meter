import AppKit
import Combine
import Foundation

@MainActor
final class AppUpdateController: ObservableObject {
    static let checkInterval: TimeInterval = 5 * 60 * 60
    private static let lastCheckKey = "appUpdate.lastCheckDate"
    private static let candidateKey = "appUpdate.candidate"

    @Published private(set) var status: AppUpdateStatus = .idle

    let currentVersion: AppVersion

    private let service: GitHubUpdateService
    private let installer: AppUpdateInstaller
    private let defaults: UserDefaults
    private var operation: Task<Void, Never>?
    private var scheduler: Task<Void, Never>?
    private var lastCheckDate: Date?

    init(
        service: GitHubUpdateService = GitHubUpdateService(),
        installer: AppUpdateInstaller = AppUpdateInstaller(),
        defaults: UserDefaults = .standard,
        currentVersion: AppVersion = .current,
        autoStart: Bool = true
    ) {
        self.service = service
        self.installer = installer
        self.defaults = defaults
        self.currentVersion = currentVersion
        restoreSavedState()
        if autoStart { startScheduler() }
    }

    deinit {
        operation?.cancel()
        scheduler?.cancel()
    }

    var currentVersionName: String { currentVersion.displayName }

    func description(locale: Locale) -> String {
        switch status {
        case .idle:
            return AppLanguage.localized("settings.update.checkDescription", locale: locale)
        case .checking:
            return AppLanguage.localized("settings.update.checking", locale: locale)
        case .upToDate:
            return AppLanguage.localized("settings.update.upToDate", locale: locale)
        case .available(let candidate):
            return AppLanguage.localized(
                "settings.update.available",
                locale: locale,
                arguments: candidate.version.displayName
            )
        case .downloading:
            return AppLanguage.localized("settings.update.downloading", locale: locale)
        case .installing:
            return AppLanguage.localized("settings.update.installing", locale: locale)
        case .failed:
            return AppLanguage.localized("settings.update.failed", locale: locale)
        }
    }

    func buttonTitle(locale: Locale) -> String {
        switch status {
        case .available:
            return AppLanguage.localized("settings.update.download", locale: locale)
        case .checking, .downloading, .installing:
            return AppLanguage.localized("settings.update.inProgress", locale: locale)
        case .failed:
            return AppLanguage.localized("settings.update.retry", locale: locale)
        case .idle, .upToDate:
            return AppLanguage.localized("settings.update.check", locale: locale)
        }
    }

    func activate() {
        if case .available = status {
            downloadLatest()
        } else {
            checkNow()
        }
    }

    func checkNow() {
        guard operation == nil else { return }
        status = .checking
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.service.check(currentVersion: self.currentVersion)
                self.apply(result)
            } catch {
                self.status = .failed
            }
            self.operation = nil
        }
    }

    private func downloadLatest() {
        guard case .available(let candidate) = status,
              operation == nil else { return }
        status = .downloading
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                let prepared = try await self.installer.prepare(
                    candidate: candidate,
                    currentBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.aisen.aiusagemeter",
                    currentAppURL: Bundle.main.bundleURL
                )
                self.status = .installing
                try self.installer.scheduleReplacement(
                    preparedUpdate: prepared,
                    currentAppURL: Bundle.main.bundleURL
                )
                self.operation = nil
                NSApplication.shared.terminate(nil)
            } catch {
                self.status = .failed
                self.operation = nil
                _ = NSWorkspace.shared.open(candidate.releaseURL)
            }
        }
    }

    private func apply(_ result: AppUpdateResult) {
        lastCheckDate = Date()
        defaults.set(lastCheckDate, forKey: Self.lastCheckKey)
        if let candidate = result.candidate {
            status = .available(candidate)
            if let data = try? JSONEncoder().encode(candidate) {
                defaults.set(data, forKey: Self.candidateKey)
            }
        } else {
            status = .upToDate
            defaults.removeObject(forKey: Self.candidateKey)
        }
    }

    private func restoreSavedState() {
        lastCheckDate = defaults.object(forKey: Self.lastCheckKey) as? Date
        guard let lastCheckDate,
              Date().timeIntervalSince(lastCheckDate) < Self.checkInterval,
              let data = defaults.data(forKey: Self.candidateKey),
              let candidate = try? JSONDecoder().decode(AppUpdateCandidate.self, from: data),
              candidate.version > currentVersion else { return }
        status = .available(candidate)
    }

    private func startScheduler() {
        let elapsed = lastCheckDate.map { Date().timeIntervalSince($0) } ?? Self.checkInterval
        let initialDelay = max(0, Self.checkInterval - elapsed)
        scheduler = Task { [weak self] in
            if initialDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            }
            while !Task.isCancelled {
                self?.checkNow()
                try? await Task.sleep(nanoseconds: UInt64(Self.checkInterval * 1_000_000_000))
            }
        }
    }
}
