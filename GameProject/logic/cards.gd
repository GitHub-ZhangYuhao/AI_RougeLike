extends RefCounted
## ← js/cards.js：武器/属性卡池与属性合成。

const SwordScript: GDScript = preload("res://logic/weapons/sword.gd")
const CloakScript: GDScript = preload("res://logic/weapons/cloak.gd")
const TalismanScript: GDScript = preload("res://logic/weapons/talisman.gd")
const TrailScript: GDScript = preload("res://logic/weapons/trail.gd")
const RingScript: GDScript = preload("res://logic/weapons/ring.gd")
const StaffScript: GDScript = preload("res://logic/weapons/staff.gd")

const WEAPON_CARDS: Array[Dictionary] = [SwordScript.CARD, CloakScript.CARD, TalismanScript.CARD, TrailScript.CARD, RingScript.CARD, StaffScript.CARD]
const ATTR_CARDS: Array[Dictionary] = [
    {"id": "damage", "kind": "attr", "name": "伤害提升"},
    {"id": "armor", "kind": "attr", "name": "护甲提升"},
    {"id": "magnet", "kind": "attr", "name": "拾取范围"},
    {"id": "xp", "kind": "attr", "name": "经验倍率"},
    {"id": "maxHp", "kind": "attr", "name": "血量提升"},
    {"id": "moveSpeed", "kind": "attr", "name": "移动速度"},
]
const WEAPON_LEVEL_BENEFITS: Dictionary = {
    "sword": [
        "近战扇形斩：伤害16，范围125",
        "伤害16→20，间隔1.15→1.08秒；解锁穿透2人的远程剑气",
        "伤害20→26，射程520→550，弹速500→560",
        "伤害26→32，间隔1.00→0.94秒；每命中3次释放流血环斩",
        "伤害32→40，穿透2→4；环斩范围350→380",
        "伤害40→48，剑气无限贯穿；每10次命中生成连锁飞剑",
    ],
    "cloak": [
        "火焰光环：每0.5秒造成5伤害，范围145",
        "伤害5→7，范围145→165；解锁持续灼烧",
        "伤害7→10，范围165→185；灼烧10→12/秒",
        "伤害10→12，范围185→205；每5.5秒释放烈焰冲击",
        "伤害12→15，范围205→225；冲击冷却5.5→5.2秒",
        "伤害15→18，范围225→250；冲击3秒一次并减速，百杀追加强化冲击",
    ],
    "talisman": [
        "自动索敌雷弹：伤害12，间隔1秒，射程520",
        "伤害12→15，间隔1.00→0.95秒；同目标两次命中引雷",
        "伤害15→19，间隔0.95→0.88秒",
        "伤害19→23，间隔0.88→0.81秒；解锁2段闪电链",
        "伤害23→27，间隔0.81→0.75秒",
        "伤害27→31，链数2→3；每发首击必落范围雷",
    ],
    "trail": [
        "移动铺设火径：伤害7，范围40，持续3.5秒",
        "伤害7→10，范围40→44，持续3.5→4.5秒；解锁灼烧",
        "伤害10→14，范围44→48；铺火间隔0.22→0.18秒",
        "伤害14→16，持续5.5→7秒；移动闭环可生成牵引丹炉",
        "伤害16→21，丹炉6→7.5秒；范围、牵引和开炉次数强化",
        "伤害21→26，丹炉7.5→9秒；开炉生成回血加速的九转热域",
    ],
    "ring": [
        "2枚玉环绕身：伤害12，轨道半径56",
        "伤害12→16，轨道56→66；解锁寒玉减速",
        "伤害16→20，玉环2→3，轨道66→78",
        "伤害20→26，玉环3→4；解锁扩张并在扩张期增伤50%",
        "伤害26→32，玉环4→5，扩张80→95",
        "伤害32→40，玉环5→6；百杀狂暴，受击释放冻结反制",
    ],
    "staff": [
        "召唤1名魂仆：伤害7，存活6秒，冷却4秒",
        "伤害7→9，魂仆1→2；解锁范围尸毒",
        "伤害9→12，存活6.8→7.5秒，冷却3.6→3.2秒",
        "伤害12→14，冷却3.2→2.8秒；魂仆退场时自爆",
        "伤害14→17，魂仆2→3；爆炸范围70→105",
        "伤害17→20，冷却2.5→2.2秒；解锁百鬼转化、强化与持续回血",
    ],
}


static func card_by_id(id: String) -> Dictionary:
    for card: Dictionary in WEAPON_CARDS + ATTR_CARDS:
        if card["id"] == id:
            return card
    return {}


static func weapon_level_benefit(id: String, level: int) -> String:
    var benefits: Array = WEAPON_LEVEL_BENEFITS.get(id, [])
    if level < 1 or level > benefits.size():
        return ""
    return benefits[level - 1]


static func compute_mods(attr_stacks: Dictionary, meta_stacks: Dictionary = {}) -> Dictionary:
    var mods: Dictionary = {"damageMult": 1.0, "xpMult": 1.0, "moveSpeedMult": 1.0,
        "armor": 0.0, "damageReduction": 0.0, "magnetRadiusBonus": 0.0,
        "maxHpBonus": 0.0, "projectileBonus": 0, "areaMult": 1.0,
        "attackSpeedMult": 1.0, "cooldownMult": 1.0}
    for card: Dictionary in ATTR_CARDS:
        var id: String = card["id"]
        var n: int = attr_stacks.get(id, 0) + meta_stacks.get(id, 0)
        if n <= 0:
            continue
        match id:
            "damage": mods["damageMult"] += 0.15 * n
            "armor": mods["armor"] += 15.0 * n
            "magnet": mods["magnetRadiusBonus"] += 50.0 * n
            "xp": mods["xpMult"] += 0.15 * n
            "maxHp": mods["maxHpBonus"] += 20.0 * n
            "moveSpeed": mods["moveSpeedMult"] += 0.06 * n
    mods["damageReduction"] = minf(0.5, mods["armor"] / (mods["armor"] + 100.0))
    return mods


static func opening_offers(_game = null) -> Array[Dictionary]:
    var offers: Array[Dictionary] = []
    for card: Dictionary in WEAPON_CARDS:
        offers.append({"card": card, "type": "new", "benefit": weapon_level_benefit(card["id"], 1)})
    return offers


static func generate_offers(game) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for weapon in game.weapons:
        if weapon.level < weapon.card["maxLevel"]:
            pool.append({"card": weapon.card, "type": "upgrade",
                "benefit": weapon_level_benefit(weapon.card["id"], weapon.level + 1)})
    if game.weapons.size() < Config.CONFIG["cards"]["maxWeaponSlots"]:
        for card: Dictionary in WEAPON_CARDS:
            var owned: bool = false
            for weapon in game.weapons:
                if weapon.card["id"] == card["id"]:
                    owned = true
                    break
            if not owned:
                pool.append({"card": card, "type": "new", "benefit": weapon_level_benefit(card["id"], 1)})
    for card: Dictionary in ATTR_CARDS:
        if game.attrStacks.get(card["id"], 0) < Config.CONFIG["cards"]["attrMaxStack"]:
            pool.append({"card": card, "type": "attr"})
    for i in range(pool.size() - 1, 0, -1):
        var j: int = floori(Rng.next() * (i + 1))
        var swap: Dictionary = pool[i]
        pool[i] = pool[j]
        pool[j] = swap
    return pool.slice(0, Config.CONFIG["cards"]["choicesCount"])
