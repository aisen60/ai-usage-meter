# Agent Quota Bar 会话总结

日期：2026-07-18  
项目目录：`/Users/aisen/Desktop/aisen/agent-quota-bar`  
GitHub 仓库：`https://github.com/aisen60/agent-quota-bar`  
仓库可见性：Private  

## 你想做什么

你想做一个简单的 macOS 工具，用来快速查看 AI 编程工具订阅额度的剩余情况。

当前目标主要覆盖两个套餐：

- Cursor Pro：希望自动读取当前账期剩余额度、用量百分比、Auto / Composer 用量、指定模型 API 用量等。
- Codex Pro：希望也能显示套餐额度或剩余使用情况，但需要进一步确认是否存在稳定、合规、可自动化的数据来源。

你考虑过两种展示形态：

- macOS 菜单栏显示。
- macOS 桌面小组件显示。

我的建议是第一版先做 macOS 菜单栏 App，再把 WidgetKit 小组件作为第二阶段展示层。原因是菜单栏 App 更适合处理登录态、刷新、失败提示、设置、Cookie 过期等问题；小组件更适合只读取本地缓存并展示结果。

## 问题和回答记录

### 1. 你问：我了解 Cursor 吗？

我回答：了解。Cursor 是基于 VS Code 体验的 AI 编程工具，核心能力包括 Chat、Composer、Agent、代码补全、基于代码库上下文的问答和编辑。后续讨论集中在 Cursor 订阅用量和内部 dashboard API。

### 2. 你问：Cursor 官方有没有 API，可以获取当前账号订阅额度还有多少？

我回答：Cursor 有官方 Admin API，但它主要面向 Team / Enterprise 管理员，不是个人 Pro 账号的公开用量 API。

官方 Admin API 能查团队成员、每日用量、spend、filtered usage events 等，但不等价于“个人账号当前 Pro 剩余额度 API”。

对于个人 Pro 账号，实际可行路线主要是读取 Cursor dashboard 使用的私有接口。这种方式技术上可行，但不稳定、不受官方支持，依赖登录态 Cookie 或 session token。

### 3. 你问：`get-current-period-usage`、`get-aggregated-usage-events` 这两个 API 是干嘛的？

我回答：

- `get-current-period-usage`：更像当前账期的额度摘要接口，返回账期开始/结束时间、总用量百分比、Auto 模型用量、指定模型 API 用量、spend limit 等。
- `get-aggregated-usage-events`：更像用量事件聚合接口，用于按模型、token、费用等维度做分析，不是最适合直接展示“剩余额度”的接口。

结论是：如果目标是显示当前剩余额度，优先用 `get-current-period-usage`。

### 4. 你贴了一段 `get-current-period-usage` 的返回数据

你贴出的关键字段包括：

```json
{
  "billingCycleStart": "1784207779000",
  "billingCycleEnd": "1786886179000",
  "planUsage": {
    "totalSpend": 3622,
    "includedSpend": 2000,
    "bonusSpend": 1622,
    "limit": 2000,
    "remainingBonus": false,
    "autoPercentUsed": 12.073333333333332,
    "apiPercentUsed": 0,
    "totalPercentUsed": 10.498550724637681
  },
  "spendLimitUsage": {
    "individualLimit": 600,
    "individualRemaining": 600,
    "limitType": "user"
  },
  "displayMessage": "You've used 77% of your included usage"
}
```

我解释了几个重点：

- `billingCycleStart` / `billingCycleEnd` 是毫秒时间戳。
- 对应北京时间大约是：
  - 开始：2026-07-16 21:16:19
  - 结束：2026-08-16 21:16:19
- `autoPercentUsed` 表示 Auto / Composer 一类模型池的使用百分比。
- `apiPercentUsed` 表示指定模型 API 池的使用百分比。
- `totalPercentUsed` 更适合作为整体剩余展示依据。
- `totalSpend`、`includedSpend`、`bonusSpend` 看起来像以美分为单位，但不能简单用 `limit - totalSpend` 算剩余额度，因为 Cursor 的 bonus 和 auto 池可能是动态的。
- `displayMessage` 里的 `77%` 和结构化字段存在不一致，应优先相信结构化字段，但要保留接口语义不稳定的判断。

我建议 UI 展示为：

```text
本期综合额度：已用 10.5%，剩余约 89.5%
Auto / Composer：已用 12.1%，剩余约 87.9%
指定 API 模型：已用 0%，剩余 100%
额外付费额度：$0 / $6
```

### 5. 你问：能不能通过爬虫或调用接口，在 macOS 做小组件？

我回答：可以做，但应该定位成本地自用工具，不建议做公开 SaaS。

可行架构是：

```text
macOS 菜单栏 App / 后台 Agent
        |
        | 定时请求
        v
https://cursor.com/api/dashboard/get-current-period-usage
        |
        | 解析 JSON
        v
App Group / 本地缓存
        |
        v
WidgetKit 小组件展示
```

我建议：

- 第一版做菜单栏 App。
- 用 Keychain 保存 Cookie / token。
- 每 30 到 60 分钟刷新一次。
- WidgetKit 只展示本地缓存。
- 请求失败时显示上次更新时间和缓存数据。

### 6. 你问：GitHub 上有没有类似开源工具？

我搜索并总结了几类相关项目：

- `cursor-usage`：个人 CLI，读取 Cursor 本地登录态，调用 Cursor dashboard 私有 API，支持 JSON、CSV、当前账期、用量统计等。
- `lixwen/cursor-usage-monitor`：Cursor / VS Code 状态栏插件，自动读取 Cursor 本地 SQLite 数据库中的 token 并展示用量。
- `bitbrain/cursor-usage-wizard`：更重的 Cursor 用量增强插件，支持状态栏、侧边栏、conversation 花费追踪等。
- `Cursor AI Usage Tracker`：偏 Enterprise / team 用量面板。
- `ofershap/cursor-usage`、`ofershap/cursor-usage-tracker`：偏团队/企业成本监控，走 Cursor Admin API 或 Enterprise 相关能力。

我的建议是优先参考：

1. `cursor-usage`：适合参考数据采集逻辑。
2. `lixwen/cursor-usage-monitor`：适合参考 Cursor 本地 token 读取和状态栏展示。

### 7. 你说：想同时显示 Cursor Pro 和 Codex Pro 套餐额度，问我觉得菜单栏还是小组件更好

我回答：建议第一版先做菜单栏 App。

原因：

- Cursor 数据源相对明确，可以自动读取。
- Codex Pro 目前没有明确的个人用量公开 API。
- OpenAI / Codex 的用量页面适合人工查看，但做自动化读取要谨慎。
- 菜单栏 App 可以先支持 Cursor 自动刷新、Codex 手动录入/半自动展示，后续再研究 Codex 自动化。

我建议的 MVP：

- 菜单栏 App 必做。
- Cursor 自动刷新，每 30 到 60 分钟一次。
- Codex 第一版显示手动录入或手动刷新状态，并提供一键打开 Codex Usage 页面。
- 本地缓存两边数据。
- 后续再加 WidgetKit 小组件。

### 8. 你问：项目取什么名字比较好？

我建议叫 `QuotaBar`，因为它简洁表达“额度 + 菜单栏”，也不绑定 Cursor 或 Codex，未来支持更多 AI 工具也合理。

备选名包括：

- `QuotaBar`
- `TokenBar`
- `UsageBar`
- `LimitLens`
- `QuotaPeek`
- `ModelMeter`
- `AI Allowance`
- `SubMeter`

### 9. 你问：Git 仓库名用 `agentQuotaBar` 还是 `agent-quota-bar`

我建议用 `agent-quota-bar`。

原因：

- GitHub 仓库名更常用 kebab-case。
- URL 可读性更好。
- 将来做 CLI 命令也自然是 `agent-quota-bar`。
- App 展示名和 Swift module 可以继续用 PascalCase。

建议命名：

```text
Repo: agent-quota-bar
App display name: Agent Quota Bar
Swift module / bundle name: AgentQuotaBar
CLI command: agent-quota-bar
```

### 10. 你让我创建私有 GitHub 仓库

你的要求：

- 仓库名：`agent-quota-bar`
- 必须是 private。
- 必须创建在你的个人 GitHub 账号下，不能创建到组织里。
- 本地路径：`/Users/aisen/Desktop/aisen/agent-quota-bar`

过程中发现：

- 一开始 `gh auth status` 显示账号 `aisen60` 的 token 失效。
- 你重新登录后，我通过 `gh api user --jq .login` 确认当前登录账号是 `aisen60`。
- 为避免落到组织里，我没有用裸仓库名，而是显式创建：

```bash
gh repo create aisen60/agent-quota-bar --private
```

然后克隆到：

```bash
/Users/aisen/Desktop/aisen/agent-quota-bar
```

最终校验结果：

```text
Repo: aisen60/agent-quota-bar
Visibility: PRIVATE
URL: https://github.com/aisen60/agent-quota-bar
Local path: /Users/aisen/Desktop/aisen/agent-quota-bar
Remote: https://github.com/aisen60/agent-quota-bar.git
```

### 11. 你让我“交给我完成这个项目”

我开始准备实现 macOS 菜单栏 MVP，并做了初步本地检查：

- 当前目录：`/Users/aisen/Desktop/aisen/agent-quota-bar`
- 当前仓库为空，尚无提交。
- `swift --version` 可用，版本为 Apple Swift 6.3.3。

随后你中断了实现请求，改为要求先写这份会话总结。

## 参考资料

本次讨论中参考或提到的资料包括：

- Cursor Admin API 官方文档：`https://docs.cursor.com/en/account/teams/admin-api`
- Cursor 社区关于 Usage API / CLI 的讨论：`https://forum.cursor.com/t/usage-api-cli-command/160967`
- Cursor 社区关于 `get-current-period-usage` 返回示例的讨论：`https://forum.cursor.com/t/usage-bar-remains-empty-at-0/165153`
- Cursor 社区关于 `get-aggregated-usage-events` 的用量聚合示例讨论：`https://forum.cursor.com/t/update-the-docs-and-dashboard-to-tell-us-exactly-whatbwe-ae-paying-for/152538/6`
- OpenAI Help：Using Codex with your ChatGPT plan：`https://help.openai.com/zh-hans-cn/articles/11369540-using-codex-with-your-chatgpt-plan`
- OpenAI Help：Using Credits for Flexible Usage：`https://help.openai.com/en/articles/12642688`
- OpenAI Help：About ChatGPT Pro tiers：`https://help.openai.com/en/articles/9793128-ab-targets-pro-chatg`
- `cursor-usage`：`https://pypi.org/project/cursor-usage/`
- `lixwen/cursor-usage-monitor`：`https://github.com/lixwen/cursor-usage-monitor`
- `bitbrain/cursor-usage-wizard`：`https://github.com/bitbrain/cursor-usage-wizard`
- `ofershap/cursor-usage`：`https://github.com/ofershap/cursor-usage`
- `ofershap/cursor-usage-tracker`：`https://github.com/ofershap/cursor-usage-tracker`

## 当前项目建议范围

建议第一版实现如下：

- macOS 菜单栏 App。
- SwiftUI + AppKit `NSStatusItem`。
- Cursor 数据源自动读取。
- 通过 Cursor 本地登录态或手动 Cookie 调用 `get-current-period-usage`。
- Keychain 保存敏感凭据。
- 本地 JSON / UserDefaults 缓存最近一次结果。
- 菜单栏标题展示两个百分比，例如 `Cursor 89% · Codex 65%`。
- 菜单点击后展示：
  - Cursor 剩余百分比。
  - Cursor Auto / Composer 剩余百分比。
  - Cursor 指定模型 API 剩余百分比。
  - Cursor 账期。
  - Codex 手动录入的剩余额度或状态。
  - 上次刷新时间。
  - 手动刷新按钮。
  - 打开 Cursor / Codex 用量页面。

## 风险和边界

Cursor 部分：

- 个人 Pro 没有稳定官方用量 API。
- `get-current-period-usage` 是私有 dashboard API。
- 字段、鉴权方式、接口路径可能随 Cursor 更新而变化。
- 适合本地自用，不适合做公开服务。

Codex 部分：

- 目前没有确认到个人 Codex Pro 可用的稳定公开额度 API。
- 自动抓取网页或内部接口有合规和稳定性风险。
- 第一版建议做手动/半自动展示，后续再研究是否存在可靠本地数据源。

安全要求：

- Cookie / session token 只保存在本机 Keychain。
- 不上传任何凭据到服务器。
- 默认低频刷新，避免高频请求私有接口。

## 当前仓库状态

创建本文档时，仓库状态是：

```text
No commits yet on main
Remote: https://github.com/aisen60/agent-quota-bar.git
```

本文档是项目中的第一个普通文件。
