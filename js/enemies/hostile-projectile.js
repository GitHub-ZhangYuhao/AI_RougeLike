export function createHostileProjectile(options) {
  const angle = options.angle ?? 0;
  const speed = options.speed ?? 150;
  return {
    x: options.x,
    y: options.y,
    angle,
    speed,
    radius: options.radius ?? 5,
    damage: options.damage ?? 6,
    lifetime: options.lifetime ?? 4,
    color: options.color ?? '#ffb74d',
    vx: Math.cos(angle) * speed,
    vy: Math.sin(angle) * speed,
    dead: false,
  };
}

export function updateHostileProjectile(projectile, dt) {
  projectile.x += projectile.vx * dt;
  projectile.y += projectile.vy * dt;
  projectile.lifetime -= dt;
  if (projectile.lifetime <= 0) projectile.dead = true;
}

export function drawHostileProjectile(ctx, projectile) {
  ctx.beginPath();
  ctx.arc(projectile.x, projectile.y, projectile.radius, 0, Math.PI * 2);
  ctx.fillStyle = projectile.color;
  ctx.fill();

  ctx.beginPath();
  ctx.arc(projectile.x, projectile.y, projectile.radius + 2, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth = 1;
  ctx.stroke();
}
