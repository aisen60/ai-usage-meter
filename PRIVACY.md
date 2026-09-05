# Privacy

[中文说明](PRIVACY.zh-CN.md)

AI Usage Meter reads Cursor and ChatGPT usage locally. It does not operate a proxy server, include telemetry or analytics, or send data to the developer or any other third party.

## What the app reads locally

| Data | Source | Purpose |
| --- | --- | --- |
| Cursor session | Cursor's local state database (read-only) | Request current usage from Cursor's billing service |
| Manual Cursor token | Entered by the user in the app | Fallback credential when the local session is unavailable |
| ChatGPT quota | The local `codex app-server` and its existing sign-in session | Read the 5-hour and 1-week quota windows |
| Usage data | The two services above | Display usage in the menu bar and popover |

AI Usage Meter does not read, save, or upload a ChatGPT token.

## Where data is stored

- **Manual Cursor token:** Stored only in macOS Keychain under the `com.aisen.aiusagemeter` service. It is not written to an ordinary file.
- **Usage cache:** Stored locally under `~/Library/Application Support/AIUsageMeter`. It contains usage values and timestamps, not credentials.
- **App settings:** Menu bar display preferences, language, and update-check results are stored in macOS UserDefaults. They contain display preferences, a language identifier, version data, timestamps, and public download URLs, not account information.

## Network requests

- Cursor usage requests go directly to Cursor's official service without an intermediary.
- ChatGPT quota is read through the local `codex app-server`. The child process is closed after the request finishes, times out, or fails.
- Update checks request public repository and release metadata from GitHub's Releases and Tags APIs. The requests contain only the public repository URL and a version User-Agent; they do not contain credentials, tokens, cookies, or usage data.

The app makes no other network connections.

## What update checks save

To reuse a result during the five-hour check interval, the app may save the last check time, available version, Release page URL, archive URL, and SHA-256 URL in local preferences. This metadata contains no sensitive credentials and can be removed by deleting the app's preferences.

## Logging

App logs record only component detection, success, timeout, and error types. They do not contain tokens, cookies, account identifiers, authorization headers, or complete service responses.

## Removing all data

Deleting the app does not automatically remove the following local data. To remove it completely:

1. **Keychain credentials:** Open Keychain Access, search for `com.aisen.aiusagemeter`, and delete the matching item.
2. **Usage cache:** Delete `~/Library/Application Support/AIUsageMeter`.
3. **App preferences:** Delete the app domain with `defaults delete com.aisen.aiusagemeter` in Terminal.

For a shorter product overview, see [README.md](README.md).
