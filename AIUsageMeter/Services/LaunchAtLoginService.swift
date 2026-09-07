import Combine
import Foundation
import ServiceManagement

/// 抹平 `SMAppService` 的系统状态，避免界面层依赖 ServiceManagement 细节。
enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case requiresInstallation
    case unavailable

    var isEnabled: Bool {
        self == .enabled
    }

    var needsSystemApproval: Bool {
        self == .requiresApproval
    }

    var canChange: Bool {
        switch self {
        case .requiresInstallation, .unavailable:
            return false
        case .enabled, .disabled, .requiresApproval:
            return true
        }
    }
}

/// 系统登录项的最小适配层，供设置状态与单元测试共同使用。
protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }

    func register() throws
    func unregister() throws
}

struct LaunchAtLoginService: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus {
        guard Self.isSupportedInstallation(at: Bundle.main.bundleURL) else {
            return .requiresInstallation
        }

        return Self.status(for: SMAppService.mainApp.status)
    }

    /// `.notFound` is the initial state before this app has ever registered
    /// with Service Management. It is still a valid, changeable off state.
    static func status(for serviceStatus: SMAppService.Status) -> LaunchAtLoginStatus {
        switch serviceStatus {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .disabled
        @unknown default:
            return .unavailable
        }
    }

    /// Login item registration must point to a stable installed application.
    /// Registering an app from Xcode's DerivedData, a temporary directory, or a
    /// mounted DMG can leave macOS pointing at a path that is not available at
    /// the next login.
    static func isSupportedInstallation(at appURL: URL) -> Bool {
        let appPath = appURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let systemApplicationsPath = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .standardizedFileURL
            .path
        let userApplicationsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
            .path

        return appPath.hasPrefix(systemApplicationsPath + "/") ||
            appPath.hasPrefix(userApplicationsPath + "/")
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// 设置页使用的状态层。系统注册状态是唯一真实来源，不额外持久化偏好。
@MainActor
final class LaunchAtLoginSettings: ObservableObject {
    static let loginItemsSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    )!

    @Published private(set) var status: LaunchAtLoginStatus
    @Published private(set) var didFailLastUpdate = false

    private let service: LaunchAtLoginControlling

    init(service: LaunchAtLoginControlling = LaunchAtLoginService()) {
        self.service = service
        status = service.status
    }

    var isEnabled: Bool {
        status.isEnabled
    }

    var needsSystemApproval: Bool {
        status.needsSystemApproval
    }

    var canChange: Bool {
        status.canChange
    }

    func refresh() {
        status = service.status
        didFailLastUpdate = false
    }

    func setEnabled(_ enabled: Bool) {
        didFailLastUpdate = false

        guard canChange else { return }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // 不记录底层错误，避免将系统路径或实现细节带入日志。
            AppLog.app.error("Launch-at-login update failed")
            didFailLastUpdate = true
        }

        status = service.status
        if enabled && status != .enabled && status != .requiresApproval {
            didFailLastUpdate = true
        }
    }
}
