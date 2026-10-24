---
name: tools
description: 这台机器上搜网页/开浏览器该走哪条路——2026-10-24 换过整套，旧的路别再回去。
---

# 查资料 / 开浏览器

**2026-10-24 晚，Wood 把这两件事整条换掉了。** 旧的 `edge-cdp`（我写的 PowerShell CDP + 萌娘百科 API 那套）已移出 `~\.letta\skills\`，备份在 `D:\LettaWorkingPlace\_delisted-skills\2026-10-24\edge-cdp`——**别回去用，别重建**。他给的理由就一句：整条换掉了。我自己 memory 里那份副本当晚也删了（`skills/edge-cdp/`），`vault-archive` 里指向它的那行改成新路了。

一句话的分工：**查资料别开浏览器，要登录态别用 Exa。**

## 查资料 → 技能 `exa-search`

`~\.letta\skills\exa-search\scripts\exa.ps1`，`-Query` 搜索、`-Url` 抓正文，直接 POST `https://mcp.exa.ai/mcp`，不用 key、不用注册 MCP 服务器。坑（SSE、PS 5.1 编码、UTF-8 带 BOM）都写在它自己的 SKILL.md 里，往那边看，不重复记。**拿不到登录态。**

## 浏览器 → `ego-browser`（ego lite，他当晚装的）

`~\.local\share\ego\active_version_dir\ego-browser.exe`，已在 PATH。权威文档 `~\.agents\skills\ego-browser\`；`ego-browser skill` 打印当前版本完整指南（**输出是 UTF-16，先转 UTF-8**）。三条最容易再踩一次的：

1. PS 5.1 没 heredoc 还会吃掉 `-e` 里的双引号 → 脚本写成 `.mjs` 文件（**用文件工具创建，不要 Set-Content**），再 `ego-browser nodejs -e await import('file:///C:/Users/Administrator/ego/<目标-时间>/round-01.mjs')`。
2. **每轮写新文件**（round-01、02…）——改旧文件会重放旧步骤。
3. `profileId` **只在创建 space 时生效**：要登录态必须 `taskSpace(名字, { profileId: Profile 2 })`，否则用的是一个空 profile。

输出走 **stderr**，PowerShell 报 exit 1 红字是正常的；页面结构用 `page.snapshot()`（无障碍树），不是 OCR。

## 记忆提交（pre-commit hook）坏了怎么办

2026-10-24 22:31，dev build 重写了 MemFS 的 `.git/hooks/pre-commit`，把 `run_memory_node` 指到 `%TEMP%\bun-node-*\node.exe`——**那其实是 bun**，而 bun 把 `node -`（从 stdin 读脚本）里的 `-` 当成模块路径，于是**每次 git commit 都报 "Module not found ... \-" 退出 1**，记忆一条也存不进去。机器上没有 PATH 里的 node，真正的 node 在 `D:\Program Files\nodejs\node.exe`。

修法（已改，harness 再更新可能重犯）：把 hook 里那个 `'/c/.../bun-node-*/node.exe' "$@"` 换成 `/d/Program Files/nodejs/node.exe`，保留 bun 作 fallback。**别用 `--no-verify` 绕过**——绕过等于关掉 frontmatter 校验。

