import { CONFIG } from '../config.js';
import { EnemyBase } from './base.js';

const BODY_COLOR = '#ff7043';
const WARNING_COLOR = '#ffca28';
const BLAST_COLOR = '#ff8a50';

export class BomberEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0, options = {}) {
    const config = CONFIG.enemyTypes.bomber;
    super(x, y, elapsed, {
      ...options,
      type: 'bomber',
      rank: 'enhanced-minion',
      color: options.color ?? BODY_COLOR,
      hpMult: config.hpMult,
      speedMult: config.speedMult,
      damageMult: config.damageMult,
    });

    this.state = 'approach';
    this.windupTimer = 0;
    this.exploded = false;

    this.triggerDistance = config.triggerDistance;
    this.windupDuration = config.windup;
    this.blastRadius = config.blastRadius;
  }

  update(player, dt, world) {
    if (this.dead || this.hp <= 0 || this.exploded) return;

    this.tickCommon(dt);

    if (this.state === 'approach') {
      if (this.distanceTo(player) <= this.triggerDistance) {
        this.state = 'windup';
        this.windupTimer = 0;
      } else {
        this.moveToward(player, dt);
      }
      return;
    }

    this.windupTimer += dt;
    if (this.windupTimer < this.windupDuration) return;

    // Mark the explosion first so a repeated update cannot deal damage twice.
    this.exploded = true;

    if (this.distanceTo(player) <= this.blastRadius) {
      world.hurtPlayer(this.damage);
    }

    world.spawnEnemyBlast({
      x: this.x,
      y: this.y,
      radius: this.blastRadius,
      color: BLAST_COLOR,
    });
    this.dead = true;
  }

  draw(ctx) {
    if (this.state === 'windup' && !this.dead) {
      const progress = Math.min(1, this.windupTimer / this.windupDuration);
      const pulse = 0.35 + 0.3 * Math.sin(this.windupTimer * 24);

      ctx.save();
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.blastRadius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(255, 112, 67, ${0.08 + progress * 0.12})`;
      ctx.fill();
      ctx.strokeStyle = WARNING_COLOR;
      ctx.globalAlpha = 0.55 + progress * 0.45;
      ctx.lineWidth = 2 + progress * 2;
      ctx.stroke();
      ctx.restore();

      ctx.save();
      ctx.globalAlpha = pulse + progress * 0.35;
      this.drawBody(ctx, WARNING_COLOR);
      ctx.restore();
    } else {
      this.drawBody(ctx);
    }

    this.drawHealthBar(ctx);
  }
}
