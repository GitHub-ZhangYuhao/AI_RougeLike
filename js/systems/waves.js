import { CONFIG } from '../config.js';

// WaveDirector owns quotas and per-wave composition counters. Spawner owns pacing.
export class WaveDirector {
  constructor() {
    this.reset();
  }

  reset() {
    this.wave = 1;
    this.phase = 'wave'; // wave | rest
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
    this.wave = Number.isFinite(wave) ? Math.max(1, Math.floor(wave)) : 1;
    this.phase = 'wave';
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

    if (this.isBossWave) {
      this._updateBossWave(dt, game, camera, viewW, viewH);
      return;
    }

    const shouldGuaranteeElite = this.wave % CONFIG.waves.eliteEvery === 0;
    if (
      shouldGuaranteeElite
      && !this.eliteSpawned
      && spawnSettings?.paused !== true
      && this.spawned < this.quota
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
        this.eliteSpawned = true;
        this.spawned++;
      }
    }

    if (this.remaining > 0) {
      this.spawned += game.spawner.update(
        dt, game.elapsed, game.enemies, camera, viewW, viewH,
        {
          spawnLimit: this.remaining,
          wave: this.wave,
          quota: this.quota,
          spawnedByType: this.spawnedByType,
          bossWave: false,
          spawnSettings,
          debug: game.debug,
        },
      );
    }

    if (this.spawned >= this.quota && !game.enemies.some((enemy) => !enemy.dead)) {
      this._beginRest();
    }
  }

  _updateBossWave(dt, game, camera, viewW, viewH) {
    if (
      !this.bossSpawned
      && game.debug?.settings.spawn.paused !== true
      && this.remaining > 0
    ) {
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
      }
      return;
    }

    if (this.remaining > 0) {
      this.spawned += game.spawner.update(
        dt, game.elapsed, game.enemies, camera, viewW, viewH,
        {
          spawnLimit: this.remaining,
          wave: this.wave,
          quota: this.quota,
          spawnedByType: this.spawnedByType,
          bossWave: true,
          forceType: 'enhancedChaser',
          spawnSettings: game.debug?.settings.spawn,
          debug: game.debug,
        },
      );
    }

    // Boss waves finish only after the boss and every reinforcement are dead.
    if (this.spawned >= this.quota && !game.enemies.some((enemy) => !enemy.dead)) {
      game.onBossWaveCleared(this);
    }
  }

  // Boss 撤离抉择选「继续深入」后，由 game 调用进入休整
  beginRest() {
    this._beginRest();
  }

  _beginRest() {
    this.phase = 'rest';
    this.restTimer = CONFIG.waves.restDuration;
    this.bannerTimer = CONFIG.waves.bannerDuration;
  }

  _startNextWave(game) {
    this.startWave(game, this.wave + 1);
  }

  _bossReinforcementsFor(wave) {
    if (wave < 15) return 0;
    // Explicit targets: wave 15 => 6, wave 20+ => capped at 8.
    return Math.min(8, 4 + Math.floor((wave - 10) / 5) * 2);
  }

  _quotaFor(wave) {
    if (wave % CONFIG.waves.bossEvery === 0) {
      return 1 + this._bossReinforcementsFor(wave);
    }
    return Math.min(
      CONFIG.waves.quotaCap,
      CONFIG.waves.baseQuota + (wave - 1) * CONFIG.waves.quotaPerWave,
    );
  }
}
