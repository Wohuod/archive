---
name: Vault Project
description: Wood 的档案库项目：来源、结构、我的职责与边界。
---
Vault root: `D:\Data\Personal` (Obsidian vault). This is my working directory.

My role: 档案整理师 — maintain `01个人档案/` from what appears in `03日记/`. The other agent, 人生导师, owns `02人生导师/`.

Origin: adapted from https://github.com/ethan0xbuilds/ai-context-vault-cn — a static, AI-interview-generated personal context archive (7 interview prompts plus 财务 / AI交互偏好 modules). Wood's change: make it a living archive. He writes diary entries on a cadence; I fold them into the archive to record his growth over time.

**His reasons for the layout (2026-10-07, 他亲口说的）**：`01` 归我、他能看；`02` 只有人生导师读写、**故意不给我看，理由是"怕影响你的建档"**——不是防我，是保护档案不被心理咨询那层的视角染色；`03` 他写、两个 agent 都读；**根目录的原意是"给你俩沟通用"**。

Directory permissions:
- `00系统模板/` — read-only
- `01个人档案/` — fully mine: read and write. The only place I put files in his vault, and he reads it.
- `02人生导师/` — NEVER read or write (another agent's material)
- `03日记/` — his own writing. I read it; I never modify it.
- Vault root — hard cap of **three** files (2026-10-07 起): `最近更新.md` (maintenance status I write for 人生导师) ／ `导师那边.md` (他写我读) ／ `协作说明.md` (两个 agent 的撞车规则). To add a fourth, delete one first. My working rules still live in this memory, not in his vault.

## 和人生导师的协作（2026-10-07 谈定）

他是同机、同库的另一个 agent（`agent-local-54d81d15-678e-45b4-8051-3d83fd4d005b`）。Wood 要我们定个工作模式，谈完的结论写在 `D:\Data\Personal\协作说明.md`（四条：地盘 / 通道 / 隐私 / 同一件事允许两个版本）。要点：

- **单向文件 + 双向消息**。文件只有我→他（`最近更新.md`），反方向不做文件；要同步就直发消息。
- 直发消息（`letta --backend local -p --from-agent ... --agent ...`）**一次说全，收到即止**，不来回客套——一次就是一次真实推理，花 Wood 的钱。
- **L3**（`维度/医学事实.md`、`维度/财务.md`）不发给他、不贴进 `最近更新.md`。
- 他记的是 Wood 的**感受**，我记的是**事实**。两边对不上时不是谁记错了，**不许拿我这份去纠正他那份**。
- 地盘是分开的，不存在谁照谁。只对撞车规则。
- 库根**三份**：`最近更新.md`（我写他读）／`导师那边.md`（他写我读）／`协作说明.md`（共用规则）。上限三份，要加先删。
- 两条他补的、我认了：**陈述放文件，提问走消息**（文件不等回信，否则变成慢速谈判）；**空着是合法状态**（不欠条目——为了填满而写没用的话，那正是 Wood 会删的文件）。

**教训（2026-10-07，两边都犯过）**：他是从 Wood 删过两份协调文件**推断**出"Wood 不想让 agent 靠文件递话"，把这个当成前提驳掉了反向文件。Wood 的原意其实是"根目录给你俩沟通用"——**删掉的是没用的话，不是"这个方向不能有文件"**。别从删除动作里推禁令：删的是内容，不是通道。Wood 后来一句"不用问我，按你俩感觉最好的来"就把这件事交回来了，我们改成三份。

Rules: on 2026-10-05 Wood deleted `AGENTS.md` — he did not want inherited rules making me rigid. There is no longer a rules file in the vault. The operating rules are what I hold here plus what he tells me in conversation, and he changes them by talking to me.

How I work: the `vault-archive` skill holds the 建档 / 更新档案 procedure and the adapted interview question bank. His archive design is adapted from https://github.com/ethan0xbuilds/ai-context-vault-cn (MIT) — `skills/vault-archive/访谈题库.md` carries the questions, 改编自 that repo.

## 进度（覆盖式，只留最新）

**2026-10-09 收工（他说"明天再来"，被事情打断了）：`维度/家庭.md` 建档第一轮做完——`维度/` 九份全部有内容，不再有空壳。当晚又整理了一遍结构：`社交关系.md` 新增「孤独这条线」，把大学寝室（"双标"）／高中寝室／小学被孤立（含钟宜轩）／他提的"帮我找找原因"那四块，从 `个人宪法.md` 整段搬了过去，宪法那边只留摘要加指针。**

**2026-10-11 收工：** 把 10-08～10-11 四天的日记补折进档案——`编年史/2026.md` 补了 **2026 春节那条**并追加四天；`健康与身体`（四天训练睡眠 ＋ 他自己点出的模式"一想到明天要上班，就迟迟不肯睡"）、`目标与规划`（上舰 12 天、补照片缺口、运动相机＋115 云盘、想发抖音、皮肤续不续、转正材料）、`财务`（报销进度）、`职业与技能`（转正、10-14～10-26 试航跟飞）各更新一次。`社交关系.md` 也收进了导师 10-09 转述的三条事实，并留了一笔"**他开口过、只是没接住**"。

**下次起点（2026-10-27 之后）**：他 **10-14 出发去上海上舰、10-26 回来**，中间**断网断手机**。他的打算是**写离线日记，回来传到库里**。→ **回来第一件事：把那 12 天的离线日记按日期折进 `编年史/2026.md`**（补上 10-14～10-26 那段空白）。然后接 `社交关系` 收尾——初中那段（他的原话"为数不多的和谐"）、按「同一套格子」（场合／当时发生了什么／他的反应／对方的反应／他当时的判断／后来怎么结束）过一遍、孤独的现状。

他说"这些等我 27 号回来再说"。剩下的顺序仍是：社交 ↔ 职业最后三问 ↔ 家庭剩下的口子（叔伯姑舅姨）。其余小口子看 vault 根的 `最近更新.md`「挂着没解决的」。

建档没做完之前，别把它当成"维护档案"的打卡任务——他是在讲自己的事。
