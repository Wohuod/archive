---
name: edge-cdp
description: 本机没装 Node/Bun 时，用 PowerShell 直接说 DevTools 协议操控 Edge 打开页面并读 JS 渲染后的正文。要读某个网页、或需要浏览器才能拿到的内容时加载。
---

# 用 PowerShell 操控浏览器（CDP）

适用场景：**本机没有 Node / Bun**，但有 Chromium 系浏览器（Windows 上一般有 Edge）。

脚本：`scripts/cdp.ps1`

## 用法

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\LettaWorkingPlace\lc-local-backend\memfs\agent-local-60ed219e-355c-4567-980f-7b0bf1328d0f\memory\skills\edge-cdp\scripts\cdp.ps1" -Url "https://..." -WaitSeconds 12 -MaxChars 3000
```

参数：`-Url`（要打开的地址）、`-Port`（默认 9222）、`-WaitSeconds`（导航后等多久，SPA 给 10–15）、`-MaxChars`（输出截断）。

输出的是一行 `document.title ||| document.body.innerText`——正文纯文本，够读。

## 这台机器上学到的坑（2026-10-07 实测）

1. **不要用他正在用的默认 profile 开调试端口。** 两个原因叠加：Edge 已经开着，同一个 profile 挂不上第二个实例；而且新版 Chromium 默认禁止对默认 profile 开 `--remote-debugging-port`。
2. 所以脚本用 `%TEMP%\edge-cdp-profile` 这个**独立 profile**，会在他屏幕上开一个干净窗口（可见是好事，他能看着）。
3. 代价：**没有他的登录态**。公开页面没问题；登录后的页面（小红书、抖音）要请他在那个窗口里**手动登录一次**，之后 profile 留着，能用一阵。
4. **别去复制他的 profile 目录**——那会碰到他的 cookie。不干。
5. **别每次重开浏览器**。第一版每次都拿 `about:blank` 当启动页新开一个实例，于是他的窗口里每跑一次多一个空白页（他会发现并问）。现在：先探 9222，通了就复用；跑完自动关掉遗留的空白页，不碰他自己的标签页。
6. **页面级连接会被站点换文档打断**。抖音就是：`WebSocket is in an invalid state ('Aborted')`——它加载时把文档上下文整个换掉，挂在页面上的 socket 跟着死。修法是**浏览器级附加**：连 `/json/version` 的 browser socket，再 `Target.attachToTarget { targetId, flatten: true }` 挂到页面，之后每条命令带 `sessionId`。页面怎么跳都不会断。

## 已验证可用

- 读 B 站个人空间（典型 JS 渲染 SPA）：拿到简介、粉丝数、投稿列表、每条的播放量与日期。

## 可扩展

- 截图：`Page.captureScreenshot`（base64 → 存盘 → 用 Read 看）
- 点击 / 输入：`Input.dispatchMouseEvent`、`Input.insertText`
- 等条件成立：轮询 `Runtime.evaluate` 直到表达式为真
- 坑：导航会销毁执行上下文，`Runtime.evaluate` 可能落空，要重试
- 大页面会分片传，脚本目前假设单帧

## 老实话

**对公开页面，平 HTTP（`Invoke-WebRequest`）就够了，不用开浏览器。** 浏览器是给「JS 渲染」和「登录态」这两种情况准备的。先试 HTTP，不成再上这个。

## 同步说明

2026-10-07：Wood 让我把这个方法教给人生导师，所以在本机全局目录 `C:\Users\Administrator\.letta\skills\edge-cdp\` 也放了一份（脚本同路径 `scripts\cdp.ps1`），所有 agent 都能加载。**本机那份是给别的 agent 用的，我这份跟着我的记忆走。改了内容两边一起改。**
