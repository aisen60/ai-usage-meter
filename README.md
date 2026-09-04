# AI Usage Meter

AI Usage Meter 是一个 macOS 菜单栏工具，用来同时查看 Cursor 和 ChatGPT 的订阅额度。

菜单栏标签以「CC」前缀加最多五个彩色胶囊呈现：蓝色胶囊显示 Cursor Models **已用百分比**，灰色胶囊显示 Other Models **已用百分比**，紫色胶囊显示 On Demand **按量付费预算**，两个绿色胶囊分别显示 ChatGPT **5 小时**与 **1 周剩余百分比**。服务未连接时统一显示灰色 `0%`。

## v0.3.0 功能

- Cursor 新增可选 On Demand 项目：仅在存在有效个人按量付费上限时展示，显示美元金额与已用进度
- ChatGPT 同时展示 5 小时与 1 周两个剩余额度窗口；短周期显示重置时间，周周期显示重置日期
- 状态栏与设置页支持五个独立显示开关，至少保留一项；「CC」前缀固定显示
- 所有用户可见的 Codex 名称统一改为 ChatGPT
- 本地显示设置从 v0.2.0 自动迁移，新增项目默认开启

## v0.2.0 功能

- 新增设置页：弹层底部工具栏的齿轮入口进入，左上角返回
- 设置页内提供状态栏预览，调整开关时可实时看到菜单栏效果
- 可分别开关 Cursor Models、Other Models、本周剩余三个菜单栏胶囊；至少保留一项，「CC」前缀固定显示
- 显示设置本地持久化，默认全开，从 v0.1.0 升级无感知
- 底部工具栏改为三等分分段布局：设置 ｜ 刷新状态 ｜ 退出

## v0.1.0 功能

- 自动识别 Cursor 本地登录态、动态套餐名称、Composer 与 API 已用额度
- 复用本机 ChatGPT/Codex 登录态，显示动态套餐名称、周剩余额度和重置日期
- 每 15 分钟自动刷新，也可从弹层底部手动刷新
- Release 版本首次启动时自动注册为登录项
- Cursor 凭据不可用时可继续显示本地缓存；ChatGPT 读取失败时立即降级为灰色 `0%`
- 不引入第三方依赖，不上传 Token、Cookie、账号信息或用量响应

## 系统要求

- macOS 13 Ventura 或更高版本
- 如需查看 Cursor 用量，请安装并登录 Cursor 桌面客户端；未安装时应用会自动隐藏 Cursor 区域
- ChatGPT 桌面应用或 Codex CLI 已安装并登录

两项服务彼此独立。只安装或登录其中一个时，另一个会显示灰色 `0%`。

## 安装

1. 从 [GitHub Releases](https://github.com/aisen60/ai-usage-meter/releases) 下载 `AIUsageMeter-0.3.0.zip` 和 `.sha256` 文件。
2. 可选：运行 `shasum -a 256 -c AIUsageMeter-0.3.0.zip.sha256` 校验文件。
3. 解压后将 `AI Usage Meter.app` 拖入 `/Applications`。
4. 首次启动时，在 Finder 中右键应用并选择“打开”。若仍被拦截，请前往“系统设置 → 隐私与安全性”确认打开。

v0.3.0 使用 ad-hoc 签名，未进行 Apple Developer ID 签名和公证，因此首次启动出现系统安全提示属于预期行为。

### 开机启动

Release 版本首次运行时会自动添加登录项。可在“系统设置 → 通用 → 登录项”中关闭或重新开启 AI Usage Meter，无需在应用内设置。

### 手动更新

1. 退出菜单栏中的旧版本。
2. 下载并解压新版。
3. 用新版覆盖 `/Applications/AI Usage Meter.app`。
4. 重新启动应用。

Bundle ID 和 Keychain service 保持不变，因此覆盖安装不会主动清除本地缓存、Cursor 手动凭据或登录项配置。

## 本地开发

```bash
open AIUsageMeter.xcodeproj
```

需要 Xcode 15 或更高版本。命令行运行测试：

```bash
xcodebuild test \
  -project AIUsageMeter.xcodeproj \
  -scheme AIUsageMeter \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AIUsageMeter-DerivedData
```

生成 v0.3.0 Universal 发行包：

```bash
./scripts/build-release.sh
```

产物位于 `dist/`，包含 Universal `arm64 + x86_64` ZIP 和 SHA-256 校验文件。

## 数据来源与兼容性

- Cursor：只读访问 Cursor 本地状态数据库，并向 Cursor 当前账期接口请求当前账号用量与按量付费预算。
- ChatGPT：启动短生命周期的本机 `codex app-server`，使用当前 ChatGPT 登录会话读取 5 小时与 1 周两个限额窗口；读取结束、超时或失败后都会关闭子进程。
- 日志：只记录组件检测、成功、超时和错误类型，不记录 Token、Cookie、账号信息或完整响应。

Cursor 用量接口和 ChatGPT `app-server` 都不是面向此应用承诺稳定的公共集成接口，可能随客户端升级发生变化。届时需要发布兼容更新。

更完整的说明见 [PRIVACY.md](PRIVACY.md)。

## License

本项目采用 [MIT License](LICENSE) 开源。

Copyright © 2026 aisen60.
