import { WeaponBase, nearestEnemy, hitEnemiesInRadius } from './base.js';
import { dist2, angleDiff } from '../utils.js';
import { createProjectile } from '../projectile.js';

// Dao sword: Lv1 melee, Lv2+ becomes a single ranged piercing sword.
export class SwordWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.attackCount = 0;
    this.lastKills = -1;
    this.killCarry = 0;
    this.flyingSwords = [];
    this.rings = [];
  }

  update(dt, world) {
    const s = this.stats;
    if (s.swordIntent) this._updateKills(world, s);
    if (this.flyingSwords.length) this._updateFlyingSwords(dt, world, s);

    for (const r of this.rings) r.ttl -= dt;
    this.rings = this.rings.filter((r) => r.ttl > 0);

    this.timer -= dt;
    if (this.timer > 0) return;
    this.timer = s.interval;

    const px = world.player.x;
    const py = world.player.y;
    const targetRange = s.projectile ? s.projectileRange : s.meleeRange * 1.8;
    const target = nearestEnemy(world.enemies, px, py, targetRange * targetRange);
    const angle = target ? Math.atan2(target.y - py, target.x - px) : world.player.facing;
    const damage = s.damage * world.mods.damageMult;

    if (s.projectile) this._fireMainSword(world, s, px, py, angle, damage);
    else this._meleeSlash(world, s, px, py, angle, damage);

    this.attackCount++;
    if (s.drawSlash && this.attackCount % 3 === 0) this._fireRing(world, s, damage);
  }

  _meleeSlash(world, s, px, py, angle, damage) {
    const halfArc = ((s.arc * Math.PI) / 180) / 2;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(px, py, e.x, e.y) > (s.meleeRange + e.radius) ** 2) continue;
      const enemyAngle = Math.atan2(e.y - py, e.x - px);
      if (angleDiff(enemyAngle, angle) <= halfArc) world.damageEnemy(e, damage);
    }
    world.effects.push({
      type: 'slash', x: px, y: py, angle,
      range: s.meleeRange, arc: halfArc * 2, ttl: 0.18, maxTtl: 0.18,
    });
  }

  _fireMainSword(world, s, px, py, angle, damage) {
    const p = createProjectile(px, py, angle, {
      speed: s.projectileSpeed,
      radius: 11,
      damage,
      lifetime: s.projectileRange / s.projectileSpeed,
      color: '#aee9ff',
    });
    p.pierce = true;
    p.maxHits = s.maxHits;
    p.swordQi = true;
    world.projectiles.push(p);
  }

  _fireRing(world, s, mainDamage) {
    const px = world.player.x;
    const py = world.player.y;
    hitEnemiesInRadius(world, px, py, s.ringRadius, mainDamage * 2.5, (e) => {
      if (!e.dead) world.applyDot(e, 'bleed', s.ringBleedDps || 10, 2.5);
    });
    this.rings.push({ x: px, y: py, r: s.ringRadius, ttl: 0.28, maxTtl: 0.28 });
  }

  _updateKills(world, s) {
    if (this.lastKills < 0) this.lastKills = world.kills;
    if (world.kills > this.lastKills) {
      this.killCarry += world.kills - this.lastKills;
      this.lastKills = world.kills;
    }
    while (this.killCarry >= 10) {
      this.killCarry -= 10;
      if (this.flyingSwords.length < s.flyMax) this._spawnFlyingSword(world);
    }
  }

  _spawnFlyingSword(world) {
    this.flyingSwords.push({
      x: world.player.x,
      y: world.player.y,
      angle: Math.random() * Math.PI * 2,
      orbitR: 48 + (this.flyingSwords.length % 3) * 12,
      ttl: 15,
      atkTimer: 0.4,
      state: 'orbit',
      target: null,
      face: 0,
    });
  }

  _updateFlyingSwords(dt, world, s) {
    const px = world.player.x;
    const py = world.player.y;
    const flyDamage = s.damage * world.mods.damageMult * 0.3;
    const searchR2 = s.flyRange * s.flyRange;

    for (const f of this.flyingSwords) {
      f.ttl -= dt;
      f.atkTimer -= dt;
      if (f.ttl <= 0) continue;

      if (f.state === 'orbit') {
        f.angle += dt * 2.4;
        const tx = px + Math.cos(f.angle) * f.orbitR;
        const ty = py + Math.sin(f.angle) * f.orbitR;
        f.x += (tx - f.x) * Math.min(1, dt * 10);
        f.y += (ty - f.y) * Math.min(1, dt * 10);
        f.face = f.angle + Math.PI / 2;
        if (f.atkTimer <= 0) {
          const target = nearestEnemy(world.enemies, px, py, searchR2);
          if (target) {
            f.state = 'strike';
            f.target = target;
            f.atkTimer = s.flyInterval;
          } else {
            f.atkTimer = 0.15;
          }
        }
      } else if (f.state === 'strike') {
        const target = f.target;
        if (!target || target.dead) {
          f.state = 'return';
          f.target = null;
          continue;
        }
        const dx = target.x - f.x;
        const dy = target.y - f.y;
        const distance = Math.hypot(dx, dy) || 1;
        f.face = Math.atan2(dy, dx);
        const step = 640 * dt;
        if (distance <= step + target.radius + 6) {
          world.damageEnemy(target, flyDamage);
          if (!target.dead) world.applyDot(target, 'bleed', 9, 2.5);
          f.state = 'return';
          f.target = null;
        } else {
          f.x += (dx / distance) * step;
          f.y += (dy / distance) * step;
          if (dist2(f.x, f.y, px, py) > 340 * 340) {
            f.state = 'return';
            f.target = null;
          }
        }
      } else {
        const tx = px + Math.cos(f.angle) * f.orbitR;
        const ty = py + Math.sin(f.angle) * f.orbitR;
        const dx = tx - f.x;
        const dy = ty - f.y;
        const distance = Math.hypot(dx, dy) || 1;
        f.face = Math.atan2(dy, dx);
        const step = 700 * dt;
        if (distance <= step) {
          f.x = tx;
          f.y = ty;
          f.state = 'orbit';
        } else {
          f.x += (dx / distance) * step;
          f.y += (dy / distance) * step;
        }
      }
    }
    this.flyingSwords = this.flyingSwords.filter((f) => f.ttl > 0);
  }

  draw(ctx, world, phase) {
    if (phase !== 'over') return;

    for (const r of this.rings) {
      const progress = 1 - r.ttl / r.maxTtl;
      const radius = r.r * (0.35 + 0.65 * progress);
      ctx.save();
      ctx.beginPath();
      ctx.arc(r.x, r.y, radius, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(190,240,255,${((1 - progress) * 0.85).toFixed(3)})`;
      ctx.lineWidth = 5;
      ctx.stroke();
      ctx.restore();
    }

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
  desc: 'Lv1 近战挥砍，Lv2 起御剑远程贯穿；Lv4 每 3 次攻击追加拔剑斩，Lv6 觉醒剑意。',
  levels: [
    { damage: 14, meleeRange: 96, interval: 1.15, arc: 105 },
    { damage: 18, projectile: true, projectileRange: 520, projectileSpeed: 500, maxHits: 2, interval: 1.08 },
    { damage: 23, projectile: true, projectileRange: 550, projectileSpeed: 560, maxHits: 2, interval: 1.00 },
    { damage: 29, projectile: true, projectileRange: 570, projectileSpeed: 580, maxHits: 2, interval: 0.94,
      drawSlash: true, ringRadius: 145, ringBleedDps: 10 },
    { damage: 36, projectile: true, projectileRange: 600, projectileSpeed: 620, maxHits: 4, interval: 0.87,
      drawSlash: true, ringRadius: 158, ringBleedDps: 11 },
    { damage: 44, projectile: true, projectileRange: 640, projectileSpeed: 660, maxHits: Infinity, interval: 0.80,
      drawSlash: true, ringRadius: 172, ringBleedDps: 12, swordIntent: true,
      flyMax: 10, flyInterval: 1.2, flyRange: 220 },
  ],
  create() { return new SwordWeapon(this); },
};