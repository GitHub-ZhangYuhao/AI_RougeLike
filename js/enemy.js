import { CONFIG } from './config.js';
import { rand } from './utils.js';
import { speedMultOf } from './systems/status.js';

// elapsed: 游戏已进行秒数，用于随时间提升敌人属性
export function createEnemy(x, y, elapsed) {
  const c = CONFIG.enemy;
  const minutes = elapsed / 60;
  const speedJitter = 1 + rand(-c.speedVariance, c.speedVariance);
  const hp = c.hp + c.hpPerMin * minutes;
  return {
    x, y,
    radius: c.radius,
    speed: c.speed * speedJitter * (1 + c.speedPerMin * minutes),
    maxHp: hp,
    hp,
    damage: c.damage + c.damagePerMin * minutes,
    hitCooldown: 0,  // 接触伤害冷却，避免每帧扣血
    hitFlash: 0,     // 被命中时的白闪
    ringCd: 0,       // 玉环等环绕物的受击冷却
    dead: false,
    // 状态系统字段（js/systems/status.js）
    dots: {},        // { burn|bleed|poison: {dps, timer} }
    slowTimer: 0,
    slowFactor: 0,
    frozenTimer: 0,
  };
}

export function updateEnemy(e, player, dt) {
  // 计时器推进在 game 的 tickStatus 里统一做，这里只管移动
  const mult = speedMultOf(e);
  if (mult > 0) {
    const dx = player.x - e.x, dy = player.y - e.y;
    const d = Math.hypot(dx, dy) || 1;
    e.x += (dx / d) * e.speed * mult * dt;
    e.y += (dy / d) * e.speed * mult * dt;
  }
  if (e.hitCooldown > 0) e.hitCooldown -= dt;
  if (e.hitFlash > 0) e.hitFlash -= dt;
  if (e.ringCd > 0) e.ringCd -= dt;
}

// 简单的互相推挤，防止敌人叠成一坨（位置修正法）
export function separateEnemies(enemies, dt) {
  const k = CONFIG.enemy.separation;
  for (let i = 0; i < enemies.length; i++) {
    const a = enemies[i];
    for (let j = i + 1; j < enemies.length; j++) {
      const b = enemies[j];
      const dx = b.x - a.x, dy = b.y - a.y;
      const minDist = a.radius + b.radius;
      const d2 = dx * dx + dy * dy;
      if (d2 > 0.0001 && d2 < minDist * minDist) {
        const d = Math.sqrt(d2);
        const push = ((minDist - d) / d) * 0.5 * Math.min(1, k * dt);
        const px = dx * push, py = dy * push;
        a.x -= px; a.y -= py;
        b.x += px; b.y += py;
      }
    }
  }
}

export function drawEnemy(ctx, e) {
  ctx.beginPath();
  ctx.arc(e.x, e.y, e.radius, 0, Math.PI * 2);
  // 冰冻时染蓝，其次受击白闪
  ctx.fillStyle = e.hitFlash > 0 ? '#ffffff'
    : (e.frozenTimer > 0 ? '#81d4fa' : CONFIG.enemy.color);
  ctx.fill();
  // 受伤后显示血条
  if (e.hp < e.maxHp) {
    const w = e.radius * 2;
    const ratio = Math.max(0, e.hp / e.maxHp);
    ctx.fillStyle = 'rgba(0,0,0,0.55)';
    ctx.fillRect(e.x - w / 2, e.y - e.radius - 8, w, 3);
    ctx.fillStyle = '#ff8a80';
    ctx.fillRect(e.x - w / 2, e.y - e.radius - 8, w * ratio, 3);
  }
}