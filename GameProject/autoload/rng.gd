extends Node
## 可注入随机源（autoload 名：Rng）。
## 原型所有 Math.random() 调用点统一映射为 Rng.next()（PORT_PLAN 决策 5）。
## 测试必须确定性：通过 set_source() 注入常量/确定性序列，禁止依赖系统随机源
## （GameProject/AGENTS.md 测试规范）。

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# 有效时优先生效；Callable 签名：() -> float，返回值域 [0, 1)。
var _source: Callable = Callable()


func _ready() -> void:
    _rng.randomize()


## 注入自定义随机源（测试可注入常量序列）。
func set_source(source: Callable) -> void:
    _source = source


## 移除注入源，恢复内部 RandomNumberGenerator。
func clear_source() -> void:
    _source = Callable()


## 设置内部 RNG 种子（确定性重放用），同时清除注入源。
func set_seed(seed_value: int) -> void:
    _source = Callable()
    _rng.seed = seed_value


## 返回 [0, 1) 的 float，与 JS Math.random() 值域一致。
func next() -> float:
    if _source.is_valid():
        return float(_source.call())
    return _rng.randf()