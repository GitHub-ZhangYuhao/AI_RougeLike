import { WeaponBase, nearestEnemy, hitEnemiesInRadius } from './base.js';
import { createProjectile } from '../projectile.js';
import { dist2 } from '../utils.js';

// ---------- 雷符咒：远程雷电弹道 ----------
// Lv2 引雷：按弹道命中次数计数，每 2 次命中劈雷一次（伤害 = 弹道 ×1.5）
// Lv4 闪电链：命中后向附近敌人弹射，每次 50% 伤害
// Lv6 质变：链弹射 3 目标；每波攻击首个命中目标必定引雷（不占计数）；引雷变范围伤害
export class TalismanWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.world = null;      // 当前帧 world（update 每帧刷新，onHit 回调里读取）
    this.hitCounts = new WeakMap(); // Per-target thunder counters
    this.attackSeq = 0;     // 攻击波次序号（Lv6「首命中必引雷」用）
    this.firstDoneSeq = 0;  // 已消费过首命中引雷的波次序号
    this.boltFx = [];       // 引雷特效：{ x, y, ttl, total, aoe }
    this.chainFx = [];      // 闪电链线段：{ x1, y1, x2, y2, ttl, total }
  }

  update(dt, world) {
    this.world = world; // onHit 在碰撞阶段触发，必须取当前帧的 world
    // 临时特效寿命推进
    for (const fx of this.boltFx) fx.ttl -= dt;
    for (const fx of this.chainFx) fx.ttl -= dt;
    this.boltFx = this.boltFx.filter((fx) => fx.ttl > 0);
    this.chainFx = this.chainFx.filter((fx) => fx.ttl > 0);

    this.timer -= dt;
    if (this.timer > 0) return;
    const s = this.stats;
    const target = nearestEnemy(world.enemies, world.player.x, world.player.y, s.range ** 2);
    if (!target) { this.timer = 0; return; }
    this.timer = s.interval;
    const damage = s.damage * world.mods.damageMult;
    const lifetime = s.range / s.speed + 0.3;
    this.attackSeq++;
    const angle = Math.atan2(target.y - world.player.y, target.x - world.player.x);
    const p = createProjectile(world.player.x, world.player.y, angle, {
      speed: s.speed, radius: 5, damage, lifetime, color: '#8be0ff',
    });
    p.attackSeq = this.attackSeq;
    p.onHit = (e) => this._onProjectileHit(e, p);
    world.projectiles.push(p);
  }

  // 弹道命中回调（由 game._handleCollisions 调用，发生在 damageEnemy 之后）
  _onProjectileHit(e, p) {
    const world = this.world;
    if (!world) return;
    const s = this.stats;
    const thunderDmg = p.damage * 1.5; // p.damage 发射时已含 damageMult

    if (s.thunderFirst && p.attackSeq !== this.firstDoneSeq) {
      // Lv6：每次攻击命中的第一个目标必定引雷，不占计数
      this.firstDoneSeq = p.attackSeq;
      this._strikeThunder(e, thunderDmg, world);
    } else if (s.thunder) {
      // Each enemy tracks its own two-hit thunder progress.
      const hits = (this.hitCounts.get(e) || 0) + 1;
      if (hits >= 2) {
        this.hitCounts.delete(e);
        this._strikeThunder(e, thunderDmg, world);
      } else {
        this.hitCounts.set(e, hits);
      }
    }

    // 闪电链：命中后向附近敌人弹射
    if (s.chain) this._chainLightning(e, p.damage * 0.5, world);
  }

  // 引雷落雷：Lv2~5 单体，Lv6 变为范围伤害（半径 95，设计上限）
  _strikeThunder(e, dmg, world) {
    const s = this.stats;
    const total = 0.18;
    if (s.thunderAoE) {
      // 范围落雷：内部自动跳过死亡敌人，击杀走统一伤害入口
      hitEnemiesInRadius(world, e.x, e.y, 95, dmg);
    } else if (!e.dead) {
      world.damageEnemy(e, dmg);
    }
    this.boltFx.push({ x: e.x, y: e.y, ttl: total, total, aoe: !!s.thunderAoE });
  }

  // 闪电链：从命中目标出发，逐跳找 160px 内最近的未命中敌人弹射
  _chainLightning(origin, dmg, world) {
    const s = this.stats;
    const bounces = s.chainBounces || 2;
    const R2 = 180 * 180; // 弹射搜索半径上限（设计定稿 ≤180px）
    const total = 0.15;
    const hitSet = new Set([origin]); // 同一条链不重复命中同一目标
    let cur = origin;
    for (let i = 0; i < bounces; i++) {
      let best = null;
      let bestD = R2;
      for (const en of world.enemies) {
        if (en.dead || hitSet.has(en)) continue;
        const d = dist2(cur.x, cur.y, en.x, en.y);
        if (d <= bestD) { bestD = d; best = en; }
      }
      if (!best) break; // 附近没有可弹射目标，链终止
      hitSet.add(best);
      world.damageEnemy(best, dmg);
      this.chainFx.push({ x1: cur.x, y1: cur.y, x2: best.x, y2: best.y, ttl: total, total });
      cur = best;
    }
  }

  draw(ctx, world, phase) {
    if (phase !== 'over') return;
    // 闪电链线段（短暂显示）
    for (const fx of this.chainFx) {
      ctx.save();
      ctx.globalAlpha = Math.max(0, fx.ttl / fx.total);
      this._drawBoltLine(ctx, fx.x1, fx.y1, fx.x2, fx.y2, '#9be8ff', 2);
      ctx.restore();
    }
    // 引雷：从天落雷 + Lv6 范围圈
    for (const fx of this.boltFx) {
      const a = Math.max(0, fx.ttl / fx.total);
      ctx.save();
      ctx.globalAlpha = a;
      this._drawBoltLine(ctx, fx.x + 14, fx.y - 150, fx.x, fx.y, '#ffe98a', 3);
      if (fx.aoe) {
        ctx.beginPath();
        ctx.arc(fx.x, fx.y, 95 * (1 - fx.ttl / fx.total), 0, Math.PI * 2);
        ctx.strokeStyle = '#ffe98a';
        ctx.lineWidth = 2;
        ctx.stroke();
      }
      ctx.restore();
    }
  }

  // 锯齿闪电线：两点间分段加随机垂直偏移（每次重绘轻微抖动，模拟电弧）
  _drawBoltLine(ctx, x1, y1, x2, y2, color, width) {
    const segs = 5;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = Math.hypot(dx, dy) || 1;
    const nx = -dy / len; // 法线方向
    const ny = dx / len;
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    for (let i = 1; i < segs; i++) {
      const t = i / segs;
      const off = (Math.random() - 0.5) * 14;
      ctx.lineTo(x1 + dx * t + nx * off, y1 + dy * t + ny * off);
    }
    ctx.lineTo(x2, y2);
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.stroke();
  }
}

export const CARD = {
  id: 'talisman', kind: 'weapon', name: '雷符咒', icon: '⚡', maxLevel: 6,
  desc: '向远处敌人射出雷电弹道。每命中 2 次触发引雷，Lv4 起命中还会弹射闪电链。',
  levels: [
    // Lv1 数值基准
    { damage: 12, interval: 1.0, speed: 460, range: 520 },
    // Lv2 解锁引雷
    { damage: 15, interval: 0.95, speed: 460, range: 520, thunder: true },
    // Lv3 数值成长
    { damage: 19, interval: 0.88, speed: 460, range: 520, thunder: true },
    // Lv4 解锁闪电链（弹射 2 次）
    { damage: 23, interval: 0.81, speed: 460, range: 520, thunder: true, chain: true, chainBounces: 2 },
    // Lv5 数值成长
    { damage: 27, interval: 0.75, speed: 460, range: 520, thunder: true, chain: true, chainBounces: 2 },
    // Lv6 质变：链弹射 3 目标；每波攻击首命中必定引雷（不占计数）；引雷变范围伤害
    { damage: 31, interval: 0.70, speed: 490, range: 550, thunder: true, thunderFirst: true, thunderAoE: true, chain: true, chainBounces: 3 },
  ],
  create() { return new TalismanWeapon(this); },
};