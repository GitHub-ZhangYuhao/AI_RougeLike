import { CONFIG } from './config.js';
import { Camera } from './camera.js';
import { createPlayer, updatePlayer, hurtPlayer as applyPlayerDamage, drawPlayer } from './player.js';
import { updateEnemy, separateEnemies, drawEnemy } from './enemy.js';
import { Spawner } from './spawner.js';
import { WaveDirector } from './systems/waves.js';
import { SynergySystem } from './systems/synergies.js';
import { DebugRuntime } from './debug-runtime.js';
import { updateProjectile, drawProjectile } from './projectile.js';
import {
  createHostileProjectile, updateHostileProjectile, drawHostileProjectile,
} from './enemies/hostile-projectile.js';
import { updateTrail, drawTrail, drawSummon } from './weapons/index.js';
import { createGem, updateGem, drawGem } from './gems.js';
import { createRarePickup, applyRareItem, drawRarePickup } from './rare-items.js';
import { openingOffers, generateOffers, computeMods } from './cards.js';
import { drawHUD, drawGameOver, getWeaponSlotRects } from './hud.js';
import { rollBossDrops } from './meta/drops.js';
import { tryBuy } from './meta/shop.js';
import { META_ITEMS, META_ITEM_LIST } from './meta/items.js';
import { loadSave, persistSave } from './meta/save.js';
import {
  updateMenu, drawMenu, updateShop, drawShop, updateStorage, drawStorage,
  updateExtraction, drawExtraction, updateSummary, drawSummary,
} from './ui/meta-screens.js';
import { getCardRects, drawChoiceUI } from './ui-cards.js';
import { dist2 } from './utils.js';
import {
  tickStatus, drawStatus, applyDot, applySlow, applyFreeze, hasDot,
} from './systems/status.js';

// 游戏主状态机
// state: 'menu' 主菜单 | 'shop' 商城 | 'storage' 仓库 | 'opening' 开局选卡 | 'playing' 战斗中
//      | 'choice' 升级选卡 | 'extraction' 撤离抉择 | 'summary' 撤离/通关结算 | 'dead' 死亡
export class Game {
  constructor(input) {
    this.input = input;
    this.debug = new DebugRuntime(this);
    this.save = loadSave();
    this.lastRunSummary = null;
    this.lastDeathLoss = null;
    this.reset();
  }

  reset() {
    this.state = 'menu';
    this.elapsed = 0;
    this.kills = 0;

    // 等级与经验
    this.level = 1;
    this.xp = 0;
    this.pendingChoices = 0; // 待处理的选卡次数（可能一次升多级）
    // 卡牌：属性卡叠加层数 -> 全局乘数
    this.attrStacks = {};
    // 局外成长：本局临时背包（撤离入库、死亡全损）与商城永久属性（每级等效 1 层属性卡）
    this.tempBackpack = { shard: 0, essence: 0, soulCrystal: 0 };
    this.metaStacks = { ...this.save.metaLevels };
    this.rareInventory = {};
    this.rareBonuses = {
      damageMult: 1,
      xpMult: 1,
      moveSpeedMult: 1,
      magnetRadiusBonus: 0,
    };
    this.mods = computeMods(this.attrStacks, this.metaStacks);
    this.playerMoveSpeedBonuses = new Map();

    this.player = createPlayer(0, 0);
    this.camera = new Camera(0, 0);
    this.enemies = [];
    this.projectiles = [];
    this.hostileProjectiles = [];
    this.gems = [];
    this.trails = [];
    this.summons = [];
    this.effects = [];
    this.weapons = [];
    this.spawner = new Spawner();
    this.waveDirector = new WaveDirector();
    this.synergies = new SynergySystem();
    this.hitShake = 0;
    this.bossesDefeated = 0;
    this.rareMessage = null;

    // ---------- 击杀日志 / 尸体 / 掉落 ----------
    // killLog：最近击杀记录，供武器监听（丹火爆燃、死灵转化、击杀计数类质变）
    // 条目包含 burn/blaze 标记与 noSummon 伤害来源标记
    this.killLog = [];
    this.nextKillId = 1;
    this.corpses = [];  // 纯视觉血迹
    this.pickups = [];  // 地面掉落物（血包等）

    // 开局展示全部武器卡任选 1（槽位上限走 CONFIG.cards.maxWeaponSlots，不写死）
    this.choiceOrigin = 'opening';
    this.currentOffers = openingOffers();

    // The runtime object survives resets; its active settings and requested
    // weapon levels are reapplied to the fresh game state.
    this.debug?.onGameReset();
  }

  // ---------- 经验 / 等级 ----------
  xpToNext() {
    return CONFIG.xp.base + (this.level - 1) * CONFIG.xp.perLevel;
  }

  recomputeMods() {
    const mods = computeMods(this.attrStacks, this.metaStacks);
    const debugPlayer = this.debug?.settings.player;
    mods.damageMult *= this.rareBonuses.damageMult * (debugPlayer?.damageMult ?? 1);
    mods.xpMult *= this.rareBonuses.xpMult * (debugPlayer?.xpMult ?? 1);
    mods.moveSpeedMult *= this.rareBonuses.moveSpeedMult * (debugPlayer?.moveSpeedMult ?? 1);
    mods.armor += debugPlayer?.armorBonus ?? 0;
    mods.damageReduction = Math.min(0.5, mods.armor / (mods.armor + 100));

    this.mods = mods;
    this.debug?.syncPlayerMaxHp();
  }

  gemMagnetRadius() {
    const baseRadius = CONFIG.gems.magnetRadius
      + this.mods.magnetRadiusBonus
      + this.rareBonuses.magnetRadiusBonus;
    return baseRadius * (this.debug?.settings.player.pickupRangeMult ?? 1);
  }

  // Short-lived speed bonuses multiply with existing attribute and rare-item movement sources.
  setPlayerMoveSpeedBonus(source, multiplier, duration = 0.12) {
    if (!source || !Number.isFinite(multiplier) || multiplier <= 0) return;
    this.playerMoveSpeedBonuses.set(source, {
      multiplier,
      expiresAt: this.elapsed + Math.max(0, duration),
    });
  }

  playerMoveSpeedBonusMult() {
    let multiplier = 1;
    for (const [source, bonus] of this.playerMoveSpeedBonuses) {
      if (bonus.expiresAt < this.elapsed) {
        this.playerMoveSpeedBonuses.delete(source);
        continue;
      }
      multiplier *= bonus.multiplier;
    }
    return multiplier;
  }

  gainXp(amount, options = {}) {
    const multiplier = options.applyMultiplier === false ? 1 : this.mods.xpMult;
    this.xp += amount * multiplier;
    while (this.xp >= this.xpToNext()) {
      this.xp -= this.xpToNext();
      this.level++;
      this.pendingChoices++;
    }
  }

  // ---------- 统一伤害入口（武器 / 弹道 / 召唤物 / DoT 都走这里） ----------
  damageEnemy(e, damage, options = {}) {
    if (e.dead) return;
    const source = {
      sourceWeaponId: options.sourceWeaponId ?? null,
      sourceAction: options.sourceAction ?? null,
      sourceTags: options.sourceTags ?? [],
      synergyId: options.synergyId ?? null,
      noSynergy: !!options.noSynergy,
      noSummon: !!options.noSummon,
    };
    const finalDamage = typeof e.modifyIncomingDamage === 'function'
      ? e.modifyIncomingDamage(damage)
      : damage;
    if (finalDamage <= 0) return;
    e.hp -= finalDamage;
    e.hitFlash = 0.08;
    if (e.hp <= 0) this._killEnemy(e, source);
    if (!source.noSynergy) {
      this.synergies.onDamage({ target: e, damage: finalDamage, options: source }, this._world());
    }
  }

  // Shared player damage entry for enemy contact, bullets and special attacks.
  hurtPlayer(damage) {
    if (this.debug?.settings.invincible) return false;
    const finalDamage = damage * (1 - this.mods.damageReduction);
    if (!applyPlayerDamage(this.player, finalDamage)) return false;
    this.hitShake = 0.25;
    this.player.lastHurtAt = this.elapsed;
    return true;
  }

  spawnHostileProjectile(options) {
    this.hostileProjectiles.push(createHostileProjectile(options));
  }

  spawnEnemyBlast(options) {
    this.effects.push({
      type: 'enemyBlast',
      x: options.x,
      y: options.y,
      radius: options.radius,
      color: options.color ?? '#ff7043',
      ttl: options.ttl ?? 0.35,
      maxTtl: options.ttl ?? 0.35,
    });
  }

  _killEnemy(e, options = {}) {
    if (e.dead) return;
    e.dead = true;
    this.kills++;
    this._dropGem(e.x, e.y);
    if (e.rank === 'elite') {
      this.dropRarePickup(e.x, e.y);
    } else if (e.rank === 'boss') {
      this.bossesDefeated++;
      this.save.stats.totalBossKills += 1;
      persistSave(this.save);
      this.dropRarePickup(e.x - 14, e.y);
      this.dropRarePickup(e.x + 14, e.y);
    }
    // 击杀日志：武器按 id 增量消费
    this.killLog.push({
      id: this.nextKillId++,
      x: e.x, y: e.y,
      burned: hasDot(e, 'burn'),
      blazed: hasDot(e, 'blaze'),
      sourceWeaponId: options.sourceWeaponId ?? null,
      sourceAction: options.sourceAction ?? null,
      synergyId: options.synergyId ?? null,
      noSynergy: !!options.noSynergy,
      noSummon: !!options.noSummon,
    });
    if (this.killLog.length > CONFIG.killLog.cap) {
      this.killLog.splice(0, this.killLog.length - CONFIG.killLog.cap);
    }
    // 视觉血迹
    this.corpses.push({ x: e.x, y: e.y, ttl: CONFIG.corpses.stainTtl });
    if (this.corpses.length > CONFIG.corpses.cap) this.corpses.shift();
  }

  _dropGem(x, y) {
    this.gems.push(createGem(x, y, this.elapsed));
    // 地面宝石超过上限时，自动收取最旧的
    while (this.gems.length > CONFIG.gems.cap) {
      const g = this.gems.shift();
      if (!g.dead) { g.dead = true; this.gainXp(g.value); }
    }
  }

  // ---------- 玩家治疗 / 地面掉落 ----------
  healPlayer(amount) {
    const p = this.player;
    p.hp = Math.min(p.maxHp, p.hp + amount);
  }

  increaseMaxHp(amount, healAmount = amount) {
    const value = Number.isFinite(amount) ? amount : 0;
    const multiplier = this.debug?.settings.player.maxHpMult ?? 1;
    this.player.maxHp = Math.max(1, this.player.maxHp + value * multiplier);
    this.player.hp = Math.min(this.player.maxHp, this.player.hp + healAmount);
  }

  // 掉一个血包（同屏数量有上限，防止爆屏）
  dropPickup(x, y, kind = 'hp') {
    let alive = 0;
    for (const pk of this.pickups) if (!pk.dead && pk.kind === 'hp') alive++;
    if (alive >= CONFIG.pickups.maxAlive) return;
    this.pickups.push({
      x, y, kind,
      value: CONFIG.pickups.hpValue,
      dead: false,
    });
  }

  dropRarePickup(x, y) {
    this.pickups.push(createRarePickup(x, y));
  }

  // ---------- 卡牌流程 ----------
  _applyOffer(offer) {
    const { card, type } = offer;
    if (card.kind === 'weapon') {
      if (type === 'new') {
        this.weapons.push(card.create());
      } else {
        const owned = this.weapons.find((w) => w.card.id === card.id);
        if (owned && owned.level < card.maxLevel) owned.level++;
      }
      this.synergies.refresh(this.weapons, this.elapsed);
    } else {
      const n = this.attrStacks[card.id] || 0;
      if (n >= CONFIG.cards.attrMaxStack) return;
      this.attrStacks[card.id] = n + 1;
      if (typeof card.onAcquire === 'function') card.onAcquire(this);
      this.recomputeMods();
    }
  }

  _finishChoice() {
    if (this.choiceOrigin === 'levelup') this.pendingChoices--;
    // 一次升了多级：连锁进入下一轮选卡
    if (this.pendingChoices > 0) {
      const offers = generateOffers(this);
      if (offers.length > 0) {
        this.choiceOrigin = 'levelup';
        this.currentOffers = offers;
        return; // 保持 choice 状态
      }
      this.pendingChoices = 0; // 池子空了，剩余选择作废
    }
    this.currentOffers = [];
    this.state = 'playing';
  }

  _handleChoice(viewW, viewH) {
    const offers = this.currentOffers;
    if (!offers || offers.length === 0) { this._finishChoice(); return; }

    // 数字键 1-9（开局界面最多展示全部武器，升级界面 3 张）
    let idx = -1;
    for (let i = 0; i < Math.min(9, offers.length); i++) {
      const d = String(i + 1);
      if (this.input.wasPressed('Digit' + d) || this.input.wasPressed('Numpad' + d)) {
        idx = i;
        break;
      }
    }

    if (idx === -1 && this.input.mouseClicked()) {
      const rects = getCardRects(viewW, viewH, offers.length);
      const mx = this.input.mouse.x, my = this.input.mouse.y;
      for (let i = 0; i < rects.length; i++) {
        const r = rects[i];
        if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h) { idx = i; break; }
      }
    }

    if (idx >= 0 && idx < offers.length) {
      this._applyOffer(offers[idx]);
      this._finishChoice();
    }
  }

  _handleWeaponBuildClick() {
    if (!this.input.mouseClicked()) return false;
    const { x, y } = this.input.mouse;
    const rects = getWeaponSlotRects();
    for (let i = 0; i < rects.length; i++) {
      const weapon = this.weapons[i];
      if (!weapon) continue;
      const rect = rects[i];
      if (x < rect.x || x > rect.x + rect.w || y < rect.y || y > rect.y + rect.h) continue;
      return this.synergies.toggleBuildWeapon(weapon.card.id, this.weapons, this.elapsed);
    }
    return false;
  }

  // ---------- 局外成长：撤离抉择 / 商城 / 仓库 ----------
  // Boss 波（含援军）清空钩子：掉落掷骰进临时背包，进入撤离抉择
  onBossWaveCleared() {
    // Timed boss checkpoints clear leftover reinforcements and hostile projectiles.
    this.enemies.length = 0;
    this.hostileProjectiles.length = 0;
    const drops = rollBossDrops(this.bossesDefeated);
    for (const id of drops) this.tempBackpack[id] = (this.tempBackpack[id] || 0) + 1;
    if (this.waveDirector.wave >= CONFIG.waves.maxWave) {
      this.onFinalWaveCleared();
      return;
    }
    this.state = 'extraction';
  }

  onFinalWaveCleared() {
    if (this.state === 'summary') return;
    this._finishRun(true);
  }

  chooseExtraction(extract) {
    if (this.state !== 'extraction') return;
    if (!extract) {
      if (this.waveDirector.wave >= CONFIG.waves.maxWave) {
        this.onFinalWaveCleared();
        return;
      }
      this.state = 'playing';
      this.waveDirector.beginRest();
      return;
    }
    this._finishRun(false);
  }

  _finishRun(completed) {
    const wave = this.waveDirector.wave;
    const darkCrystalsGained = Math.round(wave * CONFIG.meta.waveRewardMult);
    this.save.darkCrystals += darkCrystalsGained;
    const itemsBanked = { ...this.tempBackpack };
    for (const [id, count] of Object.entries(this.tempBackpack)) {
      if (count > 0) this.save.storage[id] = (this.save.storage[id] || 0) + count;
    }
    this.tempBackpack = { shard: 0, essence: 0, soulCrystal: 0 };
    this.save.stats.extractions += 1;
    if (completed) this.save.stats.completions += 1;
    this.save.stats.bestWave = Math.max(this.save.stats.bestWave, wave);
    persistSave(this.save);
    this.lastRunSummary = {
      completed,
      wave,
      kills: this.kills,
      level: this.level,
      bossesDefeated: this.bossesDefeated,
      elapsed: this.elapsed,
      darkCrystalsGained,
      itemsBanked,
    };
    this.state = 'summary';
  }

  startRun() {
    if (this.state !== 'menu') return;
    this.save.stats.runs += 1;
    persistSave(this.save);
    this.reset();
    this.state = 'opening';
    // 应用局外最大生命等级（等效局内属性卡 onAcquire 效果）
    const metaMaxHp = this.metaStacks.maxHp || 0;
    if (metaMaxHp > 0) this.increaseMaxHp(20 * metaMaxHp, 20 * metaMaxHp);
  }

  openShop() { if (this.state === 'menu') this.state = 'shop'; }
  openStorage() { if (this.state === 'menu') this.state = 'storage'; }
  backToMenu() { this.reset(); }
  confirmSummary() { if (this.state === 'summary') this.reset(); }

  buyShopItem(attrId) {
    if (this.state !== 'shop') return false;
    const ok = tryBuy(this.save, attrId);
    if (ok) persistSave(this.save);
    return ok;
  }

  // 单卖 = 卖出该材料全部存量
  sellStorageItem(itemId) {
    if (this.state !== 'storage') return 0;
    const item = META_ITEMS[itemId];
    const count = this.save.storage[itemId] || 0;
    if (!item || count <= 0) return 0;
    const gained = item.sellPrice * count;
    this.save.storage[itemId] = 0;
    this.save.darkCrystals += gained;
    persistSave(this.save);
    return gained;
  }

  sellAllStorage() {
    if (this.state !== 'storage') return 0;
    let gained = 0;
    for (const item of META_ITEM_LIST) {
      const count = this.save.storage[item.id] || 0;
      if (count > 0) {
        this.save.storage[item.id] = 0;
        gained += item.sellPrice * count;
      }
    }
    if (gained > 0) {
      this.save.darkCrystals += gained;
      persistSave(this.save);
    }
    return gained;
  }

  // 死亡：临时背包全损，已入库物品不受影响
  _onDeath() {
    this.lastDeathLoss = { ...this.tempBackpack };
    this.tempBackpack = { shard: 0, essence: 0, soulCrystal: 0 };
    this.save.stats.bestWave = Math.max(this.save.stats.bestWave, this.waveDirector.wave);
    persistSave(this.save);
    this.state = 'dead';
  }

  // ---------- 主循环 ----------
  update(dt, viewW, viewH) {
    this._viewW = viewW;
    this._viewH = viewH;

    // 局外界面：主菜单 / 商城 / 仓库 / 撤离抉择 / 撤离结算
    if (this.state === 'menu') { updateMenu(this); return; }
    if (this.state === 'shop') { updateShop(this); return; }
    if (this.state === 'storage') { updateStorage(this); return; }
    if (this.state === 'extraction') { updateExtraction(this); return; }
    if (this.state === 'summary') { updateSummary(this); return; }

    if (this.state === 'opening' || this.state === 'choice') {
      this._handleChoice(viewW, viewH);
      return; // 选卡期间世界暂停
    }

    if (this.state === 'dead') {
      if (this.input.wasPressed('KeyR')) this.backToMenu();
      return;
    }

    // 有待处理的升级选卡
    if (this.pendingChoices > 0) {
      const offers = generateOffers(this);
      if (offers.length === 0) {
        this.pendingChoices = 0;
      } else {
        this.choiceOrigin = 'levelup';
        this.currentOffers = offers;
        this.state = 'choice';
        return;
      }
    }

    this._handleWeaponBuildClick();

    // Debug pause freezes only live gameplay. Choice screens and the dead-state
    // restart path above remain interactive.
    if (this.debug?.settings.paused) return;

    this.elapsed += dt;
    this.synergies.update(dt);
    this.player.speed = CONFIG.player.speed * this.mods.moveSpeedMult * this.playerMoveSpeedBonusMult();

    updatePlayer(this.player, this.input, dt);
    this.camera.follow(this.player, dt, CONFIG.camera.lerp);
    this.waveDirector.update(dt, this, this.camera, viewW, viewH);

    const world = this._world();

    // 状态系统：DoT 结算（击杀走统一入口）+ 减速/冰冻计时
    for (const e of this.enemies) {
      if (e.dead) continue;
      const dotDmg = tickStatus(e, dt);
      if (dotDmg > 0) this.damageEnemy(e, dotDmg);
    }

    for (const e of this.enemies) updateEnemy(e, this.player, dt, world);
    separateEnemies(this.enemies, dt);

    for (const w of this.weapons) w.update(dt, world);

    for (const p of this.projectiles) updateProjectile(p, dt);
    for (const p of this.hostileProjectiles) updateHostileProjectile(p, dt);
    for (const t of this.trails) updateTrail(t, world, dt);

    for (const fx of this.effects) fx.ttl -= dt;
    for (const c of this.corpses) c.ttl -= dt;

    this._handleCollisions();
    this._updateGems(dt);
    this._updatePickups(dt);

    // 清理死亡实体
    this.enemies = this.enemies.filter((e) => !e.dead);
    this.projectiles = this.projectiles.filter((p) => !p.dead);
    this.hostileProjectiles = this.hostileProjectiles.filter((p) => !p.dead);
    this.trails = this.trails.filter((t) => !t.dead);
    this.summons = this.summons.filter((s) => !s.dead);
    this.gems = this.gems.filter((g) => !g.dead);
    this.pickups = this.pickups.filter((p) => !p.dead);
    this.corpses = this.corpses.filter((c) => c.ttl > 0);
    this.effects = this.effects.filter((fx) => fx.ttl > 0);

    if (this.hitShake > 0) this.hitShake -= dt;
    if (this.rareMessage) {
      this.rareMessage.ttl -= dt;
      if (this.rareMessage.ttl <= 0) this.rareMessage = null;
    }
  }

  // 注入给武器的世界上下文（避免武器与 game 循环依赖）
  _world() {
    return {
      player: this.player,
      enemies: this.enemies,
      projectiles: this.projectiles,
      hostileProjectiles: this.hostileProjectiles,
      trails: this.trails,
      summons: this.summons,
      effects: this.effects,
      weapons: this.weapons,
      synergies: this.synergies,
      mods: this.mods,
      elapsed: this.elapsed,
      kills: this.kills,
      killLog: this.killLog,
      hasSynergy: (id) => this.synergies.isActive(id),
      getWeapon: (id) => this.weapons.find((weapon) => weapon.card.id === id) ?? null,
      recordSynergyTrigger: (id, contribution) => this.synergies.recordTrigger(id, contribution),
      damageEnemy: (e, dmg, options) => this.damageEnemy(e, dmg, options),
      hurtPlayer: (damage) => this.hurtPlayer(damage),
      spawnHostileProjectile: (options) => this.spawnHostileProjectile(options),
      spawnEnemyBlast: (options) => this.spawnEnemyBlast(options),
      healPlayer: (amount) => this.healPlayer(amount),
      setPlayerMoveSpeedBonus: (source, multiplier, duration) => this.setPlayerMoveSpeedBonus(source, multiplier, duration),
      dropPickup: (x, y, kind) => this.dropPickup(x, y, kind),
      // 状态系统
      applyDot: (e, type, dps, duration) => applyDot(e, type, dps, duration),
      applySlow: (e, factor, duration) => applySlow(e, factor, duration),
      applyFreeze: (e, duration) => applyFreeze(e, duration),
      hasDot: (e, type) => hasDot(e, type),
    };
  }

  _updateGems(dt) {
    const pl = this.player;
    const pickupRadius = CONFIG.gems.pickupRadius
      * (this.debug?.settings.player.pickupRangeMult ?? 1);
    const pickup2 = pickupRadius * pickupRadius;
    for (const g of this.gems) {
      if (g.dead) continue;
      updateGem(g, pl, dt, this.gemMagnetRadius());
      if (dist2(g.x, g.y, pl.x, pl.y) <= pickup2) {
        g.dead = true;
        this.gainXp(g.value);
      }
    }
  }

  // 血包与稀有物品：走到上面拾取；稀有物品会显示获得提示并永久生效。
  _updatePickups(dt) {
    const pl = this.player;
    for (const pk of this.pickups) {
      if (pk.dead) continue;
      const baseRadius = pk.kind === 'rare'
        ? CONFIG.pickups.rarePickupRadius
        : CONFIG.pickups.pickupRadius;
      const radius = baseRadius * (this.debug?.settings.player.pickupRangeMult ?? 1);
      if (dist2(pk.x, pk.y, pl.x, pl.y) <= radius * radius) {
        pk.dead = true;
        if (pk.kind === 'hp') {
          this.healPlayer(pk.value);
        } else if (pk.kind === 'rare') {
          const item = applyRareItem(this, pk);
          if (item) {
            this.rareMessage = {
              text: `获得稀有物品：${item.name}`,
              detail: item.desc,
              color: item.color,
              ttl: 3.5,
              maxTtl: 3.5,
            };
          }
        }
      }
    }
  }

  _handleCollisions() {
    const pl = this.player;

    // 敌人接触伤害
    for (const e of this.enemies) {
      if (e.dead || e.hitCooldown > 0) continue;
      const rr = e.radius + pl.radius;
      if (dist2(e.x, e.y, pl.x, pl.y) <= rr * rr) {
        if (this.hurtPlayer(e.damage)) e.hitCooldown = 0.6;
      }
    }

    // Enemy projectiles hit the player and are consumed even during i-frames.
    for (const projectile of this.hostileProjectiles) {
      if (projectile.dead) continue;
      const rr = projectile.radius + pl.radius;
      if (dist2(projectile.x, projectile.y, pl.x, pl.y) <= rr * rr) {
        this.hurtPlayer(projectile.damage);
        projectile.dead = true;
      }
    }

    // 子弹命中敌人（走统一伤害入口，保证击杀掉宝石）
    // 弹道可选特性（武器在 createProjectile 后自行设置字段）：
    //   p.pierce = true   穿透：同一敌人只命中一次；p.maxHits 可限制总命中数
    //   p.onHit = (e)=>{} 命中回调：每次命中敌人时触发（引雷/闪电链等机制用）
    for (const p of this.projectiles) {
      if (p.dead) continue;
      for (const e of this.enemies) {
        if (e.dead) continue;
        if (p.hitSet && p.hitSet.has(e)) continue;
        const rr = e.radius + p.radius;
        if (dist2(p.x, p.y, e.x, e.y) <= rr * rr) {
          this.damageEnemy(e, p.damage, p.damageOptions);
          if (typeof p.onHit === 'function') p.onHit(e);
          if (p.pierce) {
            if (!p.hitSet) p.hitSet = new Set();
            p.hitSet.add(e);
            p.hitCount = (p.hitCount || 0) + 1;
            if (Number.isFinite(p.maxHits) && p.hitCount >= p.maxHits) {
              p.dead = true;
              break;
            }
          } else {
            p.dead = true;
            break;
          }
        }
      }
    }

    if (pl.hp <= 0) { pl.hp = 0; this._onDeath(); }
  }

  // ---------- 渲染 ----------
  render(ctx, viewW, viewH) {
    this._viewW = viewW;
    this._viewH = viewH;
    ctx.fillStyle = CONFIG.view.background;
    ctx.fillRect(0, 0, viewW, viewH);

    ctx.save();
    let ox = viewW / 2 - this.camera.x;
    let oy = viewH / 2 - this.camera.y;
    if (this.hitShake > 0) {
      const s = this.hitShake * 24;
      ox += (Math.random() - 0.5) * s;
      oy += (Math.random() - 0.5) * s;
    }
    ctx.translate(ox, oy);

    this._drawGrid(ctx, viewW, viewH);

    const world = this._world();
    // 层次：血迹 -> 丹火路径 -> 武器 under（光环）-> 宝石/血包 -> 敌人(+状态) -> 召唤物 -> 玩家 -> 弹道 -> 武器 over（玉环）-> 特效
    this._drawCorpses(ctx);
    for (const t of this.trails) drawTrail(ctx, t);
    for (const w of this.weapons) w.draw(ctx, world, 'under');
    for (const g of this.gems) drawGem(ctx, g);
    this._drawPickups(ctx);
    for (const e of this.enemies) { drawEnemy(ctx, e); drawStatus(ctx, e); }
    for (const su of this.summons) drawSummon(ctx, su);
    drawPlayer(ctx, this.player);
    for (const p of this.projectiles) drawProjectile(ctx, p);
    for (const p of this.hostileProjectiles) drawHostileProjectile(ctx, p);
    for (const w of this.weapons) w.draw(ctx, world, 'over');
    this._drawEffects(ctx);

    ctx.restore();

    drawHUD(ctx, viewW, viewH, this);
    if (this.state === 'opening' || this.state === 'choice') {
      drawChoiceUI(ctx, viewW, viewH, this);
    } else if (this.state === 'dead') {
      drawGameOver(ctx, viewW, viewH, this);
    } else if (this.state === 'menu') {
      drawMenu(ctx, viewW, viewH, this);
    } else if (this.state === 'shop') {
      drawShop(ctx, viewW, viewH, this);
    } else if (this.state === 'storage') {
      drawStorage(ctx, viewW, viewH, this);
    } else if (this.state === 'extraction') {
      drawExtraction(ctx, viewW, viewH, this);
    } else if (this.state === 'summary') {
      drawSummary(ctx, viewW, viewH, this);
    }
  }

  _drawCorpses(ctx) {
    for (const c of this.corpses) {
      const k = Math.max(0, c.ttl / CONFIG.corpses.stainTtl);
      ctx.globalAlpha = 0.18 * k;
      ctx.beginPath();
      ctx.arc(c.x, c.y, 10, 0, Math.PI * 2);
      ctx.fillStyle = '#b71c1c';
      ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  _drawPickups(ctx) {
    for (const pk of this.pickups) {
      if (pk.dead) continue;
      if (pk.kind === 'rare') {
        drawRarePickup(ctx, pk);
        continue;
      }
      // 血包：粉底白十字
      ctx.beginPath();
      ctx.arc(pk.x, pk.y, 8, 0, Math.PI * 2);
      ctx.fillStyle = '#ef9a9a';
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.85)';
      ctx.lineWidth = 1.2;
      ctx.stroke();
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(pk.x - 1.5, pk.y - 4.5, 3, 9);
      ctx.fillRect(pk.x - 4.5, pk.y - 1.5, 9, 3);
    }
  }

  _drawEffects(ctx) {
    for (const fx of this.effects) {
      if (fx.type === 'slash') {
        const k = Math.max(0, fx.ttl / fx.maxTtl);
        ctx.save();
        ctx.translate(fx.x, fx.y);
        ctx.rotate(fx.angle);
        ctx.globalAlpha = 0.5 * k;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.arc(0, 0, fx.range, -fx.arc / 2, fx.arc / 2);
        ctx.closePath();
        ctx.fillStyle = '#e0f7fa';
        ctx.fill();
        ctx.restore();
      } else if (fx.type === 'enemyBlast') {
        const progress = 1 - Math.max(0, fx.ttl / fx.maxTtl);
        ctx.save();
        ctx.globalAlpha = 0.55 * (1 - progress);
        ctx.beginPath();
        ctx.arc(fx.x, fx.y, fx.radius * (0.35 + progress * 0.65), 0, Math.PI * 2);
        ctx.fillStyle = fx.color;
        ctx.fill();
        ctx.restore();
      } else if (fx.type === 'synergyArc') {
        const alpha = Math.max(0, fx.ttl / fx.maxTtl);
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.strokeStyle = fx.color ?? '#80deea';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(fx.x1, fx.y1);
        ctx.lineTo((fx.x1 + fx.x2) * 0.5 + 8, (fx.y1 + fx.y2) * 0.5 - 8);
        ctx.lineTo(fx.x2, fx.y2);
        ctx.stroke();
        ctx.restore();
      } else if (fx.type === 'synergyCommandMark') {
        const progress = 1 - Math.max(0, fx.ttl / fx.maxTtl);
        ctx.save();
        ctx.translate(fx.x, fx.y - 24 - progress * 8);
        ctx.rotate(Math.PI / 4);
        ctx.globalAlpha = 0.9 * (1 - progress);
        ctx.strokeStyle = '#d7a4ff';
        ctx.lineWidth = 3;
        ctx.strokeRect(-8, -8, 16, 16);
        ctx.beginPath();
        ctx.moveTo(-12, 0);
        ctx.lineTo(12, 0);
        ctx.moveTo(0, -12);
        ctx.lineTo(0, 12);
        ctx.stroke();
        ctx.restore();
      } else if (fx.type === 'synergyFlameBlade') {
        const progress = 1 - Math.max(0, fx.ttl / fx.maxTtl);
        ctx.save();
        ctx.globalAlpha = 0.9 * (1 - progress);
        ctx.lineCap = 'round';
        ctx.strokeStyle = '#ff5722';
        ctx.lineWidth = fx.width * (1 - progress * 0.65);
        ctx.beginPath();
        ctx.moveTo(fx.x1, fx.y1);
        ctx.lineTo(fx.x2, fx.y2);
        ctx.stroke();
        ctx.strokeStyle = '#fff176';
        ctx.lineWidth = Math.max(2, fx.width * 0.24 * (1 - progress));
        ctx.stroke();
        ctx.restore();
      } else if (fx.type === 'synergyBurst') {
        const progress = 1 - Math.max(0, fx.ttl / fx.maxTtl);
        const radius = fx.radius * (0.35 + progress * 0.65);
        ctx.save();
        ctx.globalAlpha = 0.4 * (1 - progress);
        ctx.fillStyle = fx.color ?? '#ff8a50';
        ctx.beginPath();
        ctx.arc(fx.x, fx.y, radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 0.9 * (1 - progress);
        ctx.strokeStyle = fx.accent ?? '#fff176';
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.arc(fx.x, fx.y, radius, 0, Math.PI * 2);
        ctx.stroke();
        if (fx.style === 'lightningFire') {
          ctx.strokeStyle = '#9be8ff';
          ctx.lineWidth = 2;
          for (let i = 0; i < 8; i++) {
            const angle = (i * Math.PI * 2) / 8 + progress * 0.4;
            ctx.beginPath();
            ctx.moveTo(fx.x + Math.cos(angle) * radius * 0.45, fx.y + Math.sin(angle) * radius * 0.45);
            ctx.lineTo(fx.x + Math.cos(angle + 0.12) * radius * 0.72, fx.y + Math.sin(angle + 0.12) * radius * 0.72);
            ctx.lineTo(fx.x + Math.cos(angle) * radius, fx.y + Math.sin(angle) * radius);
            ctx.stroke();
          }
        } else if (fx.style === 'corpseFire') {
          ctx.fillStyle = '#d68cff';
          for (let i = 0; i < 5; i++) {
            const angle = (i * Math.PI * 2) / 5 - progress;
            const distance = radius * (0.25 + progress * 0.65);
            ctx.beginPath();
            ctx.arc(fx.x + Math.cos(angle) * distance, fx.y + Math.sin(angle) * distance, 3.5, 0, Math.PI * 2);
            ctx.fill();
          }
        } else if (fx.style === 'jadeCharge') {
          ctx.save();
          ctx.translate(fx.x, fx.y);
          ctx.rotate(progress * Math.PI);
          ctx.strokeStyle = '#d1ff8a';
          ctx.strokeRect(-radius * 0.45, -radius * 0.45, radius * 0.9, radius * 0.9);
          ctx.restore();
        } else if (fx.style === 'alchemy') {
          ctx.fillStyle = '#80deea';
          ctx.beginPath();
          ctx.arc(fx.x, fx.y, Math.max(3, radius * 0.22), 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.restore();
      }
    }
  }

  _drawGrid(ctx, viewW, viewH) {
    const g = CONFIG.view.gridSize;
    const left = this.camera.x - viewW / 2 - g;
    const right = this.camera.x + viewW / 2 + g;
    const top = this.camera.y - viewH / 2 - g;
    const bottom = this.camera.y + viewH / 2 + g;
    ctx.strokeStyle = 'rgba(255,255,255,0.06)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let x = Math.floor(left / g) * g; x <= right; x += g) {
      ctx.moveTo(x, top); ctx.lineTo(x, bottom);
    }
    for (let y = Math.floor(top / g) * g; y <= bottom; y += g) {
      ctx.moveTo(left, y); ctx.lineTo(right, y);
    }
    ctx.stroke();
  }
}
