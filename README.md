# Agent Quota Bar

macOS 菜单栏工具，快速查看 AI 编程工具的订阅额度使用情况。

## 功能

- **Cursor Pro**: 自动读取本地登录态，显示当前账期剩余额度
  - 综合已用百分比
  - Auto / Composer 用量
  - 指定模型 API 用量
  - 额外付费额度
  - 账期时间范围
- **Codex Pro**: 手动录入剩余额度（MVP 阶段）
- 每 15 分钟自动刷新（可在设置中调整）
- 失败时显示上次缓存数据
- 支持手动输入 Cursor Token (Keychain 安全存储)

## 菜单栏展示

```
⬢ Cursor 89% · Codex --
```

圆点颜色: 🟢 正常 / 🟠 过半 / 🔴 超80% / 🟡 错误 / ⚪ 未连接

## 系统要求

- macOS 13.0 (Ventura) 或更高
- Xcode 15.0+ (开发构建)
- Cursor IDE 已安装并登录（用于自动 Token 发现）

## 构建

```bash
open AgentQuotaBar.xcodeproj
# Xcode 中 Cmd+R 运行
```

## 技术栈

- Swift 6 + SwiftUI `MenuBarExtra`
- SQLite3 (读取 Cursor 本地 state 数据库)
- Security Framework (Keychain 存储)
- URLSession (API 请求)
- **零第三方依赖**

## 数据安全

- Token 仅保存在本机 Keychain
- 不上传任何凭据到服务器
- 所有 API 请求直接发送至 cursor.com

## TODO

- [ ] Codex 自动接入 (调研 ChatGPT 桌面应用本地数据源)
- [ ] WidgetKit 桌面小组件
- [ ] 支持更多 AI 编程工具

## License

Private project.
