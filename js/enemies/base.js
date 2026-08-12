import { CONFIG } from '../config.js';
import { rand } from '../utils.js';
import { speedMultOf } from '../systems/status.js';

// Shared enemy state and movement helpers. Specialized enemies only override
// update/draw or damage modification; status fields stay compatible with weapons.
export class EnemyBase {
  constructor(x, y, elapsed = 0, options = {}) {
    const c = CONFIG.enemy;
    const minutes = elapsed / 60;
    const jitter = options.speedVariance === false
      ? 1
      : 1 + rand(-c.speedVariance, c.speedVariance);

    this.x = x;
    this.y = y;
    this.radius = options.radius ?? c.radius;
    this.type = options.type ?? 'chaser';
    this.rank = options.rank ?? 'normal';
    this.color = options.color ?? c.color;

    const hpMult = options.hpMult ?? 1;
    const speedMult = options.speedMult ?? 1;
    const damageMult = options.damageMult ?? 1;
    this.maxHp = (c.hp + c.hpPerMin * minutes) * hpMult;
    this.hp = this.maxHp;
    this.speed = c.speed * jitter * (1 + c.speedPerMin * minutes) * speedMult;
    this.damage = (c.damage + c.damagePerMin * minutes) * damageMult;

    this.hitCooldown = 0;
    this.hitFlash = 0;
    this.ringCd = 0;
    this.dead = false;

    this.dots = {};
    this.slowTimer = 0;
    this.slowFactor = 0;
    this.frozenTimer = 0;
  }

  tickCommon(dt) {
    if (this.hitCooldown > 0) this.hitCooldown -= dt;
    if (this.hitFlash > 0) this.hitFlash -= dt;
    if (this.ringCd > 0) this.ringCd -= dt;
  }

  distanceTo(target) {
    return Math.hypot(target.x - this.x, target.y - this.y);
  }

  directionTo(target) {
    const dx = target.x - this.x;
    const dy = target.y - this.y;
    const distance = Math.hypot(dx, dy) || 1;
    return { x: dx / distance, y: dy / distance, distance };
  }

  moveToward(target, dt, speed = this.speed) {
    const statusMult = speedMultOf(this);
    if (statusMult <= 0) return;
    const dir = this.directionTo(target);
    this.x += dir.x * speed * statusMult * dt;
    this.y += dir.y * speed * statusMult * dt;
  }

  moveAwayFrom(target, dt, speed = this.speed) {
    const statusMult = speedMultOf(this);
    if (statusMult <= 0) return;
    const dir = this.directionTo(target);
    this.x -= dir.x * speed * statusMult * dt;
    this.y -= dir.y * speed * statusMult * dt;
  }

  update(player, dt, world) {
    this.tickCommon(dt);
    this.moveToward(player, dt);
  }

  modifyIncomingDamage(damage) {
    return damage;
  }

  draw(ctx) {
    this.drawBody(ctx);
    this.drawHealthBar(ctx);
  }

  drawBody(ctx, color = this.color) {
    ctx.beginPath();
    ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
    ctx.fillStyle = this.hitFlash > 0 ? '#ffffff'
      : (this.frozenTimer > 0 ? '#81d4fa' : color);
    ctx.fill();
  }

  drawHealthBar(ctx) {
    if (this.rank === 'normal' && this.hp >= this.maxHp) return;
    const width = this.radius * (this.rank === 'boss' ? 2.4 : 2);
    const height = this.rank === 'normal' ? 3 : 5;
    const ratio = Math.max(0, this.hp / this.maxHp);
    const y = this.y - this.radius - (this.rank === 'normal' ? 8 : 13);
    ctx.fillStyle = 'rgba(0,0,0,0.68)';
    ctx.fillRect(this.x - width / 2, y, width, height);
    ctx.fillStyle = this.rank === 'elite' ? '#ffd54f'
      : (this.rank === 'boss' ? '#b388ff' : '#ff8a80');
    ctx.fillRect(this.x - width / 2, y, width * ratio, height);
  }
}

// Apply wave growth after the concrete enemy has applied its own type/rank
// multipliers. This keeps legacy constructors compatible while letting every
// enemy type, including bosses and elites, share the same wave curve.
export function applyWaveScaling(enemy, wave = 1) {
  const normalizedWave = Number.isFinite(wave) ? Math.max(1, Math.floor(wave)) : 1;
  if (enemy.waveScalingApplied) return enemy;

  const step = normalizedWave - 1;
  // Waves 1-6 are gentle, 7-11 catch up, and 12+ scale beyond the old curve.
  const earlySteps = Math.min(step, CONFIG.enemy.midWaveStart - 2);
  const midSteps = Math.min(
    Math.max(0, step - earlySteps),
    CONFIG.enemy.lateWaveStart - CONFIG.enemy.midWaveStart,
  );
  const lateSteps = Math.max(0, step - earlySteps - midSteps);
  const hpMult = 1
    + CONFIG.enemy.hpPerWave * earlySteps
    + CONFIG.enemy.hpPerWaveMid * midSteps
    + CONFIG.enemy.hpPerWaveLate * lateSteps;
  const damageMult = 1
    + CONFIG.enemy.damagePerWave * earlySteps
    + CONFIG.enemy.damagePerWaveMid * midSteps
    + CONFIG.enemy.damagePerWaveLate * lateSteps;
  const speedBonus = CONFIG.enemy.speedPerWave * earlySteps
    + CONFIG.enemy.speedPerWaveMid * midSteps
    + CONFIG.enemy.speedPerWaveLate * lateSteps;
  const speedMult = 1 + Math.min(CONFIG.enemy.speedWaveCap, speedBonus);
  const hpRatio = enemy.maxHp > 0 ? enemy.hp / enemy.maxHp : 1;

  enemy.maxHp *= hpMult;
  enemy.hp = enemy.maxHp * hpRatio;
  enemy.damage *= damageMult;
  enemy.speed *= speedMult;
  enemy.wave = normalizedWave;
  enemy.waveScalingApplied = true;
  return enemy;
}
