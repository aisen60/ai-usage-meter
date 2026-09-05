# 隐私说明

[English Privacy Policy](PRIVACY.md)

AI Usage Meter 只在本机读取 Cursor 和 ChatGPT 的用量。应用不运营任何中转服务器，不包含遥测、统计或分析功能，也不会把任何数据发送给开发者或第三方。

## 应用在本机读取什么

| 数据 | 来源 | 用途 |
| --- | --- | --- |
| Cursor 登录态 | Cursor 本地状态数据库（只读） | 调用 Cursor 账期接口查询用量 |
| Cursor 手动 Token | 用户在应用内手动提供 | 本地登录态失效时的备用凭据 |
| ChatGPT 额度 | 本机 `codex app-server` 及其现有登录会话 | 读取 5 小时与 1 周额度窗口 |
| 用量数据 | 上述两个服务 | 在菜单栏和弹层中展示用量 |

AI Usage Meter 不读取、保存或上传 ChatGPT Token。

## 数据保存在哪里

- **Cursor 手动 Token**：仅保存在 macOS Keychain，service 固定为 `com.aisen.aiusagemeter`，不落盘到任何普通文件。
- **用量缓存**：仅保存在当前 macOS 用户的本地应用数据目录（`~/Library/Application Support/AIUsageMeter`），内容为用量数值和获取时间，不含凭据。
- **应用设置**：菜单栏显示项目的开关状态、界面语言和更新检查结果保存在 macOS 用户偏好设置（UserDefaults）中，仅含显示偏好、语言标识、版本号、时间和公开下载地址，不含任何账号信息。

## 网络请求发给谁

- Cursor 用量请求直接发送到 Cursor 官方服务，不经过任何中间方。
- ChatGPT 额度通过本机 `codex app-server` 读取，子进程在读取结束、超时或失败后都会被关闭。
- 版本检查会向 GitHub 的公开 Releases 和 Tags API 请求仓库版本与公开资源信息。请求只包含公开仓库地址和版本 User-Agent，不包含账户凭据、Token、Cookie 或用量数据。

除上述三类请求外，应用不发起任何其他网络连接。

## 更新检查保存什么

应用可以在本地偏好设置中保存上次检查时间、可用版本、Release 页面地址以及安装包和 SHA-256 文件地址，用于五小时检查间隔内复用结果。这些信息不包含敏感凭据，用户也可以通过删除应用偏好设置一并移除。

## 日志记录什么

应用日志只记录组件检测、成功、超时和错误类型，不包含 Token、Cookie、账号标识、授权请求头或完整服务响应。

## 如何彻底删除数据

删除应用本身不会自动清除以下残留，如需彻底移除：

1. **Keychain 凭据**：打开“钥匙串访问”，搜索 `com.aisen.aiusagemeter`，删除对应项目。
2. **用量缓存**：删除 `~/Library/Application Support/AIUsageMeter` 目录。
3. **应用偏好设置**：在终端执行 `defaults delete com.aisen.aiusagemeter`，删除应用偏好设置。

更简要的产品说明见 [README.zh-CN.md](README.zh-CN.md)。
