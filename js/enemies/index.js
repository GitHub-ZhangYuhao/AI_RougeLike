import { CONFIG } from '../config.js';
import { rand } from '../utils.js';
import { ChaserEnemy } from '../enemy.js';
import { applyWaveScaling } from './base.js';
import { EnhancedChaserEnemy } from './enhanced-chaser.js';
import { ChargerEnemy } from './charger.js';
import { RangedEnemy } from './ranged.js';
import { BomberEnemy } from './bomber.js';
import { ShieldEnemy } from './shield.js';
import { BossEnemy } from './boss.js';

const ENEMY_CLASSES = {
  chaser: ChaserEnemy,
  enhancedChaser: EnhancedChaserEnemy,
  charger: ChargerEnemy,
  ranged: RangedEnemy,
  bomber: BomberEnemy,
  shield: ShieldEnemy,
  boss: BossEnemy,
};

function normalizedWaveOf(wave) {
  return Number.isFinite(wave) ? Math.max(1, Math.floor(wave)) : 1;
}

function enhancedChaserRatio(wave) {
  if (wave < 8) return 0;
  if (wave === 8) return 0.25;
  if (wave === 9) return 0.5;
  if (wave === 10) return 0.75;
  return 1;
}

export function createEnemyByType(type, x, y, elapsed = 0, wave = 1) {
  const normalizedWave = normalizedWaveOf(wave);
  const fallback = normalizedWave >= 11 ? EnhancedChaserEnemy : ChaserEnemy;
  const EnemyClass = ENEMY_CLASSES[type] ?? fallback;
  return applyWaveScaling(new EnemyClass(x, y, elapsed), normalizedWave);
}

export function chooseEnemyType(elapsed = 0, enemies = [], options = {}) {
  const wave = normalizedWaveOf(options.wave ?? 1);
  const spawnedByType = options.spawnedByType ?? {};
  const quota = options.quota;
  const bossWave = options.bossWave === true;
  const aliveByType = {};

  for (const enemy of enemies) {
    if (enemy.dead) continue;
    aliveByType[enemy.type] = (aliveByType[enemy.type] ?? 0) + 1;
  }

  const rangedWaveCap = Number.isFinite(quota)
    ? Math.max(1, Math.floor(quota * 0.12))
    : Infinity;
  const replacementRatio = enhancedChaserRatio(wave);
  const choices = [];
  let totalWeight = 0;

  const addChoice = (type, config, weight) => {
    if (weight <= 0) return;
    if (elapsed < config.unlockAt) return;
    if ((aliveByType[type] ?? 0) >= config.maxAlive) return;
    if (type === 'ranged') {
      if (bossWave) return;
      if ((spawnedByType.ranged ?? 0) >= rangedWaveCap) return;
    }
    totalWeight += weight;
    choices.push({ type, limit: totalWeight });
  };

  for (const [type, config] of Object.entries(CONFIG.enemyTypes)) {
    if (type === 'boss' || type === 'enhancedChaser') continue;
    if (type === 'chaser') {
      addChoice('chaser', config, config.weight * (1 - replacementRatio));
      addChoice(
        'enhancedChaser',
        CONFIG.enemyTypes.enhancedChaser,
        config.weight * replacementRatio,
      );
      continue;
    }
    addChoice(type, config, config.weight);
  }

  // Late waves must never reintroduce the basic chaser through fallback.
  if (choices.length === 0) return wave >= 11 ? 'enhancedChaser' : 'chaser';
  const roll = rand(0, totalWeight);
  return choices.find((choice) => roll < choice.limit)?.type ?? choices[choices.length - 1].type;
}
