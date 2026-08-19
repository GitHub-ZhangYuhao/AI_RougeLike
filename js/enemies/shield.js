import { CONFIG } from '../config.js';
import { EnemyBase } from './base.js';

export class ShieldEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0) {
    const config = CONFIG.enemyTypes.shield;
    super(x, y, elapsed, {
      type: 'shield',
      rank: 'normal',
      hpMult: config.hpMult,
      speedMult: config.speedMult,
      damageMult: config.damageMult,
      color: '#78909c',
    });

    this.phase = 'shielded';
    this.phaseTimer = config.shieldDuration;
  }

  update(player, dt, world) {
    this.tickCommon(dt);
    this.advancePhase(dt);
    this.moveToward(player, dt);
  }

  advancePhase(dt) {
    const config = CONFIG.enemyTypes.shield;
    this.phaseTimer -= dt;

    while (this.phaseTimer <= 0) {
      if (this.phase === 'shielded') {
        this.phase = 'open';
        this.phaseTimer += config.openDuration;
      } else {
        this.phase = 'shielded';
        this.phaseTimer += config.shieldDuration;
      }
    }
  }

  modifyIncomingDamage(damage) {
    const config = CONFIG.enemyTypes.shield;
    const multiplier = this.phase === 'shielded'
      ? config.shieldDamageMult
      : config.openDamageMult;
    return damage * multiplier;
  }

  draw(ctx) {
    const shielded = this.phase === 'shielded';
    this.drawBody(ctx, shielded ? '#607d8b' : '#a1887f');

    ctx.save();
    ctx.lineWidth = shielded ? 4 : 3;
    ctx.strokeStyle = shielded ? '#80deea' : '#ffb74d';
    ctx.globalAlpha = shielded ? 0.9 : 0.8;

    if (shielded) {
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.radius + 7, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      const ringRadius = this.radius + 7;
      ctx.beginPath();
      ctx.arc(this.x, this.y, ringRadius, 0.2, Math.PI - 0.2);
      ctx.arc(this.x, this.y, ringRadius, Math.PI + 0.2, Math.PI * 2 - 0.2);
      ctx.stroke();
    }

    ctx.restore();
    this.drawHealthBar(ctx);
  }
}
