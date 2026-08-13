extends RefCounted
## 共享线性 harness（M1-plan #1）：原型 headless-smoke.mjs 是单线性脚本共享同一个 game，
## Godot 侧场景分文件 → 由本 harness 提供共享局与帧推进工具。
## 场景通过 preload 本文件使用；harness 自身不持有渲染/Node 依赖。
##
## 约束（AGENTS.md 经验 #1）：headless --script 无全局类缓存，跨脚本引用一律 preload。

const GameRunScript: GDScript = preload("res://logic/game_run.gd")

const VIEW_W: int = 1280
const VIEW_H: int = 720
const STEP: float = 1.0 / 60.0
const DIGITS: Array[String] = ["Digit1", "Digit2", "Digit3", "Digit4", "Digit5", "Digit6"]

## 共享对局：所有场景按注册顺序串行使用同一个 game（[2] 的 hp=100000 作弊延续到后续章节）。
var game = null


## 懒加载建局；首次调用前先 reset_save，模拟原型全新 localStorage（main.js import 即建局）。
func ensure_game():
    if game == null:
        MetaSave.reset_save()
        game = GameRunScript.new()
    return game


## 推进 n 个逻辑帧：每帧 step + input.end_frame（与原型 main.js 循环一致）。
func pump(n: int) -> void:
    for i in n:
        game.step(STEP, VIEW_W, VIEW_H)
        game.input.end_frame()


## 推进 n 帧；遇到 opening/choice 自动按 Digit 选卡（prefer(offer) -> bool 指定偏好，
## 命中第一张即选；未命中选第 0 张）。extraction 注入 KeyC；summary 注入 Enter。
## 与原型 pumpWithChoices 逐帧行为一致：先按状态注入按键，再 pump(1)。
func pump_with_choices(n: int, prefer: Callable = Callable()) -> void:
    for i in n:
        if game.state == "opening" or game.state == "choice":
            var offers: Array = game.currentOffers
            if offers.size() > 0:
                var idx: int = 0
                if prefer.is_valid():
                    for j in offers.size():
                        if prefer.call(offers[j]):
                            idx = j
                            break
                if idx >= offers.size():
                    idx = 0
                key_down(DIGITS[idx])
                key_up(DIGITS[idx])
        elif game.state == "extraction":
            key_down("KeyC")
            key_up("KeyC")
        elif game.state == "summary":
            key_down("Enter")
            key_up("Enter")
        pump(1)


# ---------- 输入注入：直接写 game.input（InputState 快照） ----------

func key_down(code: String) -> void:
    game.input.key_down(code)


func key_up(code: String) -> void:
    game.input.key_up(code)


func mouse_move(x: float, y: float) -> void:
    game.input.mouse_move(x, y)


## 原型 input.js mousedown 仅置 _clicked = true（无按住状态），这里保持一致。
func mouse_down(x: float = -1.0, y: float = -1.0) -> void:
    if x >= 0.0:
        game.input.mouse_move(x, y)
    game.input.mouse_down()


## 原型无鼠标按住语义；保留成对 API 供场景使用，无副作用。
func mouse_up() -> void:
    pass
