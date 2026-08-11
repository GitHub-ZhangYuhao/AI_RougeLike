import { WeaponBase, hitEnemiesInRadius } from './base.js';
import { dist2 } from '../utils.js';

// ---------- 丹火：移动留下灼烧路径 ----------
export class TrailWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.lastKillId = 0; // killLog 增量消费游标
    this.blasts = [];    // 爆燃爆炸特效（自绘，不进 game.effects）
    this.healTimer = 0;  // Lv6 火中回血节流计时
  }

  update(dt, world) {
    const s = this.stats;

    // killLog 消费：无论爆燃是否解锁都推进游标，
    // 避免解锁 Lv4（或中途拿到本武器）时回爆历史击杀
    if (world.killLog && world.killLog.length) {
      for (const k of world.killLog) {
        if (k.id <= this.lastKillId) continue;
        this.lastKillId = k.id;
        // 爆燃：带烈焰（burned=true）的敌人死亡时在死亡点爆炸
        if (!s.blast || !k.burned) continue;
        const radius = s.blastRadius * world.mods.areaMult;
        // 伤害 ≈ 地面 tick ×2；爆炸击杀会写回 killLog，天然支持连锁（每条只爆一次）
        hitEnemiesInRadius(world, k.x, k.y, radius, s.damage * world.mods.damageMult * 2);
        this.blasts.push({ x: k.x, y: k.y, r: radius, ttl: 0.35, maxTtl: 0.35 });
        // Lv6 质变：爆燃爆炸时 20% 概率在该点掉血包（同屏上限由系统控制）
        if (s.blastDrop && Math.random() < 0.2) world.dropPickup(k.x, k.y);
      }
    }

    // 爆燃特效衰减
    if (this.blasts.length) {
      for (const b of this.blasts) b.ttl -= dt;
      this.blasts = this.blasts.filter((b) => b.ttl > 0);
    }

    // Lv6 质变：玩家站在自己的丹火地面上回血（封顶 1 点/0.5s）
    if (s.healOnTrail) {
      const p = world.player;
      let onFire = false;
      for (const t of world.trails) {
        if (t.dead) continue;
        if (dist2(t.x, t.y, p.x, p.y) <= (t.radius + p.radius) ** 2) { onFire = true; break; }
      }
      if (onFire) {
        this.healTimer -= dt;
        if (this.healTimer <= 0) {
          world.healPlayer(1);
          this.healTimer = 0.5;
        }
      } else {
        this.healTimer = 0; // 离开火面重置，重新踩入立即生效
      }
    }

    // ---------- 地面段落投放（原有逻辑保持不变） ----------
    this.timer -= dt;
    if (this.timer < 0) this.timer = 0;
    if (this.timer > 0 || !world.player.moving) return;
    this.timer = s.dropInterval * world.mods.cooldownMult;
    world.trails.push({
      x: world.player.x, y: world.player.y,
      radius: s.radius * world.mods.areaMult,
      damage: s.damage * world.mods.damageMult,
      life: s.life, maxLife: s.life,
      tickTimer: 0, tick: 0.4, // 每 0.4s 对站在上面的敌人结算一次
      burnDps: s.burn ? s.burnDps : 0, // 烈焰：tick 命中挂 burn 的威力（0=未解锁，旧对象无此字段也安全）
      dead: false,
    });
    if (world.trails.length > 60) world.trails.shift();
  }

  // 爆燃爆炸特效：扩张火环 + 内部闪光
  draw(ctx, world, phase) {
    if (phase !== 'over' || this.blasts.length === 0) return;
    for (const b of this.blasts) {
      const p = 1 - b.ttl / b.maxTtl; // 0→1 扩张进度
      const rr = b.r * (0.4 + 0.6 * p);
      ctx.globalAlpha = 0.6 * (1 - p);
      ctx.beginPath();
      ctx.arc(b.x, b.y, rr, 0, Math.PI * 2);
      ctx.strokeStyle = '#ff5722';
      ctx.lineWidth = 4;
      ctx.stroke();
      ctx.globalAlpha = 0.3 * (1 - p);
      ctx.beginPath();
      ctx.arc(b.x, b.y, rr * 0.55, 0, Math.PI * 2);
      ctx.fillStyle = '#ffcc80';
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }
}

// 丹火地面段落的更新与绘制（由 game 统一驱动）
export function updateTrail(t, world, dt) {
  t.life -= dt;
  if (t.life <= 0) { t.dead = true; return; }
  t.tickTimer -= dt;
  if (t.tickTimer <= 0) {
    t.tickTimer = t.tick;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(t.x, t.y, e.x, e.y) <= (t.radius + e.radius) ** 2) {
        // 烈焰（Lv2+）：先挂 burn 再结算伤害，本次 tick 直接击杀也计入 burned，供爆燃消费
        if (t.burnDps) world.applyDot(e, 'burn', t.burnDps, 2);
        world.damageEnemy(e, t.damage);
      }
    }
  }
}

export function drawTrail(ctx, t) {
  const k = Math.max(0, t.life / t.maxLife);
  ctx.globalAlpha = 0.30 * k + 0.08;
  ctx.beginPath();
  ctx.arc(t.x, t.y, t.radius, 0, Math.PI * 2);
  ctx.fillStyle = '#ff9800';
  ctx.fill();
  ctx.globalAlpha = 0.5 * k;
  ctx.beginPath();
  ctx.arc(t.x, t.y, t.radius * 0.55, 0, Math.PI * 2);
  ctx.fillStyle = '#ffd54f';
  ctx.fill();
  ctx.globalAlpha = 1;
}

export const CARD = {
  id: 'trail', kind: 'weapon', name: '丹火', icon: '🔥', maxLevel: 6,
  desc: '移动时在脚下留下燃烧路径，踩上的敌人持续扣血。高解锁烈焰灼烧与爆燃（带火敌人死亡时爆炸），满级站火回血。',
  levels: [
    // Lv1 基础数值
    { damage: 6, radius: 26, life: 2.5, dropInterval: 0.25 },
    // Lv2 机制「烈焰」：地面 tick 命中挂 burn（dps 随级成长，持续 2s）
    { damage: 8, radius: 29, life: 2.9, dropInterval: 0.25, burn: true, burnDps: 10 },
    // Lv3 数值成长
    { damage: 11, radius: 32, life: 3.2, dropInterval: 0.25, burn: true, burnDps: 12 },
    // Lv4 机制「爆燃」：burned 击杀在死亡点爆炸（半径 60~70 区间，伤害 ≈ tick×2）
    { damage: 13, radius: 35, life: 3.6, dropInterval: 0.25, burn: true, burnDps: 13, blast: true, blastRadius: 64 },
    // Lv5 数值成长
    { damage: 16, radius: 38, life: 4.0, dropInterval: 0.25, burn: true, burnDps: 14, blast: true, blastRadius: 66 },
    // Lv6 质变：站火回血 1点/0.5s + 爆燃 20% 掉血包 + 爆燃半径 +50%（66→99）
    { damage: 19, radius: 42, life: 4.5, dropInterval: 0.25, burn: true, burnDps: 16, blast: true, blastRadius: 99, healOnTrail: true, blastDrop: true },
  ],
  create() { return new TrailWeapon(this); },
};