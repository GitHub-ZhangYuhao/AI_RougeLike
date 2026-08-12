import { CONFIG } from './config.js';
import { chooseEnemyType, createEnemyByType } from './enemies/index.js';
import { rand } from './utils.js';

// Spawn outside the view. WaveDirector controls the finite per-wave quota;
// Spawner controls wave-based pacing, population cap and spawn position.
export class Spawner {
  constructor() { this.timer = 0; }

  update(dt, elapsed, enemies, camera, viewW, viewH, options = {}) {
    const config = CONFIG.spawner;
    const spawnLimit = options.spawnLimit ?? Infinity;
    const wave = Number.isFinite(options.wave) ? Math.max(1, Math.floor(options.wave)) : 1;
    const spawnSettings = options.spawnSettings ?? options.debug?.settings.spawn ?? {};
    if (spawnLimit <= 0 || spawnSettings.paused === true) return 0;

    const baseInterval = Math.max(
      config.minInterval,
      config.startInterval - (wave - 1) * config.intervalPerWave,
    );
    const intervalMult = Number.isFinite(spawnSettings.intervalMult)
      ? Math.max(0.01, spawnSettings.intervalMult)
      : 1;
    const interval = baseInterval * intervalMult;
    const calculatedMaxAlive = Math.min(
      config.maxAliveCap,
      config.startMaxAlive + (wave - 1) * config.maxAlivePerWave,
    );
    const maxAlive = spawnSettings.aliveCap == null
      ? calculatedMaxAlive
      : Math.max(0, Math.floor(spawnSettings.aliveCap));
    this.timer -= dt;
    let spawned = 0;
    while (this.timer <= 0 && spawned < spawnLimit) {
      const alive = enemies.reduce((count, enemy) => count + (!enemy.dead ? 1 : 0), 0);
      if (alive >= maxAlive) {
        this.timer = 0;
        break;
      }

      this.timer += interval;
      const type = options.forceType ?? chooseEnemyType(elapsed, enemies, {
        wave,
        quota: options.quota,
        spawnedByType: options.spawnedByType,
        bossWave: options.bossWave,
      });
      const enemy = this.spawnType(type, elapsed, enemies, camera, viewW, viewH, {
        wave,
        spawnedByType: options.spawnedByType,
        debug: options.debug,
      });
      if (!enemy) break;
      spawned++;
    }
    return spawned;
  }

  spawnType(type, elapsed, enemies, camera, viewW, viewH, options = {}) {
    const position = this._ringPosition(camera, viewW, viewH);
    const wave = Number.isFinite(options.wave) ? Math.max(1, Math.floor(options.wave)) : 1;
    const enemy = createEnemyByType(type, position.x, position.y, elapsed, wave);
    options.debug?.applyEnemyMultipliers(enemy);
    enemies.push(enemy);

    if (options.spawnedByType) {
      options.spawnedByType[enemy.type] = (options.spawnedByType[enemy.type] ?? 0) + 1;
    }
    return enemy;
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
