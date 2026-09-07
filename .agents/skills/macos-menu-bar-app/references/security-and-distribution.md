# Security and Distribution

## Credentials and Local Data

- Store tokens, refresh credentials, and reusable authentication material in Keychain.
- Select the narrowest practical accessibility class. Changing it affects locked-device and background behavior, so test the intended lifecycle.
- Keep a stable Keychain service and account naming scheme across upgrades.
- Do not move credentials into `UserDefaults`, plist files, caches, environment snapshots, or test fixtures.
- When reading another application's local data, use the smallest read-only access needed and handle missing, locked, corrupt, or changed schemas safely.

## Logging and Errors

- Log coarse lifecycle and error categories, not response bodies or credential-derived values.
- Mark dynamic fields private unless they are intentionally public and non-sensitive.
- Convert upstream errors into safe user-facing messages; raw errors can contain paths, command output, or server content.
- Do not place secrets on process command lines, where they may be visible to other local tools.

## Sandbox and Entitlements

- Inspect current entitlements before recommending App Sandbox.
- Sandbox adoption can block reads from another application's files, arbitrary executable discovery, subprocess launch, and direct file-system probing.
- Treat enabling sandboxing as a product and integration migration, not a checkbox hardening change.
- Add only the entitlements required by implemented behavior, and verify both Testing and distributed builds.

## Login Items

- Prefer current ServiceManagement APIs supported by the deployment target.
- Keep registration idempotent and avoid overriding a user's explicit disabled choice.
- Verify registration behavior from the distributed application location; development builds and ad-hoc locations may behave differently.
- Bundle identifier and signing changes can affect login-item identity and upgrade behavior.

## Signing and Notarization

- Distinguish ad-hoc signing, Apple Development signing, Developer ID signing, and Mac App Store signing; they prove different things.
- Notarization requires an appropriate Developer ID workflow and hardened runtime. An ad-hoc signature is not notarization-ready evidence.
- Verify the final packaged artifact after archiving or zipping, not only the intermediate build product.
- Check bundle identifier, version, build number, architectures, signature, entitlements, and archive integrity.

## Updates

- Do not add Sparkle or another update framework without explicit product approval.
- An updater introduces signing keys, feed integrity, release hosting, rollback, and privileged file-replacement considerations.
- For manual updates, keep bundle and Keychain identifiers stable so replacement installs retain intended local state.

## Release Proof

Static tests cannot prove:

- Gatekeeper behavior on a clean Mac.
- Login-item behavior after reboot.
- Keychain access after replacing the application.
- Compatibility with newly released Cursor or Codex clients.
- VoiceOver and menu-bar interaction in the shipped package.

State these boundaries in the handoff unless the user authorizes and provides the environment for runtime verification.
