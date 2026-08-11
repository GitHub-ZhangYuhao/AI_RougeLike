import { CONFIG } from './config.js';
import { Camera } from './camera.js';
import { createPlayer, updatePlayer, hurtPlayer, drawPlayer } from './player.js';
import { updateEnemy, separateEnemies, drawEnemy } from './enemy.js';
import { Spawner } from './spawner.js';
import { updateProjectile, drawProjectile } from './projectile.js';
import { updateTrail, drawTrail, drawSummon } from './weapons/index.js';
import { createGem, updateGem, drawGem } from './gems.js';
import { openingOffers, generateOffers, computeMods } from './cards.js';
import { drawHUD, drawGameOver } from './hud.js';
import { getCardRects, drawChoiceUI } from './ui-cards.js';
import { dist2 } from './utils.js';
import {
  tickStatus, drawStatus, applyDot, applySlow, applyFreeze, hasDot,
} from './systems/status.js';

// 游戏主状态机
// state: 'opening' 开局选卡 | 'playing' 战斗中 | 'choice' 升级选卡 | 'dead' 死亡
export class Game {
  constructor(input) {
    this.input = input;
    this.reset();
  }

  reset() {
    this.state = 'opening';
    this.elapsed = 0;
    this.kills = 0;

    // 等级与经验
    this.level = 1;
    this.xp = 0;
    this.pendingChoices = 0; // 待处理的选卡次数（可能一次升多级）
    // 卡牌：属性卡叠加层数 -> 全局乘数
    this.attrStacks = {};
    this.mods = computeMods(this.attrStacks);

    this.player = createPlayer(0, 0);
    this.camera = new Camera(0, 0);
    this.enemies = [];
    this.projectiles = [];
    this.gems = [];
    this.trails = [];
    this.summons = [];
    this.effects = [];
    this.weapons = [];
    this.spawner = new Spawner();
    this.hitShake = 0;

    // ---------- 击杀日志 / 尸体 / 掉落 ----------
    // killLog：最近击杀记录，供武器监听（丹火爆燃、死灵转化、击杀计数类质变）
    // 条目：{id: 全局递增序号, x, y, burned: 死亡时是否带火系 debuff}
    this.killLog = [];
    this.nextKillId = 1;
    this.corpses = [];  // 纯视觉血迹
    this.pickups = [];  // 地面掉落物（血包等）

    // 开局展示全部武器卡任选 1（槽位上限走 CONFIG.cards.maxWeaponSlots，不写死）
    this.choiceOrigin = 'opening';
    this.currentOffers = openingOffers();
  }

  // ---------- 经验 / 等级 ----------
  xpToNext() {
    return CONFIG.xp.base + (this.level - 1) * CONFIG.xp.perLevel;
  }

  gainXp(amount) {
    this.xp += amount * this.mods.xpMult;
    while (this.xp >= this.xpToNext()) {
      this.xp -= this.xpToNext();
      this.level++;
      this.pendingChoices++;
    }
  }

  // ---------- 统一伤害入口（武器 / 弹道 / 召唤物 / DoT 都走这里） ----------
  damageEnemy(e, damage) {
    if (e.dead) return;
    e.hp -= damage;
    e.hitFlash = 0.08;
    if (e.hp <= 0) this._killEnemy(e);
  }

  _killEnemy(e) {
    if (e.dead) return;
    e.dead = true;
    this.kills++;
    this._dropGem(e.x, e.y);
    // 击杀日志：武器按 id 增量消费
    this.killLog.push({
      id: this.nextKillId++,
      x: e.x, y: e.y,
      burned: hasDot(e, 'burn'),
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

  // 掉一个血包（同屏数量有上限，防止爆屏）
  dropPickup(x, y, kind = 'hp') {
    let alive = 0;
    for (const pk of this.pickups) if (!pk.dead) alive++;
    if (alive >= CONFIG.pickups.maxAlive) return;
    this.pickups.push({
      x, y, kind,
      value: CONFIG.pickups.hpValue,
      dead: false,
    });
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
    } else {
      const n = this.attrStacks[card.id] || 0;
      if (n >= CONFIG.cards.attrMaxStack) return;
      this.attrStacks[card.id] = n + 1;
      this.mods = computeMods(this.attrStacks);
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

  // ---------- 主循环 ----------
  update(dt, viewW, viewH) {
    if (this.state === 'opening' || this.state === 'choice') {
      this._handleChoice(viewW, viewH);
      return; // 选卡期间世界暂停
    }

    if (this.state === 'dead') {
      if (this.input.wasPressed('KeyR')) this.reset();
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

    this.elapsed += dt;
    this.player.speed = CONFIG.player.speed * this.mods.moveSpeedMult;

    updatePlayer(this.player, this.input, dt);
    this.camera.follow(this.player, dt, CONFIG.camera.lerp);
    this.spawner.update(dt, this.elapsed, this.enemies, this.camera, viewW, viewH);

    const world = this._world();

    // 状态系统：DoT 结算（击杀走统一入口）+ 减速/冰冻计时
    for (const e of this.enemies) {
      if (e.dead) continue;
      const dotDmg = tickStatus(e, dt);
      if (dotDmg > 0) {
        e.hp -= dotDmg;
        if (e.hp <= 0) this._killEnemy(e);
      }
    }

    for (const e of this.enemies) updateEnemy(e, this.player, dt);
    separateEnemies(this.enemies, dt);

    for (const w of this.weapons) w.update(dt, world);

    for (const p of this.projectiles) updateProjectile(p, dt);
    for (const t of this.trails) updateTrail(t, world, dt);

    for (const fx of this.effects) fx.ttl -= dt;
    for (const c of this.corpses) c.ttl -= dt;

    this._handleCollisions();
    this._updateGems(dt);
    this._updatePickups(dt);

    // 清理死亡实体
    this.enemies = this.enemies.filter((e) => !e.dead);
    this.projectiles = this.projectiles.filter((p) => !p.dead);
    this.trails = this.trails.filter((t) => !t.dead);
    this.summons = this.summons.filter((s) => !s.dead);
    this.gems = this.gems.filter((g) => !g.dead);
    this.pickups = this.pickups.filter((p) => !p.dead);
    this.corpses = this.corpses.filter((c) => c.ttl > 0);
    this.effects = this.effects.filter((fx) => fx.ttl > 0);

    if (this.hitShake > 0) this.hitShake -= dt;
  }

  // 注入给武器的世界上下文（避免武器与 game 循环依赖）
  _world() {
    return {
      player: this.player,
      enemies: this.enemies,
      projectiles: this.projectiles,
      trails: this.trails,
      summons: this.summons,
      effects: this.effects,
      mods: this.mods,
      elapsed: this.elapsed,
      kills: this.kills,
      killLog: this.killLog,
      damageEnemy: (e, dmg) => this.damageEnemy(e, dmg),
      healPlayer: (amount) => this.healPlayer(amount),
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
    const pickup2 = CONFIG.gems.pickupRadius * CONFIG.gems.pickupRadius;
    for (const g of this.gems) {
      if (g.dead) continue;
      updateGem(g, pl, dt);
      if (dist2(g.x, g.y, pl.x, pl.y) <= pickup2) {
        g.dead = true;
        this.gainXp(g.value);
      }
    }
  }

  // 血包等掉落物：不吸附，走到上面才拾取
  _updatePickups(dt) {
    const pl = this.player;
    const pickup2 = CONFIG.pickups.pickupRadius * CONFIG.pickups.pickupRadius;
    for (const pk of this.pickups) {
      if (pk.dead) continue;
      if (dist2(pk.x, pk.y, pl.x, pl.y) <= pickup2) {
        pk.dead = true;
        if (pk.kind === 'hp') this.healPlayer(pk.value);
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
        if (hurtPlayer(pl, e.damage)) {
          e.hitCooldown = 0.6;
          this.hitShake = 0.25;
          pl.lastHurtAt = this.elapsed; // 供「受击触发」类质变监听
        }
      }
    }

    // 子弹命中敌人（走统一伤害入口，保证击杀掉宝石）
    // 弹道可选特性（武器在 createProjectile 后自行设置字段）：
    //   p.pierce = true   穿透：不消失，同一敌人只命中一次（p.hitSet 自动维护）
    //   p.onHit = (e)=>{} 命中回调：每次命中敌人时触发（引雷/闪电链等机制用）
    for (const p of this.projectiles) {
      if (p.dead) continue;
      for (const e of this.enemies) {
        if (e.dead) continue;
        if (p.hitSet && p.hitSet.has(e)) continue;
        const rr = e.radius + p.radius;
        if (dist2(p.x, p.y, e.x, e.y) <= rr * rr) {
          this.damageEnemy(e, p.damage);
          if (typeof p.onHit === 'function') p.onHit(e);
          if (p.pierce) {
            if (!p.hitSet) p.hitSet = new Set();
            p.hitSet.add(e);
          } else {
            p.dead = true;
            break;
          }
        }
      }
    }

    if (pl.hp <= 0) { pl.hp = 0; this.state = 'dead'; }
  }

  // ---------- 渲染 ----------
  render(ctx, viewW, viewH) {
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
    for (const w of this.weapons) w.draw(ctx, world, 'over');
    this._drawEffects(ctx);

    ctx.restore();

    drawHUD(ctx, viewW, viewH, this);
    if (this.state === 'opening' || this.state === 'choice') {
      drawChoiceUI(ctx, viewW, viewH, this);
    } else if (this.state === 'dead') {
      drawGameOver(ctx, viewW, viewH, this);
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