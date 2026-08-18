import { CONFIG } from '../config.js';

// WaveDirector owns the 90-second wave clock and planned spawn composition.
// Spawner owns pacing, population caps and spawn positions.
export class WaveDirector {
  constructor() {
    this.reset();
  }

  reset() {
    this.wave = 1;
    this.phase = 'wave'; // wave | overtime | rest
    this.waveTimer = CONFIG.waves.duration;
    this.spawned = 0;
    this.baseQuota = this._quotaFor(1);
    this.quota = this.baseQuota;
    this.restTimer = 0;
    this.bannerTimer = CONFIG.waves.bannerDuration;
    this.eliteSpawned = false;
    this.bossSpawned = false;
    this.spawnedByType = {};
  }

  get isBossWave() {
    return this.wave % CONFIG.waves.bossEvery === 0;
  }

  get remaining() {
    return Math.max(0, this.quota - this.spawned);
  }

  get timeRemaining() {
    return Math.max(0, this.waveTimer);
  }

  get spawnInterval() {
    const immediateSpawns = this.isBossWave ? 1 : 0;
    const pacedSpawns = Math.max(1, this.quota - immediateSpawns);
    return CONFIG.waves.duration / pacedSpawns;
  }

  applySpawnSettings(settings) {
    if (!settings || typeof settings !== 'object') return this.quota;
    const quotaMult = Number.isFinite(settings.quotaMult)
      ? Math.max(0, settings.quotaMult)
      : 1;
    const minimumQuota = this.isBossWave ? 1 : 0;
    const scaledQuota = Math.max(minimumQuota, Math.round(this.baseQuota * quotaMult));
    // A live quota reduction must never make already-spawned enemies count
    // backwards or leave the director in an invalid negative-remaining state.
    this.quota = Math.max(this.spawned, scaledQuota);
    return this.quota;
  }

  startWave(game, wave) {
    const requestedWave = Number.isFinite(wave) ? Math.max(1, Math.floor(wave)) : 1;
    this.wave = Math.min(CONFIG.waves.maxWave, requestedWave);
    this.phase = 'wave';
    this.waveTimer = CONFIG.waves.duration;
    this.spawned = 0;
    this.baseQuota = this._quotaFor(this.wave);
    this.quota = this.baseQuota;
    this.restTimer = 0;
    this.bannerTimer = CONFIG.waves.bannerDuration;
    this.eliteSpawned = false;
    this.bossSpawned = false;
    this.spawnedByType = {};
    this.applySpawnSettings(game?.debug?.settings.spawn);
    if (game?.spawner) game.spawner.timer = 0;
    return this.wave;
  }

  update(dt, game, camera, viewW, viewH) {
    const spawnSettings = game.debug?.settings.spawn;
    this.applySpawnSettings(spawnSettings);
    if (this.bannerTimer > 0) this.bannerTimer -= dt;

    if (this.phase === 'rest') {
      this.restTimer -= dt;
      if (this.restTimer <= 0) this._startNextWave(game);
      return;
    }

    if (this.phase === 'overtime') {
      if (!this._bossAlive(game)) game.onBossWaveCleared(this);
      return;
    }

    this.waveTimer = Math.max(0, this.waveTimer - dt);
    if (this.isBossWave) this._updateBossWave(dt, game, camera, viewW, viewH, spawnSettings);
    else this._updateNormalWave(dt, game, camera, viewW, viewH, spawnSettings);
  }

  _updateNormalWave(dt, game, camera, viewW, viewH, spawnSettings) {
    const shouldGuaranteeElite = this.wave % CONFIG.waves.eliteEvery === 0;
    if (
      shouldGuaranteeElite
      && !this.eliteSpawned
      && spawnSettings?.paused !== true
      && this.remaining > 0
    ) {
      const elite = game.spawner.spawnType(
        'shield', game.elapsed, game.enemies, camera, viewW, viewH,
        {
          wave: this.wave,
          spawnedByType: this.spawnedByType,
          debug: game.debug,
        },
      );
      if (elite) {
        // 盾兵基础 rank 为 normal，仅精英波生成路径赋 elite rank（驱动稀有物掉落与精英视觉）
        elite.rank = 'elite';
        this.eliteSpawned = true;
        this.spawned++;
        game.spawner.timer = this.spawnInterval;
      }
    }

    if (this.remaining > 0) {
      this.spawned += game.spawner.update(
        dt, game.elapsed, game.enemies, camera, viewW, viewH,
        {
          spawnLimit: this.remaining,
          spawnInterval: this.spawnInterval,
          wave: this.wave,
          quota: this.quota,
          spawnedByType: this.spawnedByType,
          bossWave: false,
          spawnSettings,
          debug: game.debug,
        },
      );
    }

    // Normal waves advance strictly by time. Living enemies carry into the next wave.
    if (this.waveTimer <= 0) this._startNextWave(game);
  }

  _updateBossWave(dt, game, camera, viewW, viewH, spawnSettings) {
    if (!this.bossSpawned && spawnSettings?.paused !== true && this.remaining > 0) {
      const boss = game.spawner.spawnType(
        'boss', game.elapsed, game.enemies, camera, viewW, viewH,
        {
          wave: this.wave,
          spawnedByType: this.spawnedByType,
          debug: game.debug,
        },
      );
      if (boss) {
        this.bossSpawned = true;
        this.spawned = 1;
        game.spawner.timer = this.spawnInterval;
      }
    }

    if (this.remaining > 0) {
      this.spawned += game.spawner.update(
        dt, game.elapsed, game.enemies, camera, viewW, viewH,
        {
          spawnLimit: this.remaining,
          spawnInterval: this.spawnInterval,
          wave: this.wave,
          quota: this.quota,
          spawnedByType: this.spawnedByType,
          bossWave: true,
          forceType: 'enhancedChaser',
          spawnSettings,
          debug: game.debug,
        },
      );
    }

    if (this.waveTimer > 0 || !this.bossSpawned) return;
    if (this._bossAlive(game)) {
      this.phase = 'overtime';
      this.bannerTimer = CONFIG.waves.bannerDuration;
      return;
    }
    game.onBossWaveCleared(this);
  }

  _bossAlive(game) {
    return game.enemies.some((enemy) => !enemy.dead && enemy.rank === 'boss');
  }

  // Continuing after a boss checkpoint enters a short rest before the next wave.
  beginRest() {
    this._beginRest();
  }

  _beginRest() {
    this.phase = 'rest';
    this.restTimer = CONFIG.waves.restDuration;
    this.bannerTimer = CONFIG.waves.bannerDuration;
  }

  _startNextWave(game) {
    if (this.wave >= CONFIG.waves.maxWave) {
      game.onFinalWaveCleared(this);
      return;
    }
    this.startWave(game, this.wave + 1);
  }

  _bossReinforcementsFor(wave) {
    if (wave === 5) return 4;
    if (wave === 10) return 6;
    return Math.min(12, 6 + Math.floor((wave - 10) / 5) * 2);
  }

  quantityMultiplierFor(wave) {
    const requestedWave = Number.isFinite(wave) ? Math.max(1, Math.floor(wave)) : 1;
    const normalizedWave = Math.min(CONFIG.waves.maxWave, requestedWave);
    if (normalizedWave % CONFIG.waves.bossEvery === 0) {
      return (1 + this._bossReinforcementsFor(normalizedWave)) / CONFIG.waves.baseQuota;
    }
    return Math.min(
      CONFIG.waves.quantityWaveCap,
      1 + (normalizedWave - 1) * CONFIG.waves.quantityPerWave,
    );
  }

  _quotaFor(wave) {
    return Math.round(CONFIG.waves.baseQuota * this.quantityMultiplierFor(wave));
  }
}
