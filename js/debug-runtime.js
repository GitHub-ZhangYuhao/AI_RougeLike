import { CONFIG } from './config.js';
import { WEAPON_CARDS } from './cards.js';

const DEFAULT_SETTINGS = Object.freeze({
  paused: false,
  invincible: false,
  player: Object.freeze({
    damageMult: 1,
    xpMult: 1,
    moveSpeedMult: 1,
    maxHpMult: 1,
    pickupRangeMult: 1,
    armorBonus: 0,
  }),
  enemy: Object.freeze({
    hpMult: 1,
    damageMult: 1,
    speedMult: 1,
  }),
  spawn: Object.freeze({
    quotaMult: 1,
    aliveCap: null,
    intervalMult: 1,
    paused: false,
  }),
});

const ENEMY_TYPES = new Set(Object.keys(CONFIG.enemyTypes));
const WEAPON_BY_ID = new Map(WEAPON_CARDS.map((card) => [card.id, card]));
const ENEMY_DEBUG_BASE = Symbol('enemyDebugBase');

function cloneDefaults() {
  return {
    paused: DEFAULT_SETTINGS.paused,
    invincible: DEFAULT_SETTINGS.invincible,
    player: { ...DEFAULT_SETTINGS.player },
    enemy: { ...DEFAULT_SETTINGS.enemy },
    spawn: { ...DEFAULT_SETTINGS.spawn },
  };
}

function finiteNumber(value, fallback, minimum = -Infinity, maximum = Infinity) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(maximum, Math.max(minimum, number));
}

function booleanValue(value) {
  return value === true;
}

function normalizedPartial(source, schema, limits = {}) {
  if (!source || typeof source !== 'object') return {};
  const result = {};
  for (const key of Object.keys(schema)) {
    if (!(key in source)) continue;
    const limit = limits[key] ?? {};
    result[key] = finiteNumber(source[key], schema[key], limit.min, limit.max);
  }
  return result;
}

export class DebugRuntime {
  constructor(game) {
    this.game = game;
    this.settings = cloneDefaults();
    this.weaponLevels = {};
    this.weaponBaselines = {};
    this.appliedPlayerMaxHpMult = 1;
  }

  setPaused(value) {
    this.settings.paused = booleanValue(value);
    return this.settings.paused;
  }

  setInvincible(value) {
    this.settings.invincible = booleanValue(value);
    return this.settings.invincible;
  }

  setPlayerHp(value) {
    const player = this.game.player;
    if (!player) return 0;
    player.hp = finiteNumber(value, player.hp, 0, player.maxHp);
    return player.hp;
  }

  setPlayerSettings(partial = {}) {
    const next = normalizedPartial(partial, this.settings.player, {
      damageMult: { min: 0, max: 1000 },
      xpMult: { min: 0, max: 1000 },
      moveSpeedMult: { min: 0, max: 100 },
      maxHpMult: { min: 0.01, max: 1000 },
      pickupRangeMult: { min: 0, max: 1000 },
      armorBonus: { min: 0, max: 1_000_000 },
    });
    Object.assign(this.settings.player, next);
    this.game.recomputeMods();
    return { ...this.settings.player };
  }

  setWeaponLevel(id, level) {
    const card = WEAPON_BY_ID.get(id);
    if (!card) return false;

    const requested = Math.floor(finiteNumber(level, 0, 0, 6));
    const normalizedLevel = Math.min(requested, card.maxLevel ?? 6);
    if (!Object.hasOwn(this.weaponBaselines, id)) {
      const current = this.game.weapons.find((weapon) => weapon.card?.id === id);
      this.weaponBaselines[id] = current?.level ?? 0;
    }
    this.weaponLevels[id] = normalizedLevel;
    this._applyWeaponLevel(card, normalizedLevel);
    return normalizedLevel;
  }

  grantXp(amount) {
    const granted = finiteNumber(amount, 0, 0, 1_000_000_000);
    if (granted > 0) this.game.gainXp(granted, { applyMultiplier: false });
    return granted;
  }

  setEnemyMultipliers(partial = {}) {
    const next = normalizedPartial(partial, this.settings.enemy, {
      hpMult: { min: 0.01, max: 1000 },
      damageMult: { min: 0, max: 1000 },
      speedMult: { min: 0, max: 1000 },
    });
    Object.assign(this.settings.enemy, next);
    for (const enemy of this.game.enemies) this.applyEnemyMultipliers(enemy);
    return { ...this.settings.enemy };
  }

  setSpawnSettings(partial = {}) {
    if (partial && typeof partial === 'object') {
      const next = normalizedPartial(partial, this.settings.spawn, {
        quotaMult: { min: 0, max: 1000 },
        intervalMult: { min: 0.01, max: 1000 },
      });
      delete next.aliveCap;
      Object.assign(this.settings.spawn, next);

      if ('aliveCap' in partial) {
        this.settings.spawn.aliveCap = partial.aliveCap == null
          ? null
          : Math.floor(finiteNumber(partial.aliveCap, 0, 0, 10_000));
      }
      if ('paused' in partial) this.settings.spawn.paused = booleanValue(partial.paused);
    }
    this.game.waveDirector?.applySpawnSettings(this.settings.spawn);
    return { ...this.settings.spawn };
  }

  setWave(wave) {
    const normalizedWave = Math.floor(finiteNumber(wave, 1, 1, 100_000));
    this.clearEnemies();
    this.game.waveDirector.startWave(this.game, normalizedWave);
    this.game.waveDirector.applySpawnSettings(this.settings.spawn);
    return this.game.waveDirector.wave;
  }

  nextWave() {
    return this.setWave((this.game.waveDirector?.wave ?? 0) + 1);
  }

  spawnEnemies(type, count = 1) {
    if (!ENEMY_TYPES.has(type)) return [];
    const total = Math.floor(finiteNumber(count, 1, 1, 200));
    const spawned = [];
    const viewW = this.game._viewW ?? 1280;
    const viewH = this.game._viewH ?? 720;
    const wave = this.game.waveDirector?.wave ?? 1;

    for (let index = 0; index < total; index++) {
      const enemy = this.game.spawner.spawnType(
        type,
        this.game.elapsed,
        this.game.enemies,
        this.game.camera,
        viewW,
        viewH,
        { wave, debug: this },
      );
      if (enemy) spawned.push(enemy);
    }
    return spawned;
  }

  clearEnemies() {
    const count = this.game.enemies.length;
    this.game.enemies.length = 0;
    this.game.hostileProjectiles.length = 0;
    return count;
  }

  resetDefaults() {
    this.settings = cloneDefaults();
    for (const enemy of this.game.enemies) this.applyEnemyMultipliers(enemy);
    this.game.recomputeMods();
    this.game.waveDirector?.applySpawnSettings(this.settings.spawn);
    for (const [id, level] of Object.entries(this.weaponBaselines)) {
      const card = WEAPON_BY_ID.get(id);
      if (card) this._applyWeaponLevel(card, level);
    }
    this.weaponLevels = {};
    this.weaponBaselines = {};
    return this.serialize();
  }

  serialize() {
    const weaponLevels = {};
    for (const card of WEAPON_CARDS) {
      const weapon = this.game.weapons.find((entry) => entry.card?.id === card.id);
      if (weapon) weaponLevels[card.id] = weapon.level;
    }
    return {
      version: 1,
      settings: {
        paused: this.settings.paused,
        invincible: this.settings.invincible,
        player: { ...this.settings.player },
        enemy: { ...this.settings.enemy },
        spawn: { ...this.settings.spawn },
      },
      weaponLevels,
      wave: this.game.waveDirector?.wave ?? 1,
    };
  }

  applySerialized(data) {
    let parsed = data;
    if (typeof data === 'string') {
      try {
        parsed = JSON.parse(data);
      } catch {
        return false;
      }
    }
    if (!parsed || typeof parsed !== 'object') return false;

    this.resetDefaults();
    const settings = parsed.settings ?? parsed;
    this.setPaused(settings.paused);
    this.setInvincible(settings.invincible);
    this.setPlayerSettings(settings.player);
    this.setEnemyMultipliers(settings.enemy);
    this.setSpawnSettings(settings.spawn);

    const levels = parsed.weaponLevels ?? {};
    if (levels && typeof levels === 'object') {
      for (const [id, level] of Object.entries(levels)) this.setWeaponLevel(id, level);
    }
    if (parsed.wave != null) this.setWave(parsed.wave);
    return this.serialize();
  }

  onGameReset() {
    this.appliedPlayerMaxHpMult = 1;
    this.game.recomputeMods();
    this.game.waveDirector?.applySpawnSettings(this.settings.spawn);
    for (const [id, level] of Object.entries(this.weaponLevels)) {
      this.weaponBaselines[id] = 0;
      const card = WEAPON_BY_ID.get(id);
      if (card) this._applyWeaponLevel(card, level);
    }
  }

  syncPlayerMaxHp() {
    const player = this.game.player;
    if (!player) return;
    const previousMaxHp = Math.max(0.0001, player.maxHp || CONFIG.player.maxHp);
    const hpRatio = Math.max(0, player.hp) / previousMaxHp;
    const nextMult = this.settings.player.maxHpMult;
    const scale = nextMult / Math.max(0.0001, this.appliedPlayerMaxHpMult);
    player.maxHp = Math.max(1, previousMaxHp * scale);
    player.hp = Math.min(player.maxHp, player.maxHp * hpRatio);
    this.appliedPlayerMaxHpMult = nextMult;
  }

  applyEnemyMultipliers(enemy) {
    if (!enemy) return enemy;
    if (!enemy[ENEMY_DEBUG_BASE]) {
      Object.defineProperty(enemy, ENEMY_DEBUG_BASE, {
        configurable: true,
        value: {
          hpMult: 1,
          damageMult: 1,
          speedMult: 1,
          unscaledDamage: enemy.damage,
          unscaledSpeed: enemy.speed,
        },
      });
    }

    const applied = enemy[ENEMY_DEBUG_BASE];
    const next = this.settings.enemy;
    const hpRatio = enemy.maxHp > 0 ? Math.max(0, enemy.hp) / enemy.maxHp : 1;
    const hpScale = next.hpMult / Math.max(0.0001, applied.hpMult);
    enemy.maxHp = Math.max(0.0001, enemy.maxHp * hpScale);
    enemy.hp = Math.min(enemy.maxHp, enemy.maxHp * hpRatio);

    if (applied.damageMult > 0) applied.unscaledDamage = enemy.damage / applied.damageMult;
    if (applied.speedMult > 0) applied.unscaledSpeed = enemy.speed / applied.speedMult;
    enemy.damage = applied.unscaledDamage * next.damageMult;
    enemy.speed = applied.unscaledSpeed * next.speedMult;
    applied.hpMult = next.hpMult;
    applied.damageMult = next.damageMult;
    applied.speedMult = next.speedMult;
    return enemy;
  }

  _applyWeaponLevel(card, level) {
    const matching = this.game.weapons.filter((weapon) => weapon.card?.id === card.id);
    if (level <= 0) {
      this.game.weapons = this.game.weapons.filter((weapon) => weapon.card?.id !== card.id);
      this.game.synergies?.refresh(this.game.weapons, this.game.elapsed);
      return;
    }

    const weapon = matching[0] ?? card.create();
    weapon.level = level;
    if (matching.length === 0) this.game.weapons.push(weapon);
    if (matching.length > 1) {
      let kept = false;
      this.game.weapons = this.game.weapons.filter((candidate) => {
        if (candidate.card?.id !== card.id) return true;
        if (!kept) { kept = true; return true; }
        return false;
      });
    }
    this.game.synergies?.refresh(this.game.weapons, this.game.elapsed);
  }
}

export { DEFAULT_SETTINGS as DEBUG_DEFAULT_SETTINGS };
export default DebugRuntime;
