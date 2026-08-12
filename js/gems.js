import { CONFIG } from './config.js';

// 按游戏时长返回当前宝石档位（价值与颜色）
export function gemTierAt(elapsed) {
  for (const tier of CONFIG.gems.tiers) {
    if (elapsed < tier.until) return tier;
  }
  return CONFIG.gems.tiers[CONFIG.gems.tiers.length - 1];
}

export function createGem(x, y, elapsed) {
  const tier = gemTierAt(elapsed);
  const ang = Math.random() * Math.PI * 2;
  const sp = 20 + Math.random() * 35;
  return {
    x, y,
    vx: Math.cos(ang) * sp,
    vy: Math.sin(ang) * sp,
    value: tier.value,
    color: tier.color,
    magnetized: false,
    magnetSpeed: 0,
    dead: false,
  };
}

export function updateGem(g, player, dt, magnetRadius = CONFIG.gems.magnetRadius) {
  if (g.dead) return;
  const dx = player.x - g.x;
  const dy = player.y - g.y;
  const d2 = dx * dx + dy * dy;

  // 一旦进入范围就锁定吸附，之后即便玩家移动或宝石越过边界也不会脱锁。
  if (!g.magnetized && d2 <= magnetRadius * magnetRadius) {
    g.magnetized = true;
    g.magnetSpeed = Math.max(CONFIG.gems.magnetStartSpeed, Math.hypot(g.vx, g.vy));
  }

  if (g.magnetized) {
    const d = Math.sqrt(d2) || 1;
    g.magnetSpeed = Math.min(
      CONFIG.gems.magnetMaxSpeed,
      g.magnetSpeed + CONFIG.gems.magnetAcceleration * dt,
    );
    // 直接重定向速度，消除原散射速度导致的绕圈、越过和甩飞。
    g.vx = dx / d * g.magnetSpeed;
    g.vy = dy / d * g.magnetSpeed;
  } else {
    const friction = Math.max(0, 1 - 5 * dt);
    g.vx *= friction;
    g.vy *= friction;
  }

  g.x += g.vx * dt;
  g.y += g.vy * dt;
}

export function drawGem(ctx, g) {
  const s = 4 + g.value * 2;
  ctx.save();
  ctx.translate(g.x, g.y);
  ctx.rotate(Math.PI / 4);
  ctx.fillStyle = g.color;
  ctx.fillRect(-s / 2, -s / 2, s, s);
  ctx.strokeStyle = g.magnetized ? '#ffffff' : 'rgba(255,255,255,0.55)';
  ctx.lineWidth = g.magnetized ? 1.8 : 1;
  ctx.strokeRect(-s / 2, -s / 2, s, s);
  ctx.restore();
}
