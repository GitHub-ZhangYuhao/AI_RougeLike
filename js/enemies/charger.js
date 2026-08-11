import { CONFIG } from '../config.js';
import { speedMultOf } from '../systems/status.js';
import { EnemyBase } from './base.js';

const BODY_COLORS = {
  chase: '#ff7043',
  windup: '#ffca28',
  dash: '#ff3d00',
  recovery: '#bf6d5a',
};

export class ChargerEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0) {
    const config = CONFIG.enemyTypes.charger;
    super(x, y, elapsed, {
      type: 'charger',
      rank: 'enhanced',
      color: BODY_COLORS.chase,
      hpMult: config.hpMult,
      speedMult: config.speedMult,
      damageMult: config.damageMult,
    });

    this.state = 'chase';
    this.stateTimer = 0;
    this.chargeCooldown = 0;
    this.lockedDirection = { x: 1, y: 0 };
  }

  update(player, dt, world) {
    this.tickCommon(dt);
    if (this.chargeCooldown > 0) {
      this.chargeCooldown = Math.max(0, this.chargeCooldown - dt);
    }

    switch (this.state) {
      case 'windup':
        this.updateWindup(dt);
        break;
      case 'dash':
        this.updateDash(dt);
        break;
      case 'recovery':
        this.updateRecovery(dt);
        break;
      case 'chase':
      default:
        this.updateChase(player, dt);
        break;
    }
  }

  updateChase(player, dt) {
    const config = CONFIG.enemyTypes.charger;
    this.moveToward(player, dt);

    if (this.chargeCooldown <= 0 && this.distanceTo(player) <= config.chargeRange) {
      const direction = this.directionTo(player);
      this.lockedDirection = { x: direction.x, y: direction.y };
      this.state = 'windup';
      this.stateTimer = config.windup;
    }
  }

  updateWindup(dt) {
    this.stateTimer -= dt;
    if (this.stateTimer <= 0) {
      this.state = 'dash';
      this.stateTimer = CONFIG.enemyTypes.charger.dashDuration;
    }
  }

  updateDash(dt) {
    const config = CONFIG.enemyTypes.charger;
    const statusSpeed = speedMultOf(this);
    this.x += this.lockedDirection.x * config.dashSpeed * statusSpeed * dt;
    this.y += this.lockedDirection.y * config.dashSpeed * statusSpeed * dt;

    this.stateTimer -= dt;
    if (this.stateTimer <= 0) {
      this.state = 'recovery';
      this.stateTimer = config.recovery;
    }
  }

  updateRecovery(dt) {
    this.stateTimer -= dt;
    if (this.stateTimer <= 0) {
      this.state = 'chase';
      this.stateTimer = 0;
      this.chargeCooldown = CONFIG.enemyTypes.charger.cooldown;
    }
  }

  draw(ctx) {
    if (this.state === 'windup') this.drawWindupWarning(ctx);
    if (this.state === 'dash') this.drawDashTrail(ctx);

    this.drawBody(ctx, BODY_COLORS[this.state] || this.color);

    if (this.state === 'windup') {
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.radius + 5, 0, Math.PI * 2);
      ctx.strokeStyle = '#ffe082';
      ctx.lineWidth = 3;
      ctx.stroke();
    }

    this.drawHealthBar(ctx);
  }

  drawWindupWarning(ctx) {
    const config = CONFIG.enemyTypes.charger;
    const warningLength = config.dashSpeed * config.dashDuration;
    const progress = 1 - Math.max(0, this.stateTimer) / config.windup;

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(
      this.x + this.lockedDirection.x * this.radius,
      this.y + this.lockedDirection.y * this.radius,
    );
    ctx.lineTo(
      this.x + this.lockedDirection.x * warningLength,
      this.y + this.lockedDirection.y * warningLength,
    );
    ctx.strokeStyle = `rgba(255, 202, 40, ${0.35 + progress * 0.55})`;
    ctx.lineWidth = 2 + progress * 2;
    ctx.stroke();
    ctx.restore();
  }

  drawDashTrail(ctx) {
    const trailLength = this.radius * 2.5;
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(this.x, this.y);
    ctx.lineTo(
      this.x - this.lockedDirection.x * trailLength,
      this.y - this.lockedDirection.y * trailLength,
    );
    ctx.strokeStyle = 'rgba(255, 61, 0, 0.55)';
    ctx.lineWidth = this.radius;
    ctx.stroke();
    ctx.restore();
  }
}
