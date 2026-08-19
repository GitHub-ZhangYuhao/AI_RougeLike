---
name: puzzle
description: >
  构建益智游戏：网格/棋盘状态、移动输入、基于规则的结算（三消连锁、Sokoban
  推箱、瓦片逻辑）、计分和撤销。适用于三消、Sokoban 或网格逻辑益智游戏。
---

# 益智游戏

网格/棋盘益智游戏开发指南——涵盖棋盘模型、移动输入、规则结算（匹配、推动、逻辑）、
计分、撤销和关卡推进。这是一项**组合式**技能：对棋盘状态和规则进行建模，并通过瓦片地图/UI
呈现。它不再重复讲解瓦片地图，而是定义结算循环和正确性规则（状态整洁、确定性结算、撤销），
确保益智游戏公平且没有缺陷。

## 何时使用

- 游戏采用玩家通过操作改变的**离散棋盘**，且棋盘会**按规则结算**时使用：
  三消/瓦片匹配、Sokoban/推箱、滑块益智、逻辑网格。
- 设计匹配/连锁结算、撤销、关卡推进或可解性时使用。

**何时*不*使用：**带永久死亡的实时网格动作 → `roguelike`。卡牌区域/回合 →
`card-game`。基于物理的“益智平台跳跃” → `platformer` + `physics-tuning`。
瓦片渲染请使用 `godot-tilemap` / `unity-tilemap-2d`。

## 核心循环

**读取棋盘 → 规划一步 → 执行移动 → 棋盘按规则结算（匹配、推动、下落、填充、连锁）→
查看目标进度 → 重复直至解开/失败。**乐趣在于*规划*；引擎的职责是以**确定性**方式
结算每一步，并清晰地呈现结果。

## 必备系统

1. **棋盘模型**——由容纳棋子的单元格构成的网格；唯一事实来源（逻辑，而非视觉）。
2. **移动输入**——交换、推动、拖拽、旋转或放置；应用前验证合法性。
3. **规则结算**——检测并应用该类型的规则（匹配、推动、逻辑），直至稳定。
4. **连锁/连击**——结算改变棋盘后，反复结算直至不再变化。
5. **目标 + 计分**——胜负条件（得分、全部清除、到达目标）；步数/时间限制。
6. **撤销**——精确还原上一步（及其结算）；对思考型益智游戏至关重要。
7. **关卡推进 +（通常还有）生成**——手工制作或生成**可解**棋盘。
8. **反馈（“表现力”）**——为匹配、下落和连锁提供清晰且令人满足的动画/声音。

## 设计参数

| 参数 | 影响 | 说明 |
|------|--------|-------|
| 网格大小 / 形状 | 复杂度 | 方格是标准形式；六边形/不规则网格会改变手感。 |
| 匹配/推动规则 | 类型特色 | 三连、特定形状、推入目标等。 |
| 连锁计分 | 深度奖励 | 连锁越大，收益按指数增长。 |
| 步数 / 时间限制 | 压力 | 步数限制更偏解谜；时间限制更偏街机。 |
| 难度曲线 | 学习过程 | 每次引入一种机制。 |
| 撤销深度 | 宽容度 | 单步与完整历史记录。 |
| 可解性保证 | 公平性 | 生成的棋盘必须可解。 |
| 死锁处理 | 避免死局 | 检测无可用移动；洗牌或结束（参见参考资料）。 |

## 模式

### 1. 棋盘模型 + 匹配检测（逻辑与视觉分离）

```python
# Pseudocode. The board is the truth; rendering reads from it. (0,0) top-left, y grows down.
board = [[piece_or_empty for _ in range(W)] for _ in range(H)]

def find_matches(board):
    matched = set()
    for y in range(H):                       # horizontal runs of >= 3 equal pieces
        run = 1
        for x in range(1, W):
            if board[y][x] and board[y][x] == board[y][x-1]: run += 1
            else:
                if run >= 3: matched |= {(y, k) for k in range(x-run, x)}
                run = 1
        if run >= 3: matched |= {(y, k) for k in range(W-run, W)}
    # ... repeat the same scan vertically (columns) ...
    return matched
```

### 2. 结算 → 塌落 → 填充 → 连锁（重复至稳定）

```python
# Pseudocode. One player move can trigger a chain; loop until the board stops changing.
def resolve(board):
    chain = 0
    while True:
        matches = find_matches(board)
        if not matches: break                 # stable: resolution complete
        chain += 1
        score += score_for(matches, chain)    # later chain steps score more (see refs)
        clear(board, matches)                  # remove matched pieces
        apply_gravity(board)                   # pieces fall into the gaps
        refill(board, rng)                      # spawn new pieces at the top (seeded RNG)
    return chain
```

### 3. 通过状态快照或命令撤销

```python
# Pseudocode. Snapshot before each move; undo restores it exactly (board + score + counters).
def make_move(move):
    history.append(snapshot(board, score, moves_left))   # push BEFORE applying
    apply(move); resolve(board); moves_left -= 1

def undo():
    if history:
        board, score, moves_left = history.pop()         # exact revert, including resolution
```

对于大型棋盘，为节省内存，应优先使用**命令**模式（保存移动和足以将其逆转的信息），
而不是完整快照；对小型棋盘而言，快照最简单且完全够用。

## 陷阱 / 失败模式

- **混合逻辑与视觉** → 动画与状态不同步并导致缺陷。棋盘模型是唯一事实来源；视图只负责渲染。
- **只结算一次** → 漏掉连锁/连击。循环结算，直至棋盘稳定（模式 2）。
- **撤销未还原全部内容** → 分数/步数/随机状态漂移。快照保存*所有*状态，或让移动完全可逆。
- **填充 RNG 无种子** → 无法复现关卡，也无法确定性撤销或生成每日谜题。为其设置种子。
- **生成的棋盘不可解** → 产生不公平死局。先生成再验证，或从已知解法反向生成（参见参考资料）。
- **不检测死锁**（三消）→ 棋盘没有合法移动而软锁。检测“无可用移动”，然后洗牌或结束关卡（参见参考资料）。
- **难度陡增** → 一次引入过多机制。每关先教授一种机制，再进行组合。
- **结算动画期间接受输入** → 导致重复移动/状态损坏。锁定输入，直至棋盘稳定。

## 组合方式（由以下技能构建）

- **棋盘渲染：**`godot-tilemap` / `unity-tilemap-2d` 用于网格；`godot-ui-control` 用于 HUD、分数和菜单。
- **关卡：**`level-design` 用于手工益智关卡和难度节奏；`procedural-gen` 用于生成可解棋盘。
- **持久化：**`save-systems` 用于关卡进度、最高分和带种子的每日谜题。
- **表现力：**`game-feel` 用于匹配/连锁爆破、屏幕震动和连锁反馈；引擎动画/`Tween` 技能用于交换/下落/清除；`audio-design` 用于匹配和连锁提示音。
- **脚本：**`godot-gdscript` / `unity-csharp-scripting` 用于结算循环和规则。

## 参考资料

- 有关三消检测/重力/填充/连锁细节、死锁检测和重新洗牌、Sokoban/规则型谜题、
  撤销策略、可解生成和计分，请阅读 `references/board-and-resolution.md`。
