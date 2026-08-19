---
name: visual-novel
description: >
  构建视觉小说：分支脚本、角色与背景显示、带选项的文本框、保存/加载、历史记录以及跳过/自动播放。
  适用于视觉小说、恋爱模拟或分支剧情游戏。
---

# 视觉小说

视觉小说开发指南——涵盖分支脚本、演出（文本框、角色、背景）、选择，
以及玩家期望的易用系统（随时存档、历史记录、跳过、自动播放）。这是一项**组合式**技能：
驱动对话引擎和 UI 层。它不再重复讲解对话引擎或 UI 节点，而是定义脚本模型和
让视觉小说阅读体验舒适的便利功能。

## 何时使用

- 游戏主要是配合角色立绘和背景**阅读分支文本**时使用：视觉小说、恋爱模拟、
  分支互动小说、剧情选择游戏。
- 设计选择/路线结构、剧情标记或视觉小说便利功能（历史记录、跳过、自动前进、随时存档）时使用。

**何时*不*使用：**对话只是大型游戏中的一项功能 → `rpg` 调用
`dialogue-systems`。卡牌/棋盘玩法 → 使用其他类型。分支脚本引擎本身请使用
`dialogue-systems`（Ink / Yarn Spinner）。

## 核心循环

**阅读一句文本 → 前进 →（遇到分支时）做出选择 → 剧情根据标记/选择分支 →
继续阅读 → 抵达结局。**“游戏”在于*分支的形态*以及选择是否真正有影响；
其余都是演出和便利功能。

## 必备系统

1. **分支脚本**——按顺序排列的台词 + 选项 + 跳转，并带有条件和变量（Ink/Yarn）。
2. **文本框**——说话者姓名、正文、打字机显示、点击/按键前进。
3. **角色**——带表情/姿势和位置的立绘，以及显示/隐藏转场。
4. **背景 + 转场**——场景图像、淡入淡出/溶解。
5. **选择**——显示选项、按标记限制部分选项、记录选择。
6. **剧情状态**——让脚本分支并解锁内容的标记/变量。
7. **保存/加载（随时存档）**——完整脚本位置 + 状态；多个槽位；快速保存。
8. **视觉小说便利功能**——历史记录、跳过（已读文本）、自动前进、文本速度设置。
9. **音频**——逐场景音乐、SFX、可选语音片段。

## 设计参数

| 参数 | 影响 | 说明 |
|------|--------|-------|
| 文本速度 / 即时显示 | 阅读舒适度 | 始终允许即时显示 + 跳过。 |
| 自动前进延迟 | 免手操作阅读 | 可调整；遇到选择时暂停。 |
| 跳过范围 | 重读体验 | 默认只跳过*已读*文本。 |
| 分支广度/深度 | 重玩价值与成本的取舍 | 分支会成倍增加写作/美术工作量。 |
| 标记限定内容 | 响应性 | 检查过去决定的台词/选项。 |
| 路线结构 | 故事形态 | 分支后汇合与独立路线的取舍（参考资料）。 |
| 选项可见性 | 公平性 | 显示锁定选项或将其隐藏。 |
| 历史记录长度 | 便利性 | 保留足够内容以重读近期上下文。 |

## 模式

### 1. 将脚本作为引擎遍历的数据

```python
# Pseudocode. Lines, choices, and jumps as data — usually authored in Ink/Yarn and stepped
# through by that runtime. The engine asks the script for "the next thing to show".
node = script.current()
if node.kind == "line":
    show_text(node.speaker, node.text)        # wait for advance input
elif node.kind == "choice":
    options = [o for o in node.options if condition_met(o.condition, flags)]  # gate by flags
    show_choices(options)                      # wait for selection
elif node.kind == "set":
    flags[node.var] = eval_expr(node.expr, flags)
script.advance(selected_option_or_none)
```

### 2. 打字机显示 + 前进（可跳过）

```python
# Pseudocode. Reveal characters over time; a click first completes the line, then advances.
def show_text(speaker, text):
    name_label.text = speaker
    revealed = 0
    while revealed < len(text):
        if advance_pressed():                  # first press: reveal the whole line instantly
            revealed = len(text); break
        revealed += chars_per_second * dt
        body_label.text = text[:int(revealed)]
        push_to_backlog_when_complete(speaker, text)
    wait_for_advance()                          # second press: go to the next line
```

### 3. 选择设置标记，供后续内容分支

```python
# Pseudocode. Choices write flags; later conditions read them — that is "reactivity".
def on_choice(option):
    if option.set: flags[option.set] = True     # e.g. flags["helped_npc"] = True
    script.jump(option.target)                   # follow the branch

# Elsewhere, a line/choice/ending checks the flag:
if flags.get("helped_npc"): play_route("good_ending") else: play_route("neutral_ending")
```

## 陷阱 / 失败模式

- **存档只保存检查点** → 视觉小说需要**随时存档**。持久化精确脚本位置、所有标记/变量
  （以及已读文本数据），确保加载后恢复到同一句。
- **演出逻辑嵌入脚本** → 无法维护。将*内容*（文本、选择）保留在脚本中，
  将*呈现方式*（立绘、转场）保留在引擎层。
- **没有跳过/自动播放/历史记录** → 读者会感到受困，重玩时尤其如此。这些是预期的基础功能，而非额外功能。
- **跳过未读文本** → 玩家错过内容。跳过功能只应快进**已读**文本。
- **选择没有后果** → 立即重新汇合的分支会显得虚假。设置标记，明显改变后续台词、选项或结局。
- **组合式分支爆炸** → 无法完成。相比完全独立的树状结构，应优先采用分支后汇合，
  并加入少量受标记影响的变化（参考资料）。
- **丢失阅读上下文** → 没有历史记录可重读前几句。保留历史缓冲区。
- **语言硬编码** → 无法本地化。将文本保存在以翻译键索引的数据中。

## 组合方式（由以下技能构建）

- **脚本引擎：**`dialogue-systems`（Ink / Yarn Spinner）——分支、条件、变量、本地化钩子。
- **演出：**`game-ui-ux` 用于文本框/选项菜单布局、缩放和安全区；`godot-ui-control` 用于具体的文本框、选项菜单、姓名牌和历史记录 UI。
- **持久化：**`save-systems` 用于随时存档槽位、已读文本/跳过数据和设置。
- **音频：**`audio-design` 用于逐场景音乐、SFX 和语音播放。
- **视觉：**引擎动画/`Tween` 技能用于立绘/背景转场；`shader-programming` 用于溶解。
- **流程：**添加美术前，使用 `prototype-fast` 以纯文本测试分支结构。

## 参考资料

- 有关分支数据模型、路线结构（分支后汇合与独立路线）、标记/变量、随时存档 +
  历史记录/跳过数据，以及内容/演出分离，请阅读 `references/script-and-flow.md`。
