import { CONFIG } from '../config.js';
import { EnemyBase } from './base.js';

const BODY_COLOR = '#ab47bc';
const PROJECTILE_COLOR = '#ffb74d';
const DISTANCE_EPSILON = 12;
const SHOT_FLASH_DURATION = 0.16;

export class RangedEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0, options = {}) {
    const config = CONFIG.enemyTypes.ranged;
    super(x, y, elapsed, {
      ...options,
      type: 'ranged',
      rank: 'enhanced-minion',
      color: options.color ?? BODY_COLOR,
      hpMult: config.hpMult,
      speedMult: config.speedMult,
      damageMult: config.damageMult,
    });

    this.preferredDistance = config.preferredDistance;
    this.retreatDistance = config.retreatDistance;
    this.fireInterval = config.fireInterval;
    this.fireCooldown = this.fireInterval;
    this.projectileSpeed = config.projectileSpeed;
    this.projectileRadius = config.projectileRadius;
    this.projectileLifetime = config.projectileLifetime;
    this.shotFlash = 0;
    this.aimAngle = 0;
  }

  update(player, dt, world) {
    this.tickCommon(dt);
    this.shotFlash = Math.max(0, this.shotFlash - dt);

    const direction = this.directionTo(player);
    this.aimAngle = Math.atan2(direction.y, direction.x);

    if (direction.distance > this.preferredDistance + DISTANCE_EPSILON) {
      this.moveToward(player, dt);
    } else if (direction.distance < this.retreatDistance) {
      this.moveAwayFrom(player, dt);
    }

    this.fireCooldown -= dt;
    if (this.fireCooldown > 0) return;

    if (world && typeof world.spawnHostileProjectile === 'function') {
      const muzzleDistance = this.radius + this.projectileRadius + 3;
      world.spawnHostileProjectile({
        x: this.x + direction.x * muzzleDistance,
        y: this.y + direction.y * muzzleDistance,
        angle: this.aimAngle,
        speed: this.projectileSpeed,
        radius: this.projectileRadius,
        damage: this.damage,
        lifetime: this.projectileLifetime,
        color: PROJECTILE_COLOR,
      });
      this.shotFlash = SHOT_FLASH_DURATION;
    }

    this.fireCooldown = this.fireInterval;
  }

  draw(ctx) {
    this.drawBody(ctx);

    // A small barrel makes the ranged silhouette readable at a glance.
    const barrelStart = this.radius * 0.35;
    const barrelEnd = this.radius + 7;
    const cos = Math.cos(this.aimAngle);
    const sin = Math.sin(this.aimAngle);
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(this.x + cos * barrelStart, this.y + sin * barrelStart);
    ctx.lineTo(this.x + cos * barrelEnd, this.y + sin * barrelEnd);
    ctx.strokeStyle = this.shotFlash > 0 ? '#fff3b0' : '#ce93d8';
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    ctx.stroke();
    ctx.restore();

    if (this.shotFlash > 0) {
      ctx.beginPath();
      ctx.arc(
        this.x + cos * (barrelEnd + 3),
        this.y + sin * (barrelEnd + 3),
        4,
        0,
        Math.PI * 2,
      );
      ctx.fillStyle = '#fff3b0';
      ctx.fill();
    }

    this.drawHealthBar(ctx);
  }
}
