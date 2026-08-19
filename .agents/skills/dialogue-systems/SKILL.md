---
name: dialogue-systems
description: >
  构建包含条件、变量和本地化钩子的节点/选择图以创建分支对话与叙事，并可选择在 Ink（.ink）、Yarn Spinner（.yarn）之间运行或使用自定义的数据驱动引擎；该功能适用于所有游戏开发场景且保持中立。
---

# 对话系统

将对话建模为**图**：节点持有台词，选择分支流程，条件控制选项，变量记录玩家行为。第一个真正的决定是“自建还是购买”——采用成熟的创作工具（**Ink** 或 **Yarn Spinner**）或者编写一个小型的数据驱动运行器；此技能涵盖 Ink 和 Yarn，《visual-novel》与《rpg》流派依赖它。

## 何时使用

- 用于设计分支对话、选择菜单，或影响后续对话的叙事状态（标志、关系值）。
- 用于在 Ink、Yarn Spinner 以及自定义的 JSON 或资源格式之间进行选择。
- 用于将对话脚本连接到游戏循环中（推进台词、呈现选项、运行命令、解析变量）。

**当 *不* 应使用此技能时：**对于引擎 UI（文本框、头像、选择按钮），请使用 `godot-ui-control` 或引擎的 UI 技能。对于跨会话持久化叙事变量，请使用 `save-systems`。关于 Godot/Unity 中的数据即资源，请参阅 `godot-resources` / `unity-scriptableobjects`。

## 核心工作流

1. **选择创作方式。**
- **Ink**——一款以散文为核心、专为作家设计的引擎，采用 weave/gather（编织/收集）工作流程；特别适用于对话密集型或 CYOA（选择式互动小说）等叙事形式，支持通过 ink runtime/inke 插件进行集成。
   - **Yarn Spinner** —— 基于节点，显式 `<<commands>>`，非常适合带有大量引擎钩子的游戏驱动对话。
   - **自定义运行器** —— 当需要完全控制或最小依赖时，使用 JSON/资源图加小型解释器。**不要构建一种语言；要构建一个图。**
2. **定义节点契约。** 一个节点产出以下之一：台词（说话者 + 文本）、一组选择、命令/副作用，或是结束/跳转。运行器推进通过节点并将台词/选择交给 UI。
3. **将变量与流程分离。** 保持一个变量存储（布尔值、数字、字符串），供对话读写；基于该存储中的条件来控制选项。
4. **从一开始就进行本地化。** 使用**线 ID**而非原始文本进行创作，以便显示的文字来自按区域语言键入的字符串表。
5. **由游戏循环驱动它。** 运行器是一个状态机：`current`（当前）节点 → 发出内容 → 等待输入（继续或选择）→ 推进。
6. **通过遍历分支来验证。** 练习每个选择路径；确认条件、变量写入，以及所有分支都能到达结束点或有效跳转。

## 模式

### 1. 引擎无关的对话图（数据而非代码）

```json
{
  "start": "guard_intro",
  "nodes": {
    "guard_intro": {
      "speaker": "Guard", "line": "DLG_GUARD_001",
      "choices": [
        { "text": "DLG_OPT_BRIBE", "to": "bribe", "if": "gold >= 50" },
        { "text": "DLG_OPT_LEAVE", "to": "end" }
      ]
    },
    "bribe": {
      "speaker": "Guard", "line": "DLG_GUARD_BRIBED",
      "set": { "gate_open": true, "gold": "gold - 50" },
      "next": "end"
    },
    "end": { "end": true }
  }
}
```
`line`/`text` 是**字符串表 ID**（本地化），而非字面文本。`if` 控制选项；`set` 修改变量存储。完整遍历此图的解释器在 `references/runner.md` 中。

### 2. Runner 步骤（图上的状态机）

```gdscript
# The runner holds the current node and a variable store; the UI calls advance().
func present(node):
    if node.has("line"):
        ui.show_line(node.speaker, localize(node.line))
    if node.has("choices"):
        var shown = node.choices.filter(func(c): return eval_cond(c.get("if", "")))
        ui.show_choices(shown)            # only choices whose condition passes

func choose(choice):                       # called when the player clicks a choice
    apply_set(choice.get("set", {}))       # write variables
    goto(choice.to)

func goto(id):
    current = graph.nodes[id]
    apply_set(current.get("set", {}))
    if current.get("end", false): ui.close(); return
    present(current)
    if current.has("next") and not current.has("choices"):
        goto(current.next)                 # auto-advance linear nodes
```
### 3. Ink——利用结（kots）、选项和变量实现分支叙事（Inkle）

```ink
// Ink: '*' = once-only choice, '+' = sticky. [bracketed] text shows only in the
// choice, not the printed result. '->' diverts; '-> END' stops the flow.
VAR gold = 60

=== guard_intro ===
The guard blocks the gate.
* {gold >= 50} [Offer 50 gold]   "Here, take it."
    ~ gold = gold - 50
    The guard pockets it and steps aside. -> END
* [Leave]   You turn back. -> END
```
Ink 跟踪每个 knot（节点）被看到的次数，因此 `{visited_knot}` 是一个内置条件。变量是全局的 (`VAR`) 或临时的 (~ `temp`)。

### 4. Yarn Spinner——节点、选项与命令（Yarn 2.x）

```yarn
title: GuardIntro
---
<<declare $gold = 60>>
Guard: You can't pass.
-> Offer 50 gold <<if $gold >= 50>>
    <<set $gold = $gold - 50>>
    Guard: ...fine. Go on through.
    <<set $gate_open to true>>
-> Leave
    Guard: Good choice.
===
```
Yarn 行可以以 `Speaker:`开头；选项使用 `->`；`<<set>>`/`<<declare>>`管理 `$variables`（变量）；`<<if>>`控制一个选项；`<<jump NodeName>>`在节点间移动。文本中通过 `{$gold}`插值数值。

## 常见陷阱

- **硬编码显示字符串**而不是线 ID 会使本地化变成重写工作。从一开始就针对字符串表进行创作。
- **设计一种用于简单分支树的脚本语言**：若仅需台词、选项与状态标记，使用 JSON/资源图配合约 50 行运行时即可，无需维护复杂的解析器；仅在创作者需要完整流程控制时采用 Ink/Yarn。
- **变量与 UI 耦合**：将叙事状态单独存储，以便相同的对话能在过场、菜单和测试中使用。通过 `save-systems`持久化它。
- **不可达或死胡同节点**：没有 `next`、选择或结束的节点会静默停滞。验证每个节点都能终止或分支。
- **在玩家可重访的线节点中修改状态**会导致双重应用（`gold` 被扣除两次）。在转换时应用 `set`，或使用 seen-flag（已见标志）进行保护。
- **意外混合 Ink 的 `*`（仅一次可用）和 `+`（粘性）**：循环菜单需要粘性 `+` 选择，否则选项在使用一次后会消失。

## 参考资料

- `references/ink-and-yarn.md` —— 并排语法速查表（选择、跳转/分流、变量、条件、包含）及集成说明。
- `references/runner.md` —— 完整的自定义对话运行器：图架构、条件/表达式求值、变量存储和本地化查找。

## 相关技能

- `save-systems` —— 持久化叙事变量和已见标志。
- `godot-resources`, `unity-scriptableobjects` —— 将对话作为引擎数据存储。
- `godot-ui-control` —— 渲染文本框、头像和选择按钮。
- `visual-novel`, `rpg` —— 组合此技能的流派。
