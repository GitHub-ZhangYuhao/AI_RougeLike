export function weaponPairKey(weaponIds) {
  return [...weaponIds].sort().join('+');
}

const DEFINITIONS = [
  ['sword-talisman-mark', ['sword', 'talisman'], '雷剑引雷', '⚔️⚡', true],
  ['sword-ring-return', ['sword', 'ring'], '剑环折返', '⚔️💍', true],
  ['sword-cloak-flame', ['sword', 'cloak'], '焚刃', '⚔️🔥', true],
  ['sword-trail-cut', ['sword', 'trail'], '切炉', '⚔️🔥', true],
  ['sword-staff-command', ['sword', 'staff'], '御剑号令', '⚔️🦴', true],
  ['talisman-ring-relay', ['talisman', 'ring'], '雷环中继', '⚡💍', true],
  ['talisman-cloak-burst', ['talisman', 'cloak'], '雷火震荡', '⚡🔥', true],
  ['talisman-fire-alchemy', ['talisman', 'trail'], '雷火炼化', '⚡🔥', true],
  ['talisman-staff-corpse-relay', ['talisman', 'staff'], '尸雷跳板', '⚡🦴', true],
  ['ring-cloak-burning', ['ring', 'cloak'], '灼热玉环', '💍🔥', true],
  ['ring-trail-charge', ['ring', 'trail'], '蓄炉玉', '💍🔥', true],
  ['ring-staff-guardian', ['ring', 'staff'], '护法玉', '💍🦴', true],
  ['cloak-trail-core', ['cloak', 'trail'], '内外火域', '🔥🔥', true],
  ['cloak-staff-ghostfire', ['cloak', 'staff'], '鬼火护卫', '🔥🦴', true],
  ['trail-staff-corpse-fire', ['trail', 'staff'], '尸火炼丹', '🔥🦴', true],
];

export const SYNERGY_DEFINITIONS = Object.freeze(DEFINITIONS.map(([id, weaponIds, name, icon, implemented]) => Object.freeze({
  id,
  weaponIds: Object.freeze([...weaponIds].sort()),
  pairKey: weaponPairKey(weaponIds),
  minLevel: 4,
  name,
  icon,
  implemented,
})));


export class SynergySystem {
  constructor() {
    this.activeIds = new Set();
    this.runtime = new Map();
    this.announcement = null;
    this.weaponSignature = '';
    this.cooldowns = new Map();
    this.selectedWeaponIds = [];
  }

  refresh(weapons, elapsed = 0) {
    const levels = new Map();
    for (const weapon of weapons) levels.set(weapon.card.id, weapon.level);
    this.selectedWeaponIds = this.selectedWeaponIds
      .filter((id, index, ids) => levels.has(id) && ids.indexOf(id) === index)
      .slice(-2);
    const selectedPairKey = this.selectedWeaponIds.length === 2
      ? weaponPairKey(this.selectedWeaponIds)
      : null;
    const signature = [...levels.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([id, level]) => `${id}:${level}`)
      .join('|') + `#${selectedPairKey ?? this.selectedWeaponIds[0] ?? ''}`;
    if (signature === this.weaponSignature) return false;
    this.weaponSignature = signature;

    const next = new Set();
    for (const definition of SYNERGY_DEFINITIONS) {
      if (!definition.implemented) continue;
      if (selectedPairKey && definition.pairKey !== selectedPairKey) continue;
      if (definition.weaponIds.every((id) => (levels.get(id) ?? 0) >= definition.minLevel)) {
        next.add(definition.id);
      }
    }

    for (const id of next) {
      if (this.activeIds.has(id)) continue;
      const definition = SYNERGY_DEFINITIONS.find((entry) => entry.id === id);
      this.runtime.set(id, {
        activatedAt: elapsed,
        triggerCount: 0,
        contribution: 0,
      });
      this.announcement = {
        text: `联动激活 · ${definition.name}`,
        detail: definition.icon,
        color: '#80deea',
        ttl: 3,
        maxTtl: 3,
      };
    }

    for (const id of this.activeIds) {
      if (!next.has(id)) this.runtime.delete(id);
    }
    this.activeIds = next;
    return true;
  }

  update(dt) {
    if (!this.announcement) return;
    this.announcement.ttl -= dt;
    if (this.announcement.ttl <= 0) this.announcement = null;
  }

  toggleBuildWeapon(weaponId, weapons, elapsed = 0) {
    if (!weapons.some((weapon) => weapon.card.id === weaponId)) return false;
    const selectedIndex = this.selectedWeaponIds.indexOf(weaponId);
    if (selectedIndex >= 0) {
      this.selectedWeaponIds.splice(selectedIndex, 1);
    } else {
      if (this.selectedWeaponIds.length >= 2) this.selectedWeaponIds.pop();
      this.selectedWeaponIds.push(weaponId);
    }

    this.weaponSignature = '';
    this.refresh(weapons, elapsed);
    const definition = this.selectedDefinition;
    const selectedWeaponId = this.selectedWeaponIds[0];
    const selectedWeapon = weapons.find((entry) => entry.card.id === selectedWeaponId);
    let text = 'Build 选择';
    let detail = this.selectedWeaponIds.length === 0
      ? '已恢复自动联动'
      : `已选 ${selectedWeapon?.card.name ?? selectedWeaponId}`;
    let color = '#ffd54f';

    if (this.selectedWeaponIds.length === 1) {
      detail = `已选 ${selectedWeapon?.card.name ?? selectedWeaponId}，再选一把武器`;
    } else if (definition) {
      text = `Build · ${definition.name}`;
      if (!definition.implemented) {
        detail = '联动效果尚未实装';
        color = '#b0bec5';
      } else if (!this.isActive(definition.id)) {
        detail = '需要两把武器都达到 Lv4';
      } else {
        detail = '已锁定该联动';
        color = '#80deea';
      }
    }

    this.announcement = { text, detail, color, ttl: 2.5, maxTtl: 2.5 };
    return true;
  }

  isBuildWeaponSelected(weaponId) {
    return this.selectedWeaponIds.includes(weaponId);
  }

  get selectedDefinition() {
    if (this.selectedWeaponIds.length !== 2) return null;
    const pairKey = weaponPairKey(this.selectedWeaponIds);
    return SYNERGY_DEFINITIONS.find((definition) => definition.pairKey === pairKey) ?? null;
  }

  isActive(id) {
    return this.activeIds.has(id);
  }

  get activeDefinitions() {
    return SYNERGY_DEFINITIONS.filter((definition) => this.activeIds.has(definition.id));
  }

  getRuntime(id) {
    return this.runtime.get(id) ?? null;
  }

  recordTrigger(id, contribution = 0) {
    const state = this.runtime.get(id);
    if (!state) return;
    state.triggerCount++;
    state.contribution += contribution;
  }

  onDamage(event, world) {
    if (event.options.noSynergy || event.options.sourceWeaponId !== 'talisman') return;
    if (!event.options.sourceTags?.includes('lightning')) return;
    this._triggerLightningFireBurst(event, world);
    this._chargeLightningFurnace(event, world);
  }

  _triggerLightningFireBurst(event, world) {
    if (!this.isActive('talisman-cloak-burst')) return;
    if (event.options.sourceAction !== 'thunder') return;
    if (!(event.target.dots?.burn?.timer > 0)) return;

    event.target.synergyCooldowns ??= {};
    const readyAt = event.target.synergyCooldowns.talismanCloakBurst ?? -Infinity;
    if (world.elapsed < readyAt) return;
    event.target.synergyCooldowns.talismanCloakBurst = world.elapsed + 0.9;

    const radius = 80;
    const damage = event.damage * 0.45;
    let hits = 0;
    for (const enemy of world.enemies) {
      if (enemy.dead) continue;
      const dx = enemy.x - event.target.x;
      const dy = enemy.y - event.target.y;
      if (dx * dx + dy * dy > (radius + enemy.radius) ** 2) continue;
      world.damageEnemy(enemy, damage, {
        sourceWeaponId: 'talisman',
        sourceAction: 'lightning-fire-burst',
        sourceTags: ['lightning', 'fire', 'area'],
        synergyId: 'talisman-cloak-burst',
        noSynergy: true,
        noSummon: true,
      });
      hits++;
    }
    this.recordTrigger('talisman-cloak-burst', damage * hits);
    world.effects.push({
      type: 'synergyBurst',
      style: 'lightningFire',
      x: event.target.x,
      y: event.target.y,
      radius,
      color: '#ff8a50',
      accent: '#fff176',
      ttl: 0.32,
      maxTtl: 0.32,
    });
  }

  _chargeLightningFurnace(event, world) {
    if (!this.isActive('talisman-fire-alchemy')) return;
    if (event.options.sourceAction !== 'thunder' && event.options.sourceAction !== 'chain') return;

    const readyAt = this.cooldowns.get('talisman-fire-alchemy') ?? -Infinity;
    if (world.elapsed < readyAt) return;
    const trail = world.getWeapon('trail');
    if (!trail || typeof trail.chargeFurnaceAt !== 'function') return;

    const amount = event.options.sourceAction === 'thunder' ? 2 : 0.75;
    const zone = trail.chargeFurnaceAt(event.target.x, event.target.y, amount, world);
    if (!zone) return;

    this.cooldowns.set('talisman-fire-alchemy', world.elapsed + 0.18);
    this.recordTrigger('talisman-fire-alchemy', amount);
    world.effects.push({
      type: 'synergyArc',
      x1: event.target.x,
      y1: event.target.y,
      x2: zone.center.x,
      y2: zone.center.y,
      color: '#80deea',
      ttl: 0.22,
      maxTtl: 0.22,
    });
    world.effects.push({
      type: 'synergyBurst',
      style: 'alchemy',
      x: zone.center.x,
      y: zone.center.y,
      radius: 34,
      color: '#ff8a50',
      accent: '#80deea',
      ttl: 0.26,
      maxTtl: 0.26,
    });
  }
}
