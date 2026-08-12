import { WeaponBase } from './base.js';
import { dist2 } from '../utils.js';

export class CloakWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.shockTimer = 0;
    this.shocks = [];
    this.lastKills = -1;
  }

  update(dt, world) {
    const s = this.stats;
    const px = world.player.x;
    const py = world.player.y;

    // Aura damage always ticks every 0.5 seconds.
    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 0.5;
      const damage = s.damage * world.mods.damageMult;
      for (const e of world.enemies) {
        if (e.dead) continue;
        if (dist2(px, py, e.x, e.y) <= (s.radius + e.radius) ** 2) {
          world.damageEnemy(e, damage);
          if (s.burn && !e.dead) world.applyDot(e, 'burn', s.burnDps, 2);
        }
      }
    }

    if (s.shock) {
      // Lv6: each crossed 100-kill threshold fires an extra enhanced shock.
      // This does not modify the normal shock cooldown.
      if (s.enhancedKillShock && this.lastKills >= 0) {
        const previous = Math.floor(this.lastKills / 100);
        const current = Math.floor(world.kills / 100);
        for (let i = previous; i < current; i++) this.fireShock(world, true);
      }

      this.shockTimer -= dt;
      if (this.shockTimer <= 0) {
        this.shockTimer = s.shockCd;
        this.fireShock(world, false);
      }
    }
    this.lastKills = world.kills;

    for (const shock of this.shocks) shock.t += dt;
    this.shocks = this.shocks.filter((shock) => shock.t < shock.ttl);
  }

  fireShock(world, enhanced = false) {
    const s = this.stats;
    const px = world.player.x;
    const py = world.player.y;
    const radiusMult = enhanced ? 1.8 : s.shockRadiusMult;
    const ticks = enhanced ? 8 : s.shockTicks;
    const slowDuration = enhanced ? 3 : (s.shockSlow ? 2 : 0);
    const radius = s.radius * radiusMult;
    const damage = s.damage * ticks * world.mods.damageMult;

    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(px, py, e.x, e.y) <= (radius + e.radius) ** 2) {
        world.damageEnemy(e, damage);
        if (e.dead) continue;
        world.applyDot(e, 'burn', s.burnDps, 2);
        if (slowDuration > 0) world.applySlow(e, 0.3, slowDuration);
      }
    }
    this.shocks.push({ x: px, y: py, maxR: radius, t: 0, ttl: 0.45, enhanced });
  }

  draw(ctx, world, phase) {
    if (phase === 'under') {
      ctx.save();
      ctx.globalAlpha = 0.10 + 0.04 * Math.sin(world.elapsed * 4);
      ctx.beginPath();
      ctx.arc(world.player.x, world.player.y, this.stats.radius, 0, Math.PI * 2);
      ctx.fillStyle = '#ff7043';
      ctx.fill();
      ctx.globalAlpha = 0.4;
      ctx.strokeStyle = '#ff8a65';
      ctx.lineWidth = 1.5;
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (phase !== 'over') return;

    ctx.save();
    for (const shock of this.shocks) {
      const progress = shock.t / shock.ttl;
      const radius = Math.max(1, shock.maxR * (1 - (1 - progress) ** 2));
      const fade = 1 - progress;
      ctx.globalAlpha = 0.9 * fade;
      ctx.strokeStyle = shock.enhanced ? '#fff176' : '#ffd54f';
      ctx.lineWidth = (shock.enhanced ? 3 : 1.5) + 3.5 * fade;
      ctx.beginPath();
      ctx.arc(shock.x, shock.y, radius, 0, Math.PI * 2);
      ctx.stroke();
      ctx.globalAlpha = 0.28 * fade;
      ctx.strokeStyle = shock.enhanced ? '#ff3d00' : '#ff7043';
      ctx.lineWidth = 2 + 10 * fade;
      ctx.beginPath();
      ctx.arc(shock.x, shock.y, Math.max(1, radius * 0.9), 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }
}

export const CARD = {
  id: 'cloak', kind: 'weapon', name: '炽热披风', icon: '🔥', maxLevel: 6,
  desc: '持续灼烧附近敌人；Lv4 周期释放震荡冲击，Lv6 每 100 杀额外释放一次强化冲击。',
  levels: [
    { damage: 5, radius: 85 },
    { damage: 7, radius: 98, burn: true, burnDps: 10 },
    { damage: 10, radius: 110, burn: true, burnDps: 12 },
    { damage: 12, radius: 125, burn: true, burnDps: 14, shock: true, shockCd: 5.5, shockTicks: 6, shockRadiusMult: 1.7 },
    { damage: 15, radius: 138, burn: true, burnDps: 16, shock: true, shockCd: 5.2, shockTicks: 6, shockRadiusMult: 1.7 },
    { damage: 18, radius: 152, burn: true, burnDps: 16, shock: true, shockCd: 3, shockTicks: 6,
      shockRadiusMult: 1.8, shockSlow: true, enhancedKillShock: true },
  ],
  create() { return new CloakWeapon(this); },
};