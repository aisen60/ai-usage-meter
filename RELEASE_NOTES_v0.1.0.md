# Agent Quota Bar v0.1.0

首个可安装的私有发行版。

## 主要功能

- 同时显示 Cursor Composer 已用额度与 Codex 本周剩余额度
- 自动读取本机 Cursor、ChatGPT/Codex 登录态和动态套餐名称
- 每 15 分钟自动刷新，Release 首次运行自动添加登录项
- Universal App，同时支持 Apple Silicon 和 Intel Mac

## 安装提示

本版本采用 ad-hoc 签名，未经过 Apple 公证。解压后请将应用拖入 `/Applications`，首次启动可在 Finder 中右键选择“打开”，或在“系统设置 → 隐私与安全性”中确认。

更新时先退出旧版，再用新版覆盖 `/Applications/AgentQuotaBar.app`。相同 Bundle ID 会保留本地数据与登录项配置。

SHA-256 校验：下载同名 `.sha256` 文件后运行 `shasum -a 256 -c AgentQuotaBar-0.1.0.zip.sha256`。
