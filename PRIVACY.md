# Privacy

Agent Quota Bar 在本机读取 Cursor 和 Codex 的用量，不运营中转服务器，也不提供遥测或分析功能。

## 本机数据

- Cursor 自动登录态来自 Cursor 本地状态数据库。
- 用户手动提供的 Cursor Token 仅保存在 macOS Keychain，service 固定为 `com.agentquotabar.app`。
- Codex 用量由本机 Codex CLI 使用其现有登录会话读取；Agent Quota Bar 不读取、保存或上传 ChatGPT Token。
- 用量缓存仅保存在当前 macOS 用户的本地应用数据目录。

## 网络与日志

- Cursor 请求直接发送到 Cursor 服务。
- Codex 请求通过本机 `codex app-server` 完成。
- 应用日志不包含 Token、Cookie、账号信息或完整服务响应。

## 删除数据

删除应用不会自动删除 Keychain 中的 Cursor 手动凭据。若需要彻底移除，可在“钥匙串访问”中搜索 `com.agentquotabar.app` 并删除对应项目。
