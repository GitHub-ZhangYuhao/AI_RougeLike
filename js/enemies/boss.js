import { CONFIG } from '../config.js';
import { EnemyBase } from './base.js';

const TAU = Math.PI * 2;

// Boss 使用独立波次生成。攻击前会明显蓄力，随后发射环形弹幕；半血后进入狂暴。
export class BossEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0, options = {}) {
    const config = CONFIG.enemyTypes.boss;
    super(x, y, elapsed, {
      ...options,
      type: 'boss',
      rank: 'boss',
      radius: config.radius,
      hpMult: config.hpMult,
      speedMult: config.speedMult,
      damageMult: config.damageMult,
      speedVariance: false,
      color: '#7e57c2',
    });

    this.name = '暗夜领主';
    this.state = 'chase';
    this.attackCooldown = 1.6;
    this.windupTimer = 0;
    this.rotation = 0;
  }

  get enraged() {
    return this.hp / this.maxHp <= CONFIG.enemyTypes.boss.enragedHpRatio;
  }

  update(player, dt, world) {
    if (this.dead) return;
    this.tickCommon(dt);
    this.rotation += dt * (this.enraged ? 2.2 : 1.25);

    if (this.state === 'windup') {
      this.windupTimer += dt;
      if (this.windupTimer >= CONFIG.enemyTypes.boss.windup) {
        this._fireRadialBurst(world);
        this.state = 'chase';
        this.attackCooldown = CONFIG.enemyTypes.boss.attackInterval * (this.enraged ? 0.72 : 1);
      }
      return;
    }

    this.attackCooldown -= dt;
    this.moveToward(player, dt, this.speed * (this.enraged ? 1.2 : 1));
    if (this.attackCooldown <= 0) {
      this.state = 'windup';
      this.windupTimer = 0;
    }
  }

  _fireRadialBurst(world) {
    const config = CONFIG.enemyTypes.boss;
    const count = this.enraged ? config.enragedProjectileCount : config.projectileCount;
    const speed = this.enraged ? config.enragedProjectileSpeed : config.projectileSpeed;
    const offset = this.rotation;

    for (let i = 0; i < count; i++) {
      world.spawnHostileProjectile?.({
        x: this.x,
        y: this.y,
        angle: offset + i * TAU / count,
        speed,
        radius: config.projectileRadius,
        damage: this.damage * 0.72,
        lifetime: config.projectileLifetime,
        color: this.enraged ? '#ff5252' : '#b388ff',
      });
    }
    world.spawnEnemyBlast?.({
      x: this.x,
      y: this.y,
      radius: this.radius * 2.4,
      color: this.enraged ? '#ff1744' : '#7c4dff',
      ttl: 0.45,
    });
  }

  draw(ctx) {
    const windup = this.state === 'windup';
    const progress = windup
      ? Math.min(1, this.windupTimer / CONFIG.enemyTypes.boss.windup)
      : 0;

    ctx.save();
    ctx.beginPath();
    ctx.arc(this.x, this.y, this.radius + 11 + Math.sin(this.rotation * 3) * 2, 0, TAU);
    ctx.strokeStyle = this.enraged ? '#ff5252' : '#b388ff';
    ctx.globalAlpha = 0.65 + progress * 0.35;
    ctx.lineWidth = 4 + progress * 3;
    ctx.stroke();
    ctx.restore();

    this.drawBody(ctx, this.enraged ? '#c62828' : '#7e57c2');

    // 王冠轮廓，使 Boss 与普通圆形敌人有明显区别。
    ctx.save();
    ctx.translate(this.x, this.y - this.radius + 5);
    ctx.fillStyle = windup ? '#fff59d' : '#ffd54f';
    ctx.beginPath();
    ctx.moveTo(-15, 2);
    ctx.lineTo(-11, -11);
    ctx.lineTo(-3, -3);
    ctx.lineTo(0, -15);
    ctx.lineTo(5, -3);
    ctx.lineTo(14, -11);
    ctx.lineTo(16, 2);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    if (windup) {
      ctx.save();
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.radius + 20 + progress * 18, 0, TAU);
      ctx.strokeStyle = '#ffeb3b';
      ctx.globalAlpha = 0.35 + progress * 0.6;
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.restore();
    }

    this.drawHealthBar(ctx);
  }
}
