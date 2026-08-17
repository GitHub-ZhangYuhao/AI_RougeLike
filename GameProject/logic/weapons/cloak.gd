extends "res://logic/weapons/weapon_base.gd"
## ← js/weapons/cloak.js：持续光环与击杀阈值强化冲击。


const CARD: Dictionary = {"id": "cloak", "kind": "weapon", "name": "炽热披风", "maxLevel": 6, "levels": [
    {"damage": 5, "radius": 145},
    {"damage": 7, "radius": 165, "burn": true, "burnDps": 10},
    {"damage": 10, "radius": 185, "burn": true, "burnDps": 12},
    {"damage": 12, "radius": 205, "burn": true, "burnDps": 14, "shock": true, "shockCd": 5.5, "shockTicks": 6, "shockRadiusMult": 1.7},
    {"damage": 15, "radius": 225, "burn": true, "burnDps": 16, "shock": true, "shockCd": 5.2, "shockTicks": 6, "shockRadiusMult": 1.7},
    {"damage": 18, "radius": 250, "burn": true, "burnDps": 16, "shock": true, "shockCd": 3, "shockTicks": 6, "shockRadiusMult": 1.8, "shockSlow": true, "enhancedKillShock": true},
]}

var shock_timer: float = 0.0
var shocks: Array = []
var last_kills: int = -1


func update(dt: float, current_world) -> void:
    world = current_world
    var s: Dictionary = stats
    timer -= dt
    if timer <= 0.0:
        timer = 0.5
        var damage: float = s["damage"] * current_world.mods["damageMult"]
        for enemy in current_world.enemies:
            if enemy.dead or UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) > pow(s["radius"] + enemy.radius, 2):
                continue
            current_world.damage_enemy.call(enemy, damage, {"sourceWeaponId": "cloak", "sourceAction": "aura"})
            if s.get("burn", false) and not enemy.dead:
                current_world.apply_dot.call(enemy, "burn", s["burnDps"] * current_world.mods["damageMult"], 2.0)

    if s.get("shock", false):
        if s.get("enhancedKillShock", false) and last_kills >= 0:
            var previous: int = floori(float(last_kills) / 100.0)
            var current: int = floori(float(current_world.kills) / 100.0)
            for ignored in range(previous, current):
                fire_shock(current_world, true)
        shock_timer -= dt
        if shock_timer <= 0.0:
            shock_timer = s["shockCd"]
            fire_shock(current_world, false)
    last_kills = current_world.kills

    for shock: Dictionary in shocks:
        shock["t"] += dt
    shocks = shocks.filter(func(shock: Dictionary) -> bool: return shock["t"] < shock["ttl"])


func fire_shock(current_world, enhanced: bool = false) -> void:
    var s: Dictionary = stats
    var radius_mult: float = 1.8 if enhanced else s["shockRadiusMult"]
    var ticks: int = 8 if enhanced else s["shockTicks"]
    # JS 真值：Lv4/5 普通 shock 不减速；仅 Lv6 普通与强化 shock 减速。
    var slow_duration: float = 3.0 if enhanced else (2.0 if s.get("shockSlow", false) else 0.0)
    var radius: float = s["radius"] * radius_mult
    var damage: float = s["damage"] * ticks * current_world.mods["damageMult"]
    for enemy in current_world.enemies:
        if enemy.dead or UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) > pow(radius + enemy.radius, 2):
            continue
        current_world.damage_enemy.call(enemy, damage, {"sourceWeaponId": "cloak", "sourceAction": "enhanced-shock" if enhanced else "shock"})
        if enemy.dead:
            continue
        current_world.apply_dot.call(enemy, "burn", s.get("burnDps", 12) * current_world.mods["damageMult"], 2.0)
        if slow_duration > 0.0:
            current_world.apply_slow.call(enemy, 0.3, slow_duration)
    shocks.append({"x": current_world.player.x, "y": current_world.player.y, "max_r": radius,
        "t": 0.0, "ttl": 0.45, "enhanced": enhanced})
