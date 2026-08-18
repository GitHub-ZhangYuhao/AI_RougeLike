import { WeaponBase, nearestN, hitEnemiesInRadius } from './base.js';
import { createProjectile } from '../projectile.js';
import { dist2 } from '../utils.js';

// ---------- 雷符咒：远程雷电弹道 ----------
// 低阶多发：count 决定每波雷弹数量，分别指向最近的 count 个不同目标
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
    const targets = nearestN(world.enemies, world.player.x, world.player.y, s.count || 1, s.range ** 2);
    if (!targets.length) { this.timer = 0; return; }
    this.timer = s.interval;
    const damage = s.damage * world.mods.damageMult;
    const lifetime = s.range / s.speed + 0.3;
    this.attackSeq++;
    for (const target of targets) {
      const angle = Math.atan2(target.y - world.player.y, target.x - world.player.x);
      const p = createProjectile(world.player.x, world.player.y, angle, {
        speed: s.speed, radius: 5, damage, lifetime, color: '#8be0ff',
      });
      p.attackSeq = this.attackSeq;
      p.damageOptions = {
        sourceWeaponId: 'talisman',
        sourceAction: 'projectile',
        sourceTags: ['lightning', 'projectile'],
      };
      p.onHit = (e) => this._onProjectileHit(e, p);
      world.projectiles.push(p);
    }
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
  triggerSwordThunder(e, world) {
    if (!e) return false;
    const damage = this.stats.damage * world.mods.damageMult * 0.6;
    if (!e.dead) world.damageEnemy(e, damage, {
      sourceWeaponId: 'talisman',
      sourceAction: 'sword-thunder',
      sourceTags: ['lightning', 'thunder', 'synergy'],
      synergyId: 'sword-talisman-mark',
      noSynergy: true,
      noSummon: true,
    });
    const total = 0.22;
    this.boltFx.push({ x: e.x, y: e.y, ttl: total, total, aoe: false, swordSynergy: true });
    world.recordSynergyTrigger?.('sword-talisman-mark', damage);
    return true;
  }

  _strikeThunder(e, dmg, world) {
    const s = this.stats;
    const total = 0.18;
    if (s.thunderAoE) {
      // 范围落雷：内部自动跳过死亡敌人，击杀走统一伤害入口
      hitEnemiesInRadius(world, e.x, e.y, 95, dmg, null, {
        sourceWeaponId: 'talisman',
        sourceAction: 'thunder',
        sourceTags: ['lightning', 'thunder', 'area'],
      });
    } else if (!e.dead) {
      world.damageEnemy(e, dmg, {
        sourceWeaponId: 'talisman',
        sourceAction: 'thunder',
        sourceTags: ['lightning', 'thunder'],
      });
    }
    this.boltFx.push({ x: e.x, y: e.y, ttl: total, total, aoe: !!s.thunderAoE });
  }

  // 闪电链：从命中目标出发，逐跳找 160px 内最近的未命中敌人弹射
  // Chain lightning can use one jade ring as a relay when no enemy is directly reachable. The relay does not consume a bounce.
  _chainLightning(origin, dmg, world) {
    const s = this.stats;
    const bounces = s.chainBounces || 2;
    const R2 = 180 * 180; // Maximum search radius per segment.
    const total = 0.15;
    const hitSet = new Set([origin]); // A chain cannot hit the same enemy twice.
    const ring = world.hasSynergy?.('talisman-ring-relay') ? world.getWeapon?.('ring') : null;
    const ringRelayPositions = ring ? ring.ringPositions(world) : [];
    const corpseRelayPositions = world.hasSynergy?.('talisman-staff-corpse-relay')
      ? (world.summons || []).filter((summon) => !summon.dead)
      : [];
    let ringRelayUsed = false;
    let corpseRelayUsed = false;
    let cur = origin;
    let hits = 0;
    let steps = 0;

    while (hits < bounces && steps < bounces + 2) {
      steps++;
      let best = null;
      let bestD = R2;
      for (const en of world.enemies) {
        if (en.dead || hitSet.has(en)) continue;
        const d = dist2(cur.x, cur.y, en.x, en.y);
        if (d <= bestD) { bestD = d; best = en; }
      }

      if (!best) {
        const relayCandidates = [];
        const findRelay = (type, positions) => {
          let candidate = null;
          let candidateScore = Infinity;
          let candidateEntryDistance = Infinity;
          for (const position of positions) {
            const entryDistance2 = dist2(cur.x, cur.y, position.x, position.y);
            if (entryDistance2 > R2) continue;
            for (const en of world.enemies) {
              if (en.dead || hitSet.has(en)) continue;
              const exitDistance2 = dist2(position.x, position.y, en.x, en.y);
              if (exitDistance2 > R2) continue;
              const score = Math.sqrt(entryDistance2) + Math.sqrt(exitDistance2);
              if (score < candidateScore || (score === candidateScore && entryDistance2 < candidateEntryDistance)) {
                candidate = position;
                candidateScore = score;
                candidateEntryDistance = entryDistance2;
              }
            }
          }
          if (candidate) relayCandidates.push({ type, position: candidate, score: candidateScore });
        };

        if (!ringRelayUsed) findRelay('ring', ringRelayPositions);
        if (!corpseRelayUsed) findRelay('corpse', corpseRelayPositions);
        relayCandidates.sort((a, b) => a.score - b.score);
        const relay = relayCandidates[0];
        if (relay) {
          const corpseRelay = relay.type === 'corpse';
          this.chainFx.push({
            x1: cur.x,
            y1: cur.y,
            x2: relay.position.x,
            y2: relay.position.y,
            ttl: total,
            total,
            relay: !corpseRelay,
            corpseRelay,
          });
          cur = relay.position;
          if (corpseRelay) {
            corpseRelayUsed = true;
            world.recordSynergyTrigger?.('talisman-staff-corpse-relay', 1);
          } else {
            ringRelayUsed = true;
            world.recordSynergyTrigger?.('talisman-ring-relay', 1);
          }
          continue;
        }
      }

      if (!best) break;
      hitSet.add(best);
      world.damageEnemy(best, dmg, {
        sourceWeaponId: 'talisman',
        sourceAction: 'chain',
        sourceTags: ['lightning', 'chain'],
      });
      this.chainFx.push({ x1: cur.x, y1: cur.y, x2: best.x, y2: best.y, ttl: total, total });
      cur = best;
      hits++;
    }
  }

  draw(ctx, world, phase) {
    if (phase !== 'over') return;
    // 闪电链线段（短暂显示）
    for (const fx of this.chainFx) {
      ctx.save();
      ctx.globalAlpha = Math.max(0, fx.ttl / fx.total);
      const color = fx.corpseRelay ? '#c78cff' : fx.relay ? '#ffad5c' : '#9be8ff';
      this._drawBoltLine(ctx, fx.x1, fx.y1, fx.x2, fx.y2, color, fx.relay || fx.corpseRelay ? 3 : 2);
      ctx.restore();
    }
    // 引雷：从天落雷 + Lv6 范围圈
    for (const fx of this.boltFx) {
      const a = Math.max(0, fx.ttl / fx.total);
      ctx.save();
      ctx.globalAlpha = a;
      const boltColor = fx.swordSynergy ? '#b8f7ff' : '#ffe98a';
      this._drawBoltLine(ctx, fx.x + 14, fx.y - 150, fx.x, fx.y, boltColor, fx.swordSynergy ? 4 : 3);
      if (fx.swordSynergy) {
        ctx.strokeStyle = '#fff59d';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(fx.x - 13, fx.y - 8);
        ctx.lineTo(fx.x + 13, fx.y + 8);
        ctx.moveTo(fx.x + 13, fx.y - 8);
        ctx.lineTo(fx.x - 13, fx.y + 8);
        ctx.stroke();
      }
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
  desc: '向远处敌人射出雷电弹道（低阶同时射向多个目标）。每命中 2 次触发引雷，Lv4 起命中还会弹射闪电链。',
  levels: [
    // Lv1 数值基准（4 道雷弹指向不同目标）
    { damage: 12, interval: 1.0, speed: 460, range: 520, count: 4 },
    // Lv2 解锁引雷
    { damage: 15, interval: 0.95, speed: 460, range: 520, count: 4, thunder: true },
    // Lv3 数值成长
    { damage: 19, interval: 0.88, speed: 460, range: 520, count: 4, thunder: true },
    // Lv4 解锁闪电链（弹射 2 次），雷弹数量回落为 2
    { damage: 23, interval: 0.81, speed: 460, range: 520, count: 2, thunder: true, chain: true, chainBounces: 2 },
    // Lv5 数值成长
    { damage: 27, interval: 0.75, speed: 460, range: 520, count: 2, thunder: true, chain: true, chainBounces: 2 },
    // Lv6 质变：链弹射 3 目标；每波攻击首命中必定引雷（不占计数）；引雷变范围伤害；单发但覆盖靠机制
    { damage: 31, interval: 0.70, speed: 490, range: 550, count: 1, thunder: true, thunderFirst: true, thunderAoE: true, chain: true, chainBounces: 3 },
  ],
  create() { return new TalismanWeapon(this); },
};