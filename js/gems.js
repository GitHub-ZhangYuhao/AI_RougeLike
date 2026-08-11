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
  const sp = 30 + Math.random() * 60; // 掉落时轻微散开
  return {
    x, y,
    vx: Math.cos(ang) * sp,
    vy: Math.sin(ang) * sp,
    value: tier.value,
    color: tier.color,
    dead: false,
  };
}

export function updateGem(g, player, dt) {
  if (g.dead) return;
  const dx = player.x - g.x, dy = player.y - g.y;
  const d2 = dx * dx + dy * dy;
  const magnet = CONFIG.gems.magnetRadius;
  if (d2 < magnet * magnet) {
    // 进入吸附范围：加速飞向玩家
    const d = Math.sqrt(d2) || 1;
    const pull = 950;
    g.vx += (dx / d) * pull * dt;
    g.vy += (dy / d) * pull * dt;
    const sp = Math.hypot(g.vx, g.vy);
    const maxSp = 430;
    if (sp > maxSp) {
      g.vx = (g.vx / sp) * maxSp;
      g.vy = (g.vy / sp) * maxSp;
    }
  } else {
    // 落地摩擦减速
    const f = Math.max(0, 1 - 4 * dt);
    g.vx *= f;
    g.vy *= f;
  }
  g.x += g.vx * dt;
  g.y += g.vy * dt;
}

export function drawGem(ctx, g) {
  const s = 4 + g.value * 2; // 价值越高越大
  ctx.save();
  ctx.translate(g.x, g.y);
  ctx.rotate(Math.PI / 4);
  ctx.fillStyle = g.color;
  ctx.fillRect(-s / 2, -s / 2, s, s);
  ctx.strokeStyle = 'rgba(255,255,255,0.55)';
  ctx.lineWidth = 1;
  ctx.strokeRect(-s / 2, -s / 2, s, s);
  ctx.restore();
}
