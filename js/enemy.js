import { CONFIG } from './config.js';
import { EnemyBase } from './enemies/base.js';

export class ChaserEnemy extends EnemyBase {
  constructor(x, y, elapsed = 0) {
    super(x, y, elapsed, {
      type: 'chaser',
      rank: 'normal',
      color: CONFIG.enemy.color,
    });
  }
}

// Compatibility factory used by older callers and tests.
export function createEnemy(x, y, elapsed) {
  return new ChaserEnemy(x, y, elapsed);
}

export function updateEnemy(enemy, player, dt, world) {
  enemy.update(player, dt, world);
}

// Simple position correction so enemies do not fully overlap.
export function separateEnemies(enemies, dt) {
  const strength = CONFIG.enemy.separation;
  for (let i = 0; i < enemies.length; i++) {
    const a = enemies[i];
    for (let j = i + 1; j < enemies.length; j++) {
      const b = enemies[j];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const minDistance = a.radius + b.radius;
      const distance2 = dx * dx + dy * dy;
      if (distance2 > 0.0001 && distance2 < minDistance * minDistance) {
        const distance = Math.sqrt(distance2);
        const push = ((minDistance - distance) / distance) * 0.5 * Math.min(1, strength * dt);
        const px = dx * push;
        const py = dy * push;
        a.x -= px;
        a.y -= py;
        b.x += px;
        b.y += py;
      }
    }
  }
}

export function drawEnemy(ctx, enemy) {
  enemy.draw(ctx);
}
