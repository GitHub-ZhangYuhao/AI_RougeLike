---
name: prototype-fast
description: >
  在大约一小时内用灰盒图元、严格时间盒和明确的保留/放弃标准构建可玩原型，回答一个问题——
  它有趣吗？适用于制作机制原型、垂直切片或 MVP、灰盒/关卡白盒，或判断一次性实现与保留实现。
---

# 快速制作原型

快速将机制交到玩家手中，了解它是否值得继续开发。原型的产出是一个**决策**（保留 / 放弃 / 重构），
而不是产品。以学习速度为优化目标，并预先决定代码是一次性的还是会承担长期职责。

## 使用时机

- 验证单个机制或“如果这样会怎样”、构建垂直切片 / MVP、为关卡或交互制作灰盒，
  或在投入大量时间之前降低创意风险时使用。
- 当用户说“先做出能玩的东西”、“这有趣吗？”或“先粗略搭出来”时使用。

**不应使用的情况：**有截止期限和提交要求的限时竞赛（使用 `game-jam`）；
发布或更新正式版本（使用 `steam-publish` / `itch-publish`）；构建已验证功能的生产版本
（直接使用引擎/类型 skill）。

## 核心工作流

1. **写下唯一的问题。**说明原型必须回答的唯一问题，例如：
   *“下落时使用抓钩，操控起来是否令人满意？”* 如果你有两个问题，就构建两个原型。
   测试一切的原型等于什么都没测试。
2. **在编写代码之前决定是一次性实现还是保留实现。**一次性实现（*spike*）：硬编码、
   不做架构、之后删除。保留实现：仍然粗糙，但使用可扩展的文件夹/名称。大多数原型都应是
   一次性的；假装并非如此，正是原型腐化为发布代码的原因。
3. **设置严格时间盒**（机制用 30–90 分钟；切片用一次完整工作时段）和可见计时器。
   限制本身就是重点——它迫使你测试*核心*创意，而不是修饰内容。
4. **将所有非必要内容灰盒化。**用图元制作美术（方框、圆形、胶囊），使用内置字体，
   只用一个调试音效或完全不用。对问题不依赖的任何内容都不要花时间。
5. **围绕问题添加检测手段。**添加屏幕调试文本 / gizmo，显示你正在判断的内容
   （速度、距离、时机窗口）。你是在测量，而不是装饰。
6. **立即并诚实地进行游戏测试。**先自己玩，然后在不解释操作方式的情况下交给另一个人。
   观察他们在哪里遇到困难。
7. **根据放弃标准作出决定**（见下文）。保留 → 安排正式构建并*重写*，不要直接采用 spike。
   放弃 → 记录经验并继续前进。重构 → 缩小问题范围，再做一次 spike。

## 模式

### 1. 原型简报（编码前填写）

```text
QUESTION:     The one thing this must prove (binary if possible).
CORE VERB:    The single action the player repeats.
THROWAWAY?:   yes -> hard-code freely, delete after.  no -> minimal structure to grow.
TIMEBOX:      e.g. 60 min. Stop when it rings, even if unfinished.
KEEP IF:      observable signal that means "fun / worth building" (see kill criteria).
KILL IF:      observable signal that means "stop".
```

### 2. 为核心循环制作灰盒，伪造其他一切（与引擎无关的伪代码）

```text
# Only the CORE VERB is real. Visuals are primitives; systems are stubs.
on update(dt):
    read_input()
    apply_core_mechanic(dt)        # the ONLY thing you're testing — make this feel right
    draw_primitive(player)         # a box. not a sprite. not animated.
    draw_debug_hud(speed, timing)  # show the numbers you're judging
    # enemies, menus, save, audio, art -> stubbed or absent until the verb proves out
```

### 3. 放弃标准——让保留/放弃决定基于可观察结果，而不是情绪

```text
KEEP when, with placeholder art:
  - a fresh player does the core verb on purpose within ~30s, unprompted, and
  - you (or they) repeat the loop "one more time" without being asked.
KILL when:
  - the verb only feels good after you explain it, or
  - making it fun needs systems far beyond the prototype's scope, or
  - you're adding art/levels to avoid admitting the verb is flat.
REFACTOR when one variable is clearly off (too slow, window too tight) -> retune, retest.
```

### 4. 隔离：防止 spike 进入发布代码库

```text
prototypes/<idea-name>/      # separate folder or project, never imported by main game
  - hard-coded values, single file ok, magic numbers welcome
  - committed on a throwaway branch (or not at all)
Rule: a "keep" decision authorizes a REWRITE in the real project, not a copy-paste of the
spike. Prototype code carries prototype assumptions; shipping it ships the assumptions.
```

## 常见陷阱

- **过早润色。**美术、菜单和音频会让平淡的机制看似完成，并推迟结论。
  在核心动作得到验证前坚持使用灰盒。
- **没有放弃标准。**没有书面的“满足何种条件就放弃”，每个原型都会“有潜力”，
  什么也不会被砍掉。在对代码产生感情*之前*确定信号。
- **构建系统而非机制。**物品栏、保存/加载和设置并不是问题。用桩代替它们。
- **spike 变成产品。**被提升到生产环境的一次性代码，是一个拥有有趣起源故事的技术债。
  决定保留后应重写。
- **在真实代码库中制作原型。**这会让实验与发布系统纠缠，并使 spike 的删除代价高昂。
  使用独立文件夹/项目。
- **只由自己测试。**你知道操作方式和设计意图。一个未经指导的外部玩家在两分钟内揭示的问题，
  比一小时自测更多。

## 参考资料

- 有关在严格外部截止期限内工作并提交作品，请阅读 `game-jam` skill。
- 有关要在其中构建灰盒核心循环的特定引擎，请阅读该引擎的 skill
  （`godot-gdscript`、`phaser-core`、`love2d-core`、`unity-csharp-scripting`、…）。

## 相关 skill

- `game-jam` — 将同样的范围约束方法应用于有提交要求的限时竞赛。
- 引擎核心和类型 skill — “保留”决定得到妥善重建的地方。
