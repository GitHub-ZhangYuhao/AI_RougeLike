extends RefCounted

const ENEMY_TEXTURES: Dictionary = {
  'chaser': preload('res://assets/sprites/enemies/chaser.png'),
  'enhancedChaser': preload('res://assets/sprites/enemies/enhanced_chaser.png'),
  'charger': preload('res://assets/sprites/enemies/charger.png'),
  'ranged': preload('res://assets/sprites/enemies/ranged.png'),
  'bomber': preload('res://assets/sprites/enemies/bomber.png'),
  'shield': preload('res://assets/sprites/enemies/shield.png'),
  'boss': preload('res://assets/sprites/enemies/boss.png'),
}

const WEAPON_ICONS: Dictionary = {
  'sword': preload('res://assets/icons/weapon_sword.png'),
  'talisman': preload('res://assets/icons/weapon_talisman.png'),
  'cloak': preload('res://assets/icons/weapon_cloak.png'),
  'trail': preload('res://assets/icons/weapon_trail.png'),
  'ring': preload('res://assets/icons/weapon_ring.png'),
  'staff': preload('res://assets/icons/weapon_staff.png'),
}

const PROJECTILE_TEXTURES: Dictionary = {
  'sword': preload('res://assets/icons/projectile_sword.png'),
  'talisman': preload('res://assets/icons/projectile_talisman.png'),
  'cloak': preload('res://assets/icons/projectile_fire.png'),
  'trail': preload('res://assets/icons/projectile_fire.png'),
  'ring': preload('res://assets/icons/weapon_ring.png'),
  'staff': preload('res://assets/vfx/staff_spirit_bolt.png'),
  'hostile': preload('res://assets/icons/projectile_hostile.png'),
}

const PICKUP_TEXTURES: Dictionary = {
  'gem': preload('res://assets/icons/pickup_gem.png'),
  'health': preload('res://assets/icons/pickup_health.png'),
}

const RARE_TEXTURES: Dictionary = {
  'warRune': preload('res://assets/icons/rare_war_rune.png'),
  'bloodJade': preload('res://assets/icons/rare_blood_jade.png'),
  'magnetCore': preload('res://assets/icons/rare_magnet_core.png'),
  'spiritBook': preload('res://assets/icons/rare_spirit_book.png'),
  'windFeather': preload('res://assets/icons/rare_wind_feather.png'),
}

const SUMMON_TEXTURES: Dictionary = {
  'normal': preload('res://assets/icons/summon_wood_guardian.png'),
  'corpse': preload('res://assets/icons/summon_root_skeleton.png'),
  'ward': preload('res://assets/icons/summon_jade_guard.png'),
  'wisp': preload('res://assets/icons/summon_wisp.png'),
}

const TASK_TEXTURES: Dictionary = {
  'guard': preload('res://assets/icons/task_guard.png'),
  'delivery': preload('res://assets/icons/task_delivery.png'),
  'bounty': preload('res://assets/icons/task_bounty.png'),
}

const VFX_TEXTURES: Dictionary = {
  'swordSlash': preload('res://assets/vfx/sword_slash.png'),
  'talismanLightning': preload('res://assets/vfx/talisman_lightning.png'),
  'cloakFireBurst': preload('res://assets/vfx/cloak_fire_burst.png'),
  'furnaceFlame': preload('res://assets/vfx/furnace_flame.png'),
  'jadeRingTrail': preload('res://assets/vfx/jade_ring_trail.png'),
  'staffSpiritBolt': preload('res://assets/vfx/staff_spirit_bolt.png'),
  'explosion': preload('res://assets/vfx/explosion.png'),
  'freeze': preload('res://assets/vfx/freeze_burst.png'),
  'poison': preload('res://assets/vfx/poison_mist.png'),
  'dot': preload('res://assets/vfx/dot_curse.png'),
  'healing': preload('res://assets/vfx/healing_petals.png'),
  'pickup': preload('res://assets/vfx/pickup_glow.png'),
  'bossEnraged': preload('res://assets/vfx/boss_enraged.png'),
  'taskBeacon': preload('res://assets/vfx/task_beacon.png'),
  'synergyArc': preload('res://assets/vfx/synergy_arc.png'),
  'impact': preload('res://assets/vfx/impact_flash.png'),
}

const ENVIRONMENT_TEXTURES: Dictionary = {
  'peachTreeLarge': preload('res://assets/environment/peach_tree_large.png'),
  'peachTreeMedium': preload('res://assets/environment/peach_tree_medium.png'),
  'peachTreeSmall': preload('res://assets/environment/peach_tree_small.png'),
  'boulderCluster': preload('res://assets/environment/boulder_cluster.png'),
  'boundaryStone': preload('res://assets/environment/boundary_stone.png'),
  'shrub': preload('res://assets/environment/shrub.png'),
  'grassTuft': preload('res://assets/environment/grass_tuft.png'),
  'wildflowers': preload('res://assets/environment/wildflowers.png'),
  'lanternPost': preload('res://assets/environment/lantern_post.png'),
  'roadsideShrine': preload('res://assets/environment/roadside_shrine.png'),
  'boundaryPillar': preload('res://assets/environment/boundary_pillar.png'),
  'fallenPetals': preload('res://assets/environment/fallen_petals.png'),
}

const UI_TEXTURES: Dictionary = {
  'brandMascot': preload('res://assets/ui/modern/brand_mascot.png'),
  'panelCorner': preload('res://assets/ui/modern/panel_corner.png'),
  'divider': preload('res://assets/ui/modern/divider_blossom.png'),
  'buttonCrest': preload('res://assets/ui/modern/button_crest.png'),
  'focusCursor': preload('res://assets/ui/modern/focus_cursor.png'),
  'sealWeapon': preload('res://assets/ui/modern/seal_weapon.png'),
  'sealAttribute': preload('res://assets/ui/modern/seal_attribute.png'),
  'sealBlessing': preload('res://assets/ui/modern/seal_blessing.png'),
  'sealTask': preload('res://assets/ui/modern/seal_task.png'),
  'boss': preload('res://assets/ui/modern/medallion_boss.png'),
  'shop': preload('res://assets/ui/modern/medallion_shop.png'),
  'warehouse': preload('res://assets/ui/modern/medallion_warehouse.png'),
  'pause': preload('res://assets/ui/modern/medallion_pause.png'),
}
