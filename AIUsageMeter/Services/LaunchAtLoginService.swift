import ServiceManagement

enum LaunchAtLoginService {
    private static let registrationCompletedKey = "launchAtLoginRegistrationCompleted"

    static func registerIfNeeded() {
#if DEBUG
        AppLog.app.debug("Debug build skips launch-at-login registration")
#else
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: registrationCompletedKey) else {
            AppLog.app.debug("First-launch login-item setup already completed")
            return
        }

        let service = SMAppService.mainApp
        guard service.status == .notRegistered else {
            defaults.set(true, forKey: registrationCompletedKey)
            AppLog.app.info("Launch-at-login already configured")
            return
        }

        do {
            try service.register()
            defaults.set(true, forKey: registrationCompletedKey)
            AppLog.app.info("Launch-at-login registered")
        } catch {
            AppLog.app.error(
                "Launch-at-login registration failed: \(error.localizedDescription, privacy: .public)"
            )
        }
#endif
    }
}
