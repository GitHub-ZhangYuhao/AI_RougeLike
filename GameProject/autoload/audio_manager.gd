extends Node
## 音频管理器（Autoload：AudioManager）
## 统一管理 BGM 与 SFX：
##   - SFX 使用 8 路 AudioStreamPlayer 池，支持节流与音高抖动
##   - BGM 使用双播放器交叉淡入淡出
##   - 轮询 game_run 状态自动切换 BGM
##   - 监听 Events.sfx_requested 处理显式音效请求（UI 点击等）
## 音频文件为 OGG 格式，放在 assets/audio/ 下。文件不存在时静默跳过。

# ============================================================
#  常量
# ============================================================

## SFX 同时播放最大数（多态复音）
const SFX_POOL_SIZE: int = 8
## BGM 交叉淡入淡出时长（秒）
const BGM_CROSSFADE: float = 1.0

# ============================================================
#  节点引用
# ============================================================

var _sfx_pool: Array[AudioStreamPlayer] = []
var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _current_bgm_player: AudioStreamPlayer
var _next_bgm_player: AudioStreamPlayer
var _current_bgm_name: String = ""

# ============================================================
#  资源缓存
# ============================================================

## SFX 资源缓存：name → AudioStreamOggVorbis
var _sfx_cache: Dictionary = {}
## BGM 资源缓存：name → AudioStreamOggVorbis
var _bgm_cache: Dictionary = {}

# ============================================================
#  节流系统
# ============================================================

## 每个 SFX name 的上次播放时间戳
var _throttle_times: Dictionary = {}
## 每个 SFX name 的最小播放间隔（秒）
var _throttle_intervals: Dictionary = {}

# ============================================================
#  游戏状态轮询（BGM 自动切换 + 隐式音效触发）
# ============================================================

var run = null
var _prev_state: String = ""
var _prev_enemy_count: int = 0
var _prev_gem_count: int = 0
var _prev_pickup_count: int = 0
var _prev_player_hp: float = -1.0
var _prev_level: int = 0
var _prev_is_boss_wave: bool = false
var _prev_card_played: bool = false
## 武器实例 id → 上一帧 shocks/furnaces 数量（检测新增爆发用）
var _prev_weapon_counts: Dictionary = {}
## 清理节流字典的计时器
var _cleanup_timer: float = 0.0

# ============================================================
#  SFX 名称 → 资源路径映射
# ============================================================

const SFX_PATHS: Dictionary = {
	# --- 武器 ---
	"sfx_sword_swing": "res://assets/audio/sfx/weapon/sfx_sword_swing.ogg",
	"sfx_sword_slash": "res://assets/audio/sfx/weapon/sfx_sword_slash.ogg",
	"sfx_talisman_zap": "res://assets/audio/sfx/weapon/sfx_talisman_zap.ogg",
	"sfx_cloak_burst": "res://assets/audio/sfx/weapon/sfx_cloak_burst.ogg",
	"sfx_trail_blaze": "res://assets/audio/sfx/weapon/sfx_trail_blaze.ogg",
	"sfx_ring_orbit": "res://assets/audio/sfx/weapon/sfx_ring_orbit.ogg",
	"sfx_staff_cast": "res://assets/audio/sfx/weapon/sfx_staff_cast.ogg",
	# --- 敌人 ---
	"sfx_enemy_death": "res://assets/audio/sfx/enemy/sfx_enemy_death.ogg",
	"sfx_enemy_hit": "res://assets/audio/sfx/enemy/sfx_enemy_hit.ogg",
	"sfx_boss_roar": "res://assets/audio/sfx/enemy/sfx_boss_roar.ogg",
	# --- 玩家 ---
	"sfx_player_hurt": "res://assets/audio/sfx/player/sfx_player_hurt.ogg",
	"sfx_player_death": "res://assets/audio/sfx/player/sfx_player_death.ogg",
	"sfx_level_up": "res://assets/audio/sfx/player/sfx_level_up.ogg",
	# --- 拾取 ---
	"sfx_gem_pickup": "res://assets/audio/sfx/pickup/sfx_gem_pickup.ogg",
	"sfx_hp_pickup": "res://assets/audio/sfx/pickup/sfx_hp_pickup.ogg",
	"sfx_rare_pickup": "res://assets/audio/sfx/pickup/sfx_rare_pickup.ogg",
	"sfx_extraction": "res://assets/audio/sfx/pickup/sfx_extraction.ogg",
	# --- UI ---
	"sfx_ui_click": "res://assets/audio/sfx/ui/sfx_ui_click.ogg",
	"sfx_card_select": "res://assets/audio/sfx/ui/sfx_card_select.ogg",
	"sfx_card_deal": "res://assets/audio/sfx/ui/sfx_card_deal.ogg",
	# --- 波次 ---
	"sfx_wave_start": "res://assets/audio/sfx/wave/sfx_wave_start.ogg",
	"sfx_boss_alarm": "res://assets/audio/sfx/wave/sfx_boss_alarm.ogg",
}

## BGM 名称 → 资源路径映射
const BGM_PATHS: Dictionary = {
	"menu": "res://assets/audio/bgm/bgm_menu.ogg",
	"gameplay": "res://assets/audio/bgm/bgm_gameplay.ogg",
	"boss": "res://assets/audio/bgm/bgm_boss.ogg",
	"rest": "res://assets/audio/bgm/bgm_rest.ogg",
	"extraction": "res://assets/audio/bgm/bgm_extraction.ogg",
	"summary": "res://assets/audio/bgm/bgm_summary.ogg",
}

## 游戏状态 → BGM 名称映射
const STATE_BGM: Dictionary = {
	"menu": "menu",
	"shop": "menu",
	"storage": "menu",
	"opening": "gameplay",
	"playing": "gameplay",
	"choice": "gameplay",
	"dead": "summary",
	"summary": "summary",
}

## 高频音效节流默认间隔（秒）
const HIGH_FREQ_INTERVALS: Dictionary = {
	"sfx_enemy_death": 0.06,
	"sfx_enemy_hit": 0.08,
	"sfx_gem_pickup": 0.05,
	"sfx_player_hurt": 0.15,
	"sfx_cloak_burst": 0.25,
	"sfx_trail_blaze": 0.3,
}

# ============================================================
#  生命周期
# ============================================================

func _ready() -> void:
	# 1) 创建 SFX 播放器池
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPool_%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)
	# 2) 创建 BGM 播放器
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name = "BGM_A"
	_bgm_player_a.bus = "Music"
	add_child(_bgm_player_a)
	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name = "BGM_B"
	_bgm_player_b.bus = "Music"
	add_child(_bgm_player_b)
	_current_bgm_player = _bgm_player_a
	_next_bgm_player = _bgm_player_b
	# 3) 创建/恢复音频总线
	_setup_audio_buses()
	# 4) 连接事件总线（显式 SFX 请求入口）
	Events.sfx_requested.connect(_on_sfx_requested)
	# 5) 注册高频音效节流间隔
	for key: String in HIGH_FREQ_INTERVALS:
		_throttle_intervals[key] = HIGH_FREQ_INTERVALS[key]


func _setup_audio_buses() -> void:
	## 兜底：默认总线布局由 project.godot 的 default_bus_layout 提供
	## （assets/audio/default_bus_layout.tres：Master/Music/SFX）。
	## 若布局缺失则动态补建总线，避免 player.bus 指向不存在的总线。
	var has_music := false
	var has_sfx := false
	for i in AudioServer.bus_count:
		match AudioServer.get_bus_name(i):
			"Music": has_music = true
			"SFX": has_sfx = true
	if not has_music:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if not has_sfx:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")


func _process(_delta: float) -> void:
	if run == null:
		if not is_node_ready():
			return
		# 首帧尝试获取 game_run（game_view 会在 _ready 中调用 bind_run）
		return
	# 节流字典定期清理（每 5 秒）
	_cleanup_timer += _delta
	if _cleanup_timer >= 5.0:
		_cleanup_timer = 0.0
		_cleanup_throttle()
	_check_state_change()
	_check_enemies()
	_check_gems()
	_check_pickups()
	_check_player()
	_check_level_up()
	_check_weapons()
	_check_boss_wave()


# ============================================================
#  绑定入口 —— 由 game_view.gd 在 _ready 中调用
# ============================================================

func bind_run(game_run) -> void:
	run = game_run
	_prev_state = run.state
	_prev_enemy_count = run.enemies.size()
	_prev_gem_count = run.gems.size()
	_prev_pickup_count = run.pickups.size()
	_prev_player_hp = run.player.hp
	_prev_level = run.level
	_prev_is_boss_wave = false
	_prev_card_played = false
	_prev_weapon_counts = {}
	_throttle_times.clear()
	_cleanup_timer = 0.0
	# 新对局直接落位对应 BGM（无淡入）
	_set_bgm(STATE_BGM.get(run.state, "gameplay"))


func _check_weapons() -> void:
	## 武器爆发音效：披风冲击波（shocks）与丹火炉（furnaces）新增时触发
	for weapon in run.weapons:
		var wid: int = weapon.get_instance_id()
		if not _prev_weapon_counts.has(wid):
			_prev_weapon_counts[wid] = _weapon_event_count(weapon)
			continue
		var current: int = _weapon_event_count(weapon)
		var prev: int = _prev_weapon_counts[wid]
		if current > prev:
			if "shocks" in weapon:
				var enhanced: bool = false
				for i in range(prev, current):
					if weapon.shocks[i].get("enhanced", false):
						enhanced = true
				play_sfx("sfx_cloak_burst", {"no_pitch_variance": enhanced})
			elif "furnaces" in weapon:
				play_sfx("sfx_trail_blaze")
		_prev_weapon_counts[wid] = current

func _weapon_event_count(weapon) -> int:
	if "shocks" in weapon:
		return weapon.shocks.size()
	if "furnaces" in weapon:
		return weapon.furnaces.size()
	return -1


# ============================================================
#  播放入口
# ============================================================

## 播放一次性音效。data 可选键：
##   pitch: 显式音调（>0 时覆盖抖动）；no_pitch_variance: true 关闭随机抖动。
## 资源缺失时静默跳过（音频资产仍在补齐中）。
func play_sfx(sfx_name: String, data: Dictionary = {}) -> void:
	if not SFX_PATHS.has(sfx_name):
		return
	if _is_throttled(sfx_name):
		return
	var stream: AudioStream = _load_sfx(SFX_PATHS[sfx_name])
	if stream == null:
		return
	var player: AudioStreamPlayer = _find_free_sfx_player()
	player.stream = stream
	var pitch: float = float(data.get("pitch", 0.0))
	if pitch <= 0.0:
		pitch = 1.0 if data.get("no_pitch_variance", false) else randf_range(0.94, 1.06)
	player.pitch_scale = pitch
	player.play()


## 切换 BGM（双播放器交叉淡入淡出）。当前无播放时直接淡入。
func play_bgm(bgm_name: String) -> void:
	if not BGM_PATHS.has(bgm_name):
		return
	if bgm_name == _current_bgm_name and _current_bgm_player.playing:
		return
	var stream: AudioStream = _load_bgm(BGM_PATHS[bgm_name])
	if stream == null:
		return
	if not _current_bgm_player.playing:
		_set_bgm(bgm_name)
		return
	var old_player: AudioStreamPlayer = _current_bgm_player
	var new_player: AudioStreamPlayer = _next_bgm_player
	new_player.stream = stream
	new_player.volume_db = -40.0
	new_player.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_player, "volume_db", 0.0, BGM_CROSSFADE)
	tween.tween_property(old_player, "volume_db", -40.0, BGM_CROSSFADE)
	tween.chain().tween_callback(func() -> void: old_player.stop())
	# 交换角色
	_current_bgm_player = new_player
	_next_bgm_player = old_player
	_current_bgm_name = bgm_name


## Events.sfx_requested 的统一入口（UI 点击等显式请求）。
func _on_sfx_requested(sfx_name: String, data: Dictionary) -> void:
	play_sfx(sfx_name, data)


## 直接设定 BGM（无淡入，用于初始化）。
func _set_bgm(bgm_name: String) -> void:
	if not BGM_PATHS.has(bgm_name):
		return
	var stream: AudioStream = _load_bgm(BGM_PATHS[bgm_name])
	if stream == null:
		return
	_current_bgm_player.stream = stream
	_current_bgm_player.volume_db = 0.0
	_current_bgm_player.play()
	_current_bgm_name = bgm_name


# ============================================================
#  状态轮询 —— BGM 自动切换
# ============================================================

func _check_state_change() -> void:
	var state: String = run.state
	if state == _prev_state:
		return
	_prev_card_played = false
	var bgm_name: String = STATE_BGM.get(state, "")
	if not bgm_name.is_empty():
		play_bgm(bgm_name)
	# 进入选择界面时播放卡牌分发音效
	if state == "choice" or state == "opening":
		play_sfx("sfx_card_deal")
	_prev_state = state


func _check_boss_wave() -> void:
	## 首领先锋波 BGM 切换（仅在 playing 状态监测）
	if run.state != "playing":
		_prev_is_boss_wave = false
		return
	var is_boss: bool = run.waveDirector != null and run.waveDirector.isBossWave
	if is_boss and not _prev_is_boss_wave:
		play_bgm("boss")
		play_sfx("sfx_boss_alarm")
	elif not is_boss and _prev_is_boss_wave:
		# Boss 被击败，切回正常 BGM
		play_bgm("gameplay")
	_prev_is_boss_wave = is_boss


# ============================================================
#  状态轮询 —— 隐式音效触发
# ============================================================

func _check_enemies() -> void:
	## 检测敌人死亡（从 alive → dead）与首次受击
	var current_count: int = run.enemies.size()
	# 检测死亡：遍历上一帧还在的敌人，检查是否有新增 dead 标记
	var scan_end: int = mini(current_count, _prev_enemy_count)
	for i in scan_end:
		var enemy = run.enemies[i]
		if enemy.dead:
			var kind: String = enemy.get("type") if enemy.get("type") != null else "generic"
			var data: Dictionary = {"kind": kind, "rank": enemy.get("rank") if "rank" in enemy else "normal"}
			play_sfx("sfx_enemy_death", data)
			if enemy.get("rank") == "boss":
				play_sfx("sfx_boss_roar", {"no_pitch_variance": true})
		elif enemy.hitFlash > 0.0 and enemy.hitFlash <= 0.14:
			# hitFlash 在 damage_enemy 中被设为 0.14，首帧即为命中瞬间
			play_sfx("sfx_enemy_hit")
	_prev_enemy_count = current_count


func _check_gems() -> void:
	## 宝石拾取（数组缩短 = 有宝石被收集/消失）
	var current: int = run.gems.size()
	if current < _prev_gem_count:
		var collected: int = _prev_gem_count - current
		# 一次收集多颗宝石时用稍高音调，增加愉悦感
		var pitch: float = clampf(1.0 + float(collected - 1) * 0.05, 1.0, 1.5)
		play_sfx("sfx_gem_pickup", {"pitch": pitch})
	_prev_gem_count = current


func _check_pickups() -> void:
	## 拾取物收集（HP / 稀有遗物）
	var current: int = run.pickups.size()
	if current < _prev_pickup_count:
		# 扫描最近消失的拾取物，判断类型
		for i in mini(current, _prev_pickup_count):
			var pickup: Dictionary = run.pickups[i] if i < run.pickups.size() else {}
			if pickup.is_empty():
				continue
			var kind: String = pickup.get("kind", pickup.get("type", ""))
			if kind == "rare":
				play_sfx("sfx_rare_pickup", {"no_pitch_variance": true})
			else:
				play_sfx("sfx_hp_pickup")
	_prev_pickup_count = current


func _check_player() -> void:
	## 玩家受击 / 死亡
	var current_hp: float = run.player.hp
	if _prev_player_hp >= 0.0 and current_hp < _prev_player_hp:
		play_sfx("sfx_player_hurt")
		if current_hp <= 0.0:
			play_sfx("sfx_player_death", {"no_pitch_variance": true})
	_prev_player_hp = current_hp


func _check_level_up() -> void:
	## 升级音效
	if run.level > _prev_level:
		play_sfx("sfx_level_up", {"no_pitch_variance": true})
	_prev_level = run.level


# ============================================================
#  内部工具
# ============================================================

func _is_throttled(sfx_name: String) -> bool:
	var interval: float = _throttle_intervals.get(sfx_name, 0.0)
	if interval <= 0.0:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = _throttle_times.get(sfx_name, -999.0)
	if now - last < interval:
		return true
	_throttle_times[sfx_name] = now
	return false


func _find_free_sfx_player() -> AudioStreamPlayer:
	# 优先找空闲播放器
	for player in _sfx_pool:
		if not player.playing:
			return player
	# 全部占用时，找播放时间最长的（避免截断刚启动的音效）
	var oldest: AudioStreamPlayer = _sfx_pool[0]
	var oldest_time: float = 0.0
	for player in _sfx_pool:
		var pos: float = player.get_playback_position()
		if pos > oldest_time:
			oldest_time = pos
			oldest = player
	return oldest


func _load_sfx(path: String) -> AudioStream:
	if _sfx_cache.has(path):
		return _sfx_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_sfx_cache[path] = stream
	return stream


func _load_bgm(path: String) -> AudioStream:
	if _bgm_cache.has(path):
		return _bgm_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_bgm_cache[path] = stream
	return stream


func _cleanup_throttle() -> void:
	## 清除超过 10 秒未使用的节流条目，防止字典无限增长
	var now: float = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[String] = []
	for key: String in _throttle_times:
		if now - _throttle_times[key] > 10.0:
			to_remove.append(key)
	for key: String in to_remove:
		_throttle_times.erase(key)
