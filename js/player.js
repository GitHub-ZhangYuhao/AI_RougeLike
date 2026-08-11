import { CONFIG } from './config.js';

export function createPlayer(x = 0, y = 0) {
  return {
    x, y,
    radius: CONFIG.player.radius,
    speed: CONFIG.player.speed,
    hp: CONFIG.player.maxHp,
    maxHp: CONFIG.player.maxHp,
    iFrames: 0,     // 无敌帧剩余时间
    lastHurtAt: -1, // 最近一次真正受击的时刻（elapsed 秒），供受击触发类质变监听
    facing: 0,      // 朝向角（用于绘制指示器）
    moving: false,
  };
}

export function updatePlayer(p, input, dt) {
  const axis = input.axis();
  p.moving = axis.x !== 0 || axis.y !== 0;
  if (p.moving) {
    p.x += axis.x * p.speed * dt;
    p.y += axis.y * p.speed * dt;
    p.facing = Math.atan2(axis.y, axis.x);
  }
  if (p.iFrames > 0) p.iFrames -= dt;
}

// 返回 true 表示真的受到了伤害（没被无敌帧挡掉）
export function hurtPlayer(p, damage) {
  if (p.iFrames > 0) return false;
  p.hp -= damage;
  p.iFrames = CONFIG.player.hurtIFrames;
  return true;
}

export function drawPlayer(ctx, p) {
  const blinking = p.iFrames > 0 && Math.floor(p.iFrames * 20) % 2 === 0;
  ctx.save();
  ctx.translate(p.x, p.y);
  ctx.globalAlpha = blinking ? 0.35 : 1;
  // 本体
  ctx.beginPath();
  ctx.arc(0, 0, p.radius, 0, Math.PI * 2);
  ctx.fillStyle = CONFIG.player.color;
  ctx.fill();
  // 朝向小三角
  ctx.rotate(p.facing);
  ctx.beginPath();
  ctx.moveTo(p.radius + 6, 0);
  ctx.lineTo(p.radius - 4, -5);
  ctx.lineTo(p.radius - 4, 5);
  ctx.closePath();
  ctx.fillStyle = '#e3f6ff';
  ctx.fill();
  ctx.restore();
}