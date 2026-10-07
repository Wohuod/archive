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

## 机器相关

这份技能绑定"本地后端 + 没有 JS/Python"这个环境。如果他换了机器或换了后端（Cloud），先确认这几条还成不成立，别照搬。

## 同步说明

2026-10-07：Wood 让我把这些也教给人生导师，所以在本机全局目录 `C:\Users\Administrator\.letta\skills\local-backend-config\` 也放了一份（措辞改成 agent 中立，多了一张本机 agent 名单表）。**本机那份是给所有 agent 用的。改了内容两边一起改。**
