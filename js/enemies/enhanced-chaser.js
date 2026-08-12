import { CONFIG } from '../config.js';
import { EnemyBase } from './base.js';

const NORMAL_COLOR = '#d84315';
const WARNING_COLOR = '#ffca28';
const ENRAGED_COLOR = '#b71c1c';

export class EnhancedChaserEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0) {
    const config = CONFIG.enemyTypes.enhancedChaser;
    super(x, y, elapsed, {
      type: 'enhancedChaser',
      rank: 'enhanced-minion',
      radius: CONFIG.enemy.radius + 2,
      color: NORMAL_COLOR,
      hpMult: config.hpMult,
      speedMult: config.speedMult,
      damageMult: config.damageMult,
    });

    this.enrageTriggered = false;
    this.enraged = false;
    this.warningTimer = 0;
    this.warningDuration = config.warningDuration;
  }

  update(player, dt, world) {
    this.tickCommon(dt);
    const config = CONFIG.enemyTypes.enhancedChaser;

    if (!this.enrageTriggered && this.hp <= this.maxHp * config.enrageHpRatio) {
      this.enrageTriggered = true;
      this.warningTimer = this.warningDuration;
    }

    if (this.warningTimer > 0) {
      this.warningTimer = Math.max(0, this.warningTimer - dt);
      // Brief hesitation makes the transition readable without fully stopping pursuit.
      this.moveToward(player, dt, this.speed * 0.3);
      if (this.warningTimer <= 0) this.enterEnrage();
      return;
    }

    this.moveToward(player, dt);
  }

  enterEnrage() {
    if (this.enraged) return;
    const config = CONFIG.enemyTypes.enhancedChaser;
    this.enraged = true;
    this.speed *= config.enragedSpeedMult;
    this.damage *= config.enragedDamageMult;
    this.color = ENRAGED_COLOR;
  }

  draw(ctx) {
    const warning = this.warningTimer > 0;
    const pulse = 0.5 + 0.5 * Math.sin(this.warningTimer * 45);
    this.drawBody(ctx, warning ? WARNING_COLOR : this.color);

    ctx.save();
    ctx.translate(this.x, this.y);
    ctx.strokeStyle = warning ? `rgba(255,235,59,${0.55 + pulse * 0.4})`
      : (this.enraged ? '#ff5252' : '#ff8a65');
    ctx.lineWidth = warning ? 4 : 3;
    ctx.beginPath();
    ctx.arc(0, 0, this.radius + (warning ? 7 + pulse * 5 : 5), 0, Math.PI * 2);
    ctx.stroke();

    // Four outward fangs keep the silhouette distinct from a normal chaser.
    ctx.fillStyle = warning ? WARNING_COLOR : (this.enraged ? '#ff5252' : '#ff7043');
    for (let i = 0; i < 4; i++) {
      ctx.rotate(Math.PI / 2);
      ctx.beginPath();
      ctx.moveTo(this.radius + 2, -4);
      ctx.lineTo(this.radius + 10, 0);
      ctx.lineTo(this.radius + 2, 4);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();

    this.drawHealthBar(ctx);
  }
}
