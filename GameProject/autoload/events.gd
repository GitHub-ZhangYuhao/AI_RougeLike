extends Node
## 表现层信号总线（autoload 名：Events），见 PORT_PLAN 实现决策 2。
## 逻辑层（logic/）不感知表现：特效、震屏、公告、音效钩子一律经此广播，
## 由 scenes/ 订阅并渲染。M0 仅声明信号集合，M1+ 逐步接入。
## 约定：信号参数只用基础类型（float / int / bool / String / Dictionary），
## 不向外传递逻辑层对象；世界坐标以 float 分量传，避免 Vector2 的 float32 隐患。

# ---------- 相机 / 震屏 ----------
## 震屏请求：对应原型 game.hitShake（玩家受击、爆炸等）。
@warning_ignore("unused_signal")
signal screen_shake(intensity: float)

# ---------- 特效 / 实体视觉钩子 ----------
## 特效生成：kind 区分 hit/explosion/pickup 等；(x, y) 为世界坐标；data 携带附加参数。
@warning_ignore("unused_signal")
signal effect_spawned(kind: String, x: float, y: float, data: Dictionary)
## 敌人死亡：死亡爆裂与尸体血迹钩子（对应原型 corpses 纯视觉血迹）。
@warning_ignore("unused_signal")
signal enemy_killed(kind: String, x: float, y: float, data: Dictionary)
## 玩家受击：受击红闪 / hitFlash 反馈。
@warning_ignore("unused_signal")
signal player_hurt(damage: float)
## 玩家升级：升级特效与选卡开启提示。
@warning_ignore("unused_signal")
signal player_level_up(level: int)

# ---------- 公告 / 横幅 ----------
## 波次横幅：对应原型 waveDirector.bannerTimer 的 HUD 渲染（普通波 / BOSS 波 / 休整）。
@warning_ignore("unused_signal")
signal wave_banner(wave: int, is_boss: bool, is_rest: bool)
## 通用公告：对应原型 rareMessage、synergy 公告等；kind 区分来源。
@warning_ignore("unused_signal")
signal announcement(text: String, kind: String)

# ---------- 音效钩子 ----------
## 原型暂无音频实现，预留统一音效入口；name 为音效标识，data 携带位置等附加参数。
@warning_ignore("unused_signal")
signal sfx_requested(name: String, data: Dictionary)
