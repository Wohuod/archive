---
name: local-backend-config
description: 在本机（Letta Code 本地后端）查看或修改我自己 / agent 的配置——模型、上下文阈值、压缩模式、名字。当 Wood 要我"改一下设置""调整压缩阈值""看看用了多少上下文""换个模型"时加载。
---

# 本地后端上的自我配置

Wood 的机器走的是 **local backend**，不是 Letta Cloud。`self-configuration` 那份 bundled 技能描述的 helper 脚本在这台机器上**跑不起来**——见下面第一条。

## 这台机器上没有 JS / Python 运行时

- `node` / `npx` / `bun` / `deno`：都没有（`npx` 直接 not recognized）
- `python`：Microsoft Store 的占位符，一跑就报 "Python was not found"
- `py`：没有
- `letta.cmd` 只是个 shim：`Letta.exe ...\letta.js`。`letta --help`、`letta usage`、`letta model ...` 这些 CLI 子命令能用

所以 `update-agent-settings.ts`、`show_config.py`、`update-compaction-prompt.ts` 一律不可用。**别浪费轮次去试**。

## 首选路径：直接打本地后端 HTTP API

环境变量已经就绪：`LETTA_BASE_URL=http://localhost:3849`、`LETTA_API_KEY`、`AGENT_ID`、`CONVERSATION_ID`。

```powershell
$h = @{ Authorization = "Bearer $env:LETTA_API_KEY"; "Content-Type" = "application/json" }

# 读：model、model_settings、system、tools
Invoke-RestMethod -Uri "$env:LETTA_BASE_URL/v1/agents/$env:AGENT_ID" -Headers $h -Method Get

# 写：model_settings 是"整体替换"语义 —— 先把现有对象读出来，改一个字段，再整个写回
$ms = (Invoke-RestMethod ... ).model_settings
$ms.context_window_limit = 200000
$body = @{ model_settings = $ms } | ConvertTo-Json -Depth 8
Invoke-RestMethod -Uri "$env:LETTA_BASE_URL/v1/agents/$env:AGENT_ID" -Headers $h -Method Patch -Body $body
```

要点：

- 配置挂在 `model_settings` 里：`context_window_limit`、`max_tokens`、`reasoning_effort`、`reasoning`
- **PATCH 会整体替换 `model_settings`**，漏字段就是删字段（尤其别把 `reasoning_effort: high` 弄丢——那是他明确要保留的）
- 干跑没有意义，但可以先 PATCH 一次"原值"验证通路
- 不存在的端点：`/openapi.json`、`/v1/conversations/{id}`、`/v1/agents/{id}/conversations` → 全部 404
- `llm_config.context_window` 是 legacy 投影（`model_endpoint` 是 `https://example.invalid/v1`），**改它没用**，以 `model_settings` 为准

## 备选路径：直接看存储目录

`D:\LettaWorkingPlace\lc-local-backend\`

- `agents\<base64url>.json` — agent 记录
- `conversations\<base64url>\` — `conversation.json` / `messages.jsonl` / `system-prompt.json`
- 目录名是 base64url：解出来是 `default:<agent-id>` 或 `conversation:local-conv-N`

**只读用途**（考古、确认某条对话到底存在哪、估算 token）。不要直接写文件——后端有内存态，会被覆盖或打架。

## 本机其他坑（人生导师 2026-10-07 补的）

- `Remove-Item -Force` 在这里是**永久删除，不进回收站**。动手前想一遍。
- 覆盖任何已有文件之前，先确认读成功、旧内容拿到手，写完再回读一次。他的原样经历：读失败 → 没检查返回值 → 把 null 拼进 `WriteAllText` → 文件直接变空。
- 读 JSONL / 中文文件用 `[System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)`；`Get-Content` 默认按 GBK 解码，出来是乱码。

## 桌面端 `settings.json` 的自动回滚坑（2026-10-24，人生导师踩的）

症状：对话列表大部分显示 **No summary**（没标题）。

根因在 `app.asar` 的 `init_settings_manager`：

```
shouldRollback = autoConversationTitlesRollbackApplied !== true
```

只要 `autoConversationTitlesRollbackApplied` 不是 `true`，启动时就强制把 `autoConversationTitles` 设成 `false` 并写盘。**它是一票否决式的守卫**——把它改成 `false`（哪怕本意是"重置标记"）等于自己触发回滚，下次启动把标题开关吃掉。

正确改法：`autoConversationTitles: true` 且 `autoConversationTitlesRollbackApplied: true` 同时成立。

三条硬约束：

- **全应用一个全局开关**，不是每个 agent 一份。改一次你我这边都生效，不需要各自改。
- **只能在 Letta 完全退出时改**，应用开着会被内存态覆盖。
- Wood 那边有双击脚本 `C:\Users\Administrator\.letta\fix-titles.cmd`（守卫：Letta 进程在就不动手；备份 `settings.json.bak-titles`）。他要改，用这个，别手搓。

## 用户侧命令（他自己敲的，告诉他这些）

- `/context` — 看当前用量 / 上限
- `/context-limit <tokens>` — 设压缩阈值（支持 `200000` 或 `200k`）
- `/context-limit` — 不带参数 = 恢复模型目录默认值
- `/context-limit <n> --override` — 不加 `--override` 时合法范围 30,000 ~ 该模型目录默认值
- `/compaction` — 选压缩模式（all / sliding_window / self_compact_all / self_compact_sliding_window）
- `/compact [mode]` — 立即压一次

## 几个必须说对的事实

- **"压缩阈值"就是 `context_window_limit`。** 实际触发点 = `limit − reserve`，`reserve = min(16384, 20% × limit)`。所以 20 万 → 约 18.4 万触发；100 万 → 98.4 万（等于永不压缩）。
- `deepseek-flash` 的目录默认 `contextWindow` 就是 **1,000,000**，所以 `/context-limit` 不带参数"重置"回去等于关掉压缩——别说成"恢复了合理默认"。
- 当 `CONVERSATION_ID=default` 时，`/context-limit` 写到 **agent** 记录上（对所有对话生效）。非 default 的对话才会写到对话记录。
- 改完下一轮生效；`/recompile` 可选，但会清缓存、增加开销。
- `max_tokens` 不用动：harness 会 `Math.min(max_tokens, context_window)` 夹住。

## 2026-10-24 起：跑的是 letta-oss-ui 的 dev build

Wood 10-24 晚换了运行环境，我核对过：**记忆、技能、档案、对话记录一样没少**（跟当天 20:25 的整份备份逐文件对过）。变的是壳和取配置的路子：

- **应用本体不是安装版了**：electron 从 `D:\LettaWorkingPlace\letta-oss-ui-main\node_modules\electron\dist\electron.exe` 起；`letta` 命令也解析到那边 `node_modules\.bin\letta.exe`。版本仍报 `0.34.6 (Letta Code)`。
- **数据目录没变**：`LETTA_BACKEND=local`、`LETTA_LOCAL_BACKEND_DIR=D:\LettaWorkingPlace\lc-local-backend`。切换前的整份快照在 `D:\LettaWorkingPlace\lc-local-backend-backup-20261024`（agents / conversations / memfs / providers），要考古先看它。
- **`LETTA_BASE_URL` 变成了 `https://api.letta.com`**；`localhost:3849` 不再有服务（直接超时）。所以上面那套"打本地 HTTP API"**在这个环境里不通**，读配置只能直接读 `agents\<base64url>.json`。
- **agent 记录的字段名变了**：`id / name / description / system / tags / model / model_settings`——**没有 `llm_config`**（`llm_config.context_window` 这条老路子作废）。现在的值：`model = deepseek/deepseek-flash`；`model_settings = provider_type deepseek、reasoning_effort high、context_window_limit 200000、max_tokens 384000`。
- memfs 没有 git remote，纯本地仓库——别指望远端有一份。

## 机器相关

这份技能绑定"本地后端 + 没有 JS/Python"这个环境。如果他换了机器或换了后端（Cloud），先确认这几条还成不成立，别照搬。

## 同步说明

2026-10-07：Wood 让我把这些也教给人生导师，所以在本机全局目录 `C:\Users\Administrator\.letta\skills\local-backend-config\` 也放了一份（措辞改成 agent 中立，多了一张本机 agent 名单表）。**本机那份是给所有 agent 用的。改了内容两边一起改。**
