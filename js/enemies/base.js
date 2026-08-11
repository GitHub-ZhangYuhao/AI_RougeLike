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
    if (this.hp >= this.maxHp) return;
    const width = this.radius * 2;
    const ratio = Math.max(0, this.hp / this.maxHp);
    const y = this.y - this.radius - 8;
    ctx.fillStyle = 'rgba(0,0,0,0.55)';
    ctx.fillRect(this.x - width / 2, y, width, 3);
    ctx.fillStyle = '#ff8a80';
    ctx.fillRect(this.x - width / 2, y, width * ratio, 3);
  }
}
