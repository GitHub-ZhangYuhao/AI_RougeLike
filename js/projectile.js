// 子弹：直线飞行，寿命结束消失
export function createProjectile(x, y, angle, opts) {
  return {
    x, y, angle,
    speed: opts.speed,
    radius: opts.radius,
    damage: opts.damage,
    lifetime: opts.lifetime,
    color: opts.color,
    vx: Math.cos(angle) * opts.speed,
    vy: Math.sin(angle) * opts.speed,
    dead: false,
  };
}

export function updateProjectile(p, dt) {
  p.x += p.vx * dt;
  p.y += p.vy * dt;
  p.lifetime -= dt;
  if (p.lifetime <= 0) p.dead = true;
}

export function drawProjectile(ctx, p) {
  ctx.beginPath();
  ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
  ctx.fillStyle = p.color;
  ctx.fill();
}