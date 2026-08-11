import { CONFIG } from './config.js';
import { chooseEnemyType, createEnemyByType } from './enemies/index.js';
import { clamp, lerp, rand } from './utils.js';

// Spawn outside the view. Pace and normal-enemy stats continue to scale over time.
export class Spawner {
  constructor() { this.timer = 0; }

  update(dt, elapsed, enemies, camera, viewW, viewH) {
    const config = CONFIG.spawner;
    const interval = lerp(
      config.startInterval,
      config.minInterval,
      clamp(elapsed / config.intervalRamp, 0, 1),
    );
    const maxAlive = Math.round(lerp(
      config.startMaxAlive,
      config.maxAliveCap,
      clamp(elapsed / config.maxAliveRamp, 0, 1),
    ));

    this.timer -= dt;
    while (this.timer <= 0) {
      if (enemies.length >= maxAlive) {
        this.timer = 0;
        break;
      }
      this.timer += interval;
      const position = this._ringPosition(camera, viewW, viewH);
      const type = chooseEnemyType(elapsed, enemies);
      enemies.push(createEnemyByType(type, position.x, position.y, elapsed));
    }
  }

  _ringPosition(camera, viewW, viewH) {
    const margin = CONFIG.spawner.spawnMargin;
    const halfW = viewW / 2 + margin;
    const halfH = viewH / 2 + margin;
    const side = Math.floor(rand(0, 4));
    const t = rand(-1, 1);
    switch (side) {
      case 0: return { x: camera.x + t * halfW, y: camera.y - halfH };
      case 1: return { x: camera.x + t * halfW, y: camera.y + halfH };
      case 2: return { x: camera.x - halfW, y: camera.y + t * halfH };
      default: return { x: camera.x + halfW, y: camera.y + t * halfH };
    }
  }
}
