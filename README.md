# Agent Quota Bar

Agent Quota Bar 是一个 macOS 菜单栏工具，用来同时查看 Cursor 和 Codex 的订阅额度。

菜单栏蓝色胶囊显示 Cursor Composer **已用百分比**，绿色胶囊显示 Codex **本周剩余百分比**。服务未连接时统一显示灰色 `0%`。

## v0.1.0 功能

- 自动识别 Cursor 本地登录态、动态套餐名称、Composer 与 API 已用额度
- 复用本机 ChatGPT/Codex 登录态，显示动态套餐名称、周剩余额度和重置日期
- 每 15 分钟自动刷新，也可从弹层底部手动刷新
- Release 版本首次启动时自动注册为登录项
- Cursor 凭据不可用时可继续显示本地缓存；Codex 读取失败时立即降级为灰色 `0%`
- 不引入第三方依赖，不上传 Token、Cookie、账号信息或用量响应

## 系统要求

- macOS 13 Ventura 或更高版本
- Cursor 桌面客户端已安装并登录
- ChatGPT/Codex 桌面应用或 Codex CLI 已安装并登录

两项服务彼此独立。只安装或登录其中一个时，另一个会显示灰色 `0%`。

## 安装

1. 从私有 GitHub Release 下载 `AgentQuotaBar-0.1.0.zip` 和 `.sha256` 文件。
2. 可选：运行 `shasum -a 256 -c AgentQuotaBar-0.1.0.zip.sha256` 校验文件。
3. 解压后将 `AgentQuotaBar.app` 拖入 `/Applications`。
4. 首次启动时，在 Finder 中右键应用并选择“打开”。若仍被拦截，请前往“系统设置 → 隐私与安全性”确认打开。

v0.1.0 使用 ad-hoc 签名，未进行 Apple Developer ID 签名和公证，因此首次启动出现系统安全提示属于预期行为。

### 开机启动

Release 版本首次运行时会自动添加登录项。可在“系统设置 → 通用 → 登录项”中关闭或重新开启 Agent Quota Bar，无需在应用内设置。

### 手动更新

1. 退出菜单栏中的旧版本。
2. 下载并解压新版。
3. 用新版覆盖 `/Applications/AgentQuotaBar.app`。
4. 重新启动应用。

Bundle ID 和 Keychain service 保持不变，因此覆盖安装不会主动清除本地缓存、Cursor 手动凭据或登录项配置。

## 本地开发

```bash
open AgentQuotaBar.xcodeproj
```

需要 Xcode 15 或更高版本。命令行运行测试：

```bash
xcodebuild test \
  -project AgentQuotaBar.xcodeproj \
  -scheme AgentQuotaBar \
  -destination 'platform=macOS'
```

生成 v0.1.0 Universal 发行包：

```bash
./scripts/build-release.sh
```

产物位于 `dist/`，包含 Universal `arm64 + x86_64` ZIP 和 SHA-256 校验文件。

## 数据来源与兼容性

- Cursor：只读访问 Cursor 本地状态数据库，并向 Cursor 当前账期接口请求当前账号用量。
- Codex：启动短生命周期的本机 `codex app-server`，使用当前 Codex 登录会话读取限额；读取结束、超时或失败后都会关闭子进程。
- 日志：只记录组件检测、成功、超时和错误类型，不记录 Token、Cookie、账号信息或完整响应。

Cursor 用量接口和 Codex `app-server` 都不是面向此应用承诺稳定的公共集成接口，可能随客户端升级发生变化。届时需要发布兼容更新。

更完整的说明见 [PRIVACY.md](PRIVACY.md)。

## License

Private project. All rights reserved.
