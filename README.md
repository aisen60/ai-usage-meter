# AI Usage Meter

[English](README.en.md)

AI Usage Meter 是一款以本地处理为核心的 macOS 菜单栏工具，用于查看 Cursor 和 ChatGPT 的用量。

无需打开 Cursor 或 ChatGPT，即可在菜单栏查看最重要的 AI 额度信息。AI Usage Meter 在本机读取支持的用量数据，并以紧凑的菜单栏面板呈现。

## 功能

- 查看 Cursor Models、Other Models 和 On Demand 用量。
- 查看 ChatGPT 5 小时与 1 周剩余额度窗口。
- 自定义菜单栏中显示哪些用量项目。
- 在英文和简体中文之间切换界面语言。
- 登录后自动启动应用。
- 从 GitHub Releases 检查更新，并使用 SHA-256 校验安装包。
- Cursor 与 ChatGPT 集成彼此独立。
- 凭据保存在 macOS 钥匙串，用量数据保存在本机。

## 下载

从 [GitHub Releases](https://github.com/aisen60/ai-usage-meter/releases) 下载最新版本。AI Usage Meter 需要 macOS 13 Ventura 或更高版本。如需查看 Cursor 用量，请安装 Cursor；如需查看 ChatGPT 额度，请安装 ChatGPT macOS 应用或 Codex CLI。两个集成可以独立使用。

在 macOS 上下载 ZIP 文件，解压后将 `AI Usage Meter.app` 移动到 `/Applications`。如果首次启动时 macOS 显示安全提示，请在 Finder 中右键点击应用，选择“打开”，然后在“系统设置 → 隐私与安全性”中确认一次。

当前发行包使用 ad-hoc 签名，未使用 Developer ID 签名或公证。首次启动出现安全提示属于预期行为。

## 隐私

AI Usage Meter 不会向开发者发送 Token、Cookie、账号标识或用量响应。Cursor 和 ChatGPT 用量只在本机读取，更新检查只请求 GitHub 的公开仓库元数据。

完整的数据来源、本地存储、网络请求和删除说明见 [PRIVACY.zh-CN.md](PRIVACY.zh-CN.md)。英文用户可以阅读 [PRIVACY.md](PRIVACY.md)。

## 本地开发

当前源码以 macOS 13 为目标，使用 SwiftUI，运行时不依赖第三方库。使用 Xcode 打开工程：

```bash
open AIUsageMeter.xcodeproj
```

运行测试：

```bash
xcodebuild test \
  -project AIUsageMeter.xcodeproj \
  -scheme AIUsageMeter \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AIUsageMeter-DerivedData
```

构建 Universal 发布包：

```bash
./scripts/build-release.sh
```

脚本会在 `dist/` 中生成包含 `arm64 + x86_64` 的 ZIP 文件及其 SHA-256 校验文件。

## 发布

发布前，在一个 PR 中更新 Xcode 的 `MARKETING_VERSION`、构建号与 `CHANGELOG.md`，合并到 `main` 后再从干净且已同步的 `main` 执行：

```bash
./scripts/release.sh v0.3.2
```

该命令会手动触发 GitHub Actions。工作流校验版本和更新日志、运行完整测试、构建 Universal ZIP 与 SHA-256 文件；全部成功后创建同名 Git tag 和公开 GitHub Release。Release 正文取自该版本的 `CHANGELOG.md` 条目，并自动追加安装提示。

仓库需要允许 GitHub Actions 的 `GITHUB_TOKEN` 使用 `contents: write` 权限，以便创建 tag 和 Release；发布不需要向仓库保存证书或其他密钥。当前自动化仍使用 ad-hoc 签名，未包含 Developer ID 签名或 Apple 公证。

## 关于项目

- [发行版本](https://github.com/aisen60/ai-usage-meter/releases)
- [更新日志](CHANGELOG.md)
- [问题反馈](https://github.com/aisen60/ai-usage-meter/issues)
- [MIT License](LICENSE)

MIT © 2026 aisen60
