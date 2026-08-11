import { CONFIG } from './config.js';
import { createEnemy } from './enemy.js';
import { clamp, lerp, rand } from './utils.js';

// 刷怪器：随时间加快刷怪节奏，在屏幕外一圈生成敌人
export class Spawner {
  constructor() { this.timer = 0; }

  update(dt, elapsed, enemies, camera, viewW, viewH) {
    const s = CONFIG.spawner;
    const interval = lerp(s.startInterval, s.minInterval, clamp(elapsed / s.intervalRamp, 0, 1));
    const maxAlive = Math.round(lerp(s.startMaxAlive, s.maxAliveCap, clamp(elapsed / s.maxAliveRamp, 0, 1)));

    this.timer -= dt;
    while (this.timer <= 0) {
      if (enemies.length >= maxAlive) { this.timer = 0; break; }
      this.timer += interval;
      const pos = this._ringPosition(camera, viewW, viewH);
      enemies.push(createEnemy(pos.x, pos.y, elapsed));
    }
  }

  // 在视野矩形外一圈随机取点
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
