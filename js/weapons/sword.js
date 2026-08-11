import { WeaponBase, nearestEnemy, hitEnemiesInRadius } from './base.js';
import { dist2, angleDiff } from '../utils.js';
import { createProjectile } from '../projectile.js';

// ---------- 道剑：扇形挥砍 ----------
// Lv2「剑气」：每次挥砍沿挥砍方向发射穿透剑气（pierce 弹道，碰撞由 game 统一结算）
// Lv4「拔剑斩」：每第 3 次挥砍追加一次以玩家为中心的 360° 剑气环（2.5 倍伤害）
// Lv6「剑意」：拔剑斩带击飞；每击杀 10 个敌人 +1 飞剑（上限 10，15 秒后消散），
//              飞剑自动攻击玩家附近敌人并附加流血
export class SwordWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.swingCount = 0;      // 挥砍计数（拔剑斩每第 3 次触发）
    this.lastKills = -1;      // world.kills 增量基准（-1 = 尚未建立基线）
    this.killCarry = 0;       // 距离下一把飞剑的击杀积累（每 10 个一把）
    this.flyingSwords = [];   // 飞剑实例（Lv6 剑意）
    this.rings = [];          // 拔剑斩剑气环特效（武器自绘，不进 game.effects）
  }

  update(dt, world) {
    const s = this.stats;

    // ---- Lv6 剑意：击杀计数 -> 飞剑 ----
    if (s.swordIntent) this._updateKills(world, s);

    // ---- 飞剑行为 ----
    if (this.flyingSwords.length > 0) this._updateFlyingSwords(dt, world, s);

    // ---- 剑气环特效寿命 ----
    for (const r of this.rings) r.ttl -= dt;
    if (this.rings.length > 0) this.rings = this.rings.filter((r) => r.ttl > 0);

    // ---- 挥砍 ----
    this.timer -= dt;
    if (this.timer > 0) return;
    this.timer = s.interval / world.mods.attackSpeedMult;

    const px = world.player.x, py = world.player.y;
    // 朝最近敌人挥砍；没有目标就朝移动朝向
    const range = s.range * world.mods.areaMult;
    const target = nearestEnemy(world.enemies, px, py, (range * 1.8) ** 2);
    const angle = target
      ? Math.atan2(target.y - py, target.x - px)
      : world.player.facing;

    const halfArc = ((s.arc * Math.PI) / 180) / 2;
    const damage = s.damage * world.mods.damageMult;
    for (const e of world.enemies) {
      if (e.dead) continue;
      const d2 = dist2(px, py, e.x, e.y);
      if (d2 > (range + e.radius) ** 2) continue;
      const a = Math.atan2(e.y - py, e.x - px);
      if (angleDiff(a, angle) <= halfArc) world.damageEnemy(e, damage);
    }
    world.effects.push({
      type: 'slash', x: px, y: py,
      angle, range, arc: halfArc * 2, ttl: 0.18, maxTtl: 0.18,
    });

    this.swingCount++;

    // ---- Lv2 剑气：沿挥砍方向扇形发射穿透剑气，伤害 = 当次挥砍伤害 ----
    if (s.swordQi) {
      const n = s.qiCount || 3;
      const spread = 0.32; // 相邻剑气夹角 ~18°，3 道覆盖 ~54° 扇面
      for (let i = 0; i < n; i++) {
        const a = angle + (i - (n - 1) / 2) * spread;
        const p = createProjectile(px, py, a, {
          speed: 520, radius: 12, damage, lifetime: 0.6, color: '#aee9ff',
        });
        p.pierce = true;   // 穿透：路径上敌人均受击（hitSet 由 game 维护）
        p.swordQi = true;  // 标记：武器 draw 里补画剑刃拖影
        world.projectiles.push(p);
      }
    }

    // ---- Lv4 拔剑斩：每第 3 次挥砍，360° 剑气环，2.5 倍伤害 ----
    if (s.drawSlash && this.swingCount % 3 === 0) this._fireRing(world, s, damage);
  }

  // 拔剑斩：以玩家为中心的 360° 剑气环；Lv6 剑意附加 ~40px 击飞（解围）
  _fireRing(world, s, swingDamage) {
    const px = world.player.x, py = world.player.y;
    const radius = s.range * 1.25 * world.mods.areaMult;
    const knock = s.swordIntent ? 40 : 0;
    hitEnemiesInRadius(world, px, py, radius, swingDamage * 2.5, knock ? (e) => {
      if (e.dead) return;
      const dx = e.x - px, dy = e.y - py;
      const d = Math.sqrt(dx * dx + dy * dy) || 1;
      e.x += (dx / d) * knock;
      e.y += (dy / d) * knock;
    } : null);
    this.rings.push({ x: px, y: py, r: radius, ttl: 0.28, maxTtl: 0.28 });
  }

  // Lv6 剑意：用 world.kills 增量计数，每 10 击杀 +1 飞剑（上限 flyMax）
  _updateKills(world, s) {
    if (this.lastKills < 0) this.lastKills = world.kills; // 首帧建基线，不追溯历史击杀
    if (world.kills > this.lastKills) {
      this.killCarry += world.kills - this.lastKills;
      this.lastKills = world.kills;
    }
    // 有空位且积累足够就补出飞剑（封顶期间积累的击杀不浪费）
    const max = s.flyMax || 10;
    while (this.killCarry >= 10 && this.flyingSwords.length < max) {
      this.killCarry -= 10;
      this.flyingSwords.push({
        x: world.player.x, y: world.player.y,
        angle: Math.random() * Math.PI * 2,          // 环绕相位
        orbitR: 48 + (this.flyingSwords.length % 3) * 12, // 三档环绕半径，错落分布
        ttl: 15,                                      // 15 秒后消散
        atkTimer: 0.4,                                // 入场稍后即可出手
        state: 'orbit',                               // orbit | strike | return
        target: null,
        face: 0,                                      // 绘制朝向
      });
    }
  }

  // 飞剑：环绕玩家 -> 锁定附近敌人突刺（伤害 + 流血）-> 返回轨道；到期消散
  _updateFlyingSwords(dt, world, s) {
    const px = world.player.x, py = world.player.y;
    const flyDmg = (s.flyDmg || 20) * world.mods.damageMult;
    const searchR2 = ((s.flyRange || 180) * world.mods.areaMult) ** 2;
    const atkInterval = (s.flyInterval || 1.1) * world.mods.cooldownMult;

    for (const f of this.flyingSwords) {
      f.ttl -= dt;
      if (f.ttl <= 0) continue;

      if (f.state === 'orbit') {
        f.angle += dt * 2.4;
        const tx = px + Math.cos(f.angle) * f.orbitR;
        const ty = py + Math.sin(f.angle) * f.orbitR;
        f.x += (tx - f.x) * Math.min(1, dt * 10);
        f.y += (ty - f.y) * Math.min(1, dt * 10);
        f.face = f.angle + Math.PI / 2; // 沿切线方向
        f.atkTimer -= dt;
        if (f.atkTimer <= 0) {
          const t = nearestEnemy(world.enemies, px, py, searchR2);
          if (t) {
            f.state = 'strike';
            f.target = t;
            f.atkTimer = atkInterval;
          } else {
            f.atkTimer = 0.15; // 没有目标，稍后再找
          }
        }
      } else if (f.state === 'strike') {
        const t = f.target;
        if (!t || t.dead) { f.state = 'return'; f.target = null; continue; }
        const dx = t.x - f.x, dy = t.y - f.y;
        const d = Math.sqrt(dx * dx + dy * dy);
        f.face = Math.atan2(dy, dx);
        const step = 640 * dt;
        if (d <= step + t.radius + 6) {
          // 命中：伤害 + 流血 debuff
          world.damageEnemy(t, flyDmg);
          world.applyDot(t, 'bleed', 9, 2.5);
          f.state = 'return';
          f.target = null;
        } else {
          f.x += (dx / d) * step;
          f.y += (dy / d) * step;
          // 追出太远则放弃，防止飞剑脱队
          if (dist2(f.x, f.y, px, py) > 340 * 340) { f.state = 'return'; f.target = null; }
        }
      } else { // return：飞回轨道位
        const tx = px + Math.cos(f.angle) * f.orbitR;
        const ty = py + Math.sin(f.angle) * f.orbitR;
        const dx = tx - f.x, dy = ty - f.y;
        const d = Math.sqrt(dx * dx + dy * dy);
        f.face = Math.atan2(dy, dx);
        const step = 700 * dt;
        if (d <= step) { f.x = tx; f.y = ty; f.state = 'orbit'; }
        else { f.x += (dx / d) * step; f.y += (dy / d) * step; }
      }
    }
    this.flyingSwords = this.flyingSwords.filter((f) => f.ttl > 0);
  }

  // 武器自绘特效：剑气环 / 剑气剑刃 / 飞剑（over 相位，画在弹道之上）
  draw(ctx, world, phase) {
    if (phase !== 'over') return;

    // 拔剑斩剑气环：快速扩环并淡出
    for (const r of this.rings) {
      const t = 1 - r.ttl / r.maxTtl;
      const rr = r.r * (0.35 + 0.65 * t);
      ctx.save();
      ctx.beginPath();
      ctx.arc(r.x, r.y, rr, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(190,240,255,${((1 - t) * 0.85).toFixed(3)})`;
      ctx.lineWidth = 5;
      ctx.stroke();
      ctx.restore();
    }

    // 剑气剑刃：沿飞行方向补画细长剑形（弹道本体圆点由 game 绘制）
    for (const p of world.projectiles) {
      if (!p.swordQi || p.dead) continue;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.angle);
      ctx.beginPath();
      ctx.moveTo(-22, 0);
      ctx.lineTo(0, -4.5);
      ctx.lineTo(14, 0);
      ctx.lineTo(0, 4.5);
      ctx.closePath();
      ctx.fillStyle = 'rgba(174,233,255,0.9)';
      ctx.fill();
      ctx.restore();
    }

    // 飞剑：金色剑刃，消散前 1.5 秒渐隐
    for (const f of this.flyingSwords) {
      const fade = Math.min(1, f.ttl / 1.5);
      ctx.save();
      ctx.translate(f.x, f.y);
      ctx.rotate(f.face);
      ctx.beginPath();
      ctx.moveTo(-11, 0);
      ctx.lineTo(0, -3.2);
      ctx.lineTo(13, 0);
      ctx.lineTo(0, 3.2);
      ctx.closePath();
      ctx.fillStyle = `rgba(255,214,120,${(0.95 * fade).toFixed(3)})`;
      ctx.fill();
      ctx.restore();
    }
  }
}

export const CARD = {
  id: 'sword', kind: 'weapon', name: '道剑', icon: '⚔️', maxLevel: 6,
  desc: '朝最近敌人挥砍，对扇形范围内所有敌人造成伤害。Lv2 挥砍发射穿透剑气，Lv4 每 3 次挥砍追加 360° 拔剑斩，Lv6 觉醒「剑意」驭剑杀敌。',
  levels: [
    // Lv1：基础挥砍
    { damage: 12, range: 95, interval: 1.2, arc: 100 },
    // Lv2：解锁剑气（挥砍时发射 3 道穿透剑气，伤害 = 挥砍伤害）
    { damage: 16, range: 107, interval: 1.1, arc: 108, swordQi: true, qiCount: 3 },
    // Lv3：数值成长
    { damage: 21, range: 120, interval: 1.0, arc: 116, swordQi: true, qiCount: 3 },
    // Lv4：解锁拔剑斩（每第 3 次挥砍，360° 剑气环，2.5 倍伤害）
    { damage: 27, range: 132, interval: 0.9, arc: 124, swordQi: true, qiCount: 3, drawSlash: true },
    // Lv5：数值成长
    { damage: 34, range: 145, interval: 0.8, arc: 132, swordQi: true, qiCount: 3, drawSlash: true },
    // Lv6：质变「剑意」（拔剑斩击飞；每 10 击杀 +1 飞剑，上限 10，飞剑挂流血，15 秒消散）
    {
      damage: 42, range: 158, interval: 0.7, arc: 140,
      swordQi: true, qiCount: 3, drawSlash: true, swordIntent: true,
      flyMax: 10, flyDmg: 20, flyInterval: 1.1, flyRange: 180,
    },
  ],
  create() { return new SwordWeapon(this); },
};