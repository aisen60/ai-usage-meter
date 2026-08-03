# 隐私说明

Agent Quota Bar 只在本机读取 Cursor 和 Codex 的用量。应用不运营任何中转服务器，不包含遥测、统计或分析功能，也不会把任何数据发送给开发者或第三方。

## 应用在本机读取什么

| 数据 | 来源 | 用途 |
| --- | --- | --- |
| Cursor 登录态 | Cursor 本地状态数据库（只读） | 调用 Cursor 账期接口查询用量 |
| Cursor 手动 Token | 用户在应用内手动提供 | 自动登录态失效时的备用凭据 |
| Codex 用量 | 本机 `codex app-server` 复用其现有登录会话 | 读取周剩余额度 |
| 用量数据 | 上述两个服务 | 菜单栏与弹层展示 |

Agent Quota Bar 不读取、保存或上传 ChatGPT Token。

## 数据保存在哪里

- **Cursor 手动 Token**：仅保存在 macOS Keychain，service 固定为 `com.agentquotabar.app`，不落盘到任何普通文件。
- **用量缓存**：仅保存在当前 macOS 用户的本地应用数据目录（`~/Library/Application Support/AgentQuotaBar`），内容为用量数值和获取时间，不含凭据。
- **显示设置**：菜单栏显示项目的开关状态保存在 macOS 用户偏好设置（UserDefaults）中，仅含三个布尔值，不含任何账号信息。

## 网络请求发给谁

- Cursor 用量请求直接发送到 Cursor 官方服务，不经过任何中间方。
- Codex 用量通过本机 `codex app-server` 在本机进程间完成，子进程在读取结束、超时或失败后都会被关闭。
- 除上述两类请求外，应用不发起任何其他网络连接。

## 日志记录什么

应用日志只记录组件检测、成功、超时和错误类型，不包含 Token、Cookie、账号标识、授权请求头或完整服务响应。

## 如何彻底删除数据

删除应用本身不会自动清除以下残留，如需彻底移除：

1. **Keychain 凭据**：打开“钥匙串访问”，搜索 `com.agentquotabar.app`，删除对应项目。
2. **用量缓存**：删除 `~/Library/Application Support/AgentQuotaBar` 目录。
3. **显示设置**：随用户偏好设置一并删除应用域即可（终端执行 `defaults delete com.agentquotabar.app`）。

更简要的产品说明见 [README.md](README.md)。
