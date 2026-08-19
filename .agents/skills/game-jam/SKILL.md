---
name: game-jam
description: >
  在游戏创作活动的截止期限内规划并发布游戏：根据时间锁定范围、安排工时、削减功能并按时提交。
  适用于游戏创作活动（Ludum Dare、GMTK Jam、Global Game Jam）、48 小时或周末开发，
  以及确定活动参赛作品的范围并提交作品。
---

# 游戏创作活动

将一个主题和固定的截止期限转化为一款完成并提交的游戏。这是一份规划和范围控制手册，而非引擎代码：
成功标准是*提交了可玩的作品*，而不是*做出了你想象中的游戏*。

## 使用时机

- 参加限时活动（Ludum Dare、GMTK Jam、Global Game Jam、周末活动）、规划 48 小时开发范围，
  或决定为了赶上截止期限应削减什么内容时使用。
- 当用户询问“一个周末实际上能做出什么”或“如何向这个活动提交作品”时使用。

**不应使用的情况：**用引擎代码构建*核心循环*（请使用引擎 skill——
`godot-2d-movement`、`phaser-core` 等——或 `platformer` 之类的类型 skill）；
没有截止期限的一次性实验（使用 `prototype-fast`）；发布商业版本（使用
`steam-publish` / `itch-publish`）。

## 核心工作流

1. **在主题公布前阅读规则。**确认活动的*时长*、*主题公布时间*、*提交截止时间（含时区）*、
   是否允许组队/预制资源/引擎，以及评分是否要求你评价其他参赛作品。漏掉其中任何一项，
   都可能使原本完成的游戏失去资格。
2. **提前准备枯燥的部分**（大多数活动允许）：可构建和导出的空项目、输入以及标题/结束画面框架、
   已经运行过一次的导出流水线，以及你获准使用的字体/SFX 来源。第一天的时间太宝贵，
   不应耗费在这些事情上。
3. **主题 → 一句话。**在 15 分钟内集思广益想出 10 个创意，然后选定**一个**能表述为：
   *“你通过[动词]实现[目标]，同时受到[限制]。”* 如果无法用一句话说清楚，范围就太大了。
4. **根据时间而非创意确定范围。**使用下方预算表。选择**一个**核心机制和**一个**“亮点”。
   其他一切都是延伸目标。
5. **先构建垂直切片。**尽早让一个 30 秒的可玩循环（开始 → 游玩 → 失败/获胜 → 重新开始）
   运行起来。完整的小循环胜过只完成一半的大循环。
6. **预留最后约 20% 的时间用于发布**，而不是开发功能。导出、在干净路径上测试构建、
   截取屏幕截图、撰写页面。构建总会在第 47 小时出问题。
7. **尽早提交，如有剩余时间再更新。**在截止期限*很久之前*上传可用构建；
   大多数活动页面允许你在关闭前替换文件。已提交的平庸游戏能够得分；未提交的优秀游戏不能。

## 模式

### 1. 按活动时长分配范围预算（从截止期限倒推）

```text
              | 48-hour jam            | 72-hour jam           | 1-week jam
--------------|------------------------|-----------------------|------------------------
Core mechanic | 1, proven by hour 6    | 1-2                   | 2-3 interacting
Levels/content| 1 hand-made or gen'd   | 3-5                   | 8-12 + progression
Art           | placeholder/1 palette  | cohesive 1-artist set | themed set + UI
Audio         | 3-5 SFX + 1 loop       | SFX + 1-2 tracks      | adaptive music
SHIP BUFFER   | last 8-10 h            | last 12-16 h          | last full day
```

### 2. 48 小时时间线（具体时段）

```text
H0-2    Ideate -> lock ONE-sentence concept -> name the core mechanic + win/lose.
H2-8    Core loop in code with primitives (boxes/circles). Make it playable, no art.
H8-12   Sleep. (Tired code is tomorrow's bug list.)
H12-24  Content: 1 level/encounter, tune difficulty, add the "hook" feature.
H24-30  Sleep + playtest with one other person; cut anything not landing.
H30-38  Art + audio pass. Juice: screenshake, hit-stop, tween, particles, SFX.
H38-44  Bug-fix freeze: no new features. Fix only crashes + soft-locks.
H44-48  EXPORT, test the build clean, screenshots, write page, SUBMIT (by ~H46).
```

### 3. 功能分流——快速决定，明确说出决定

```text
For every feature ask, in order:
  1. Does the core loop work WITHOUT it?   -> if yes, it's a stretch goal, not MVP.
  2. Can a player tell it's missing?       -> if no, cut it.
  3. Is it < 30 min of work?               -> if no, defer past the ship buffer.
Default answer under deadline pressure is CUT. You can always add in a post-jam version.
```

### 4. 提交前构建检查（在干净副本上运行，而不是开发文件夹）

```text
[ ] Build runs from an extracted zip on a path with NO engine/IDE installed.
[ ] Controls are shown on-screen or on the page (jurors won't read your mind).
[ ] No dev console errors; no soft-lock; restart works.
[ ] Web build (if any) is set to the platform's playable-in-browser mode.
[ ] Page has: 1-line pitch, controls, screenshots, credits + asset licenses.
[ ] File uploaded and the submission is actually attached to the JAM, not just the page.
```

## 常见陷阱

- **范围蔓延是游戏创作活动的头号杀手。**如果核心循环在总时间的前三分之一内还不可玩，
  现在就削减功能，而不是稍后再做。
- **没有发布缓冲时间。**导出、压缩和撰写页面通常需要 1–3 小时，而且总会暴露构建错误。
  将截止期限视为比实际时间提前约 2 小时。
- **提交到了页面，却没有提交到活动。**在 itch.io 上，活动参赛作品是从活动页面链接的独立
  *submission*——仅上传游戏并不代表已参赛。
- **未经测试的导出。**“在编辑器中可用”不等于“在构建中可用”。在干净路径上测试导出产物；
  缺少资源和错误的工作目录是典型问题。
- **未经许可的资源。**从网上获取的音乐/字体/精灵可能违反活动规则，并妨碍后续发行。
  使用你获准使用的资源，并在制作人员名单中列出它们。
- **在循环变得有趣之前就进行润色。**手感能放大乐趣，却无法创造乐趣。先用占位内容把循环做好。

## 参考资料

- 有关一次性原型与保留型原型的思维方式及灰盒技术，请阅读
  `prototype-fast` skill。
- 有关实际上传机制（项目页面、渠道、`butler push`），请阅读
  `itch-publish`。

## 相关 skill

- `prototype-fast` — 在投入活动工时之前快速验证机制。
- `itch-publish` — 创建页面并上传构建（大多数活动托管在 itch.io 上）。
- 引擎核心（`phaser-core`、`love2d-core`、`godot-gdscript`、…）和类型 skill
  （`platformer`、`roguelike`、…）——构建活动所规划的实际循环。
