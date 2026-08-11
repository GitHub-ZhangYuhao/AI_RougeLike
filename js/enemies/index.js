import { CONFIG } from '../config.js';
import { rand } from '../utils.js';
import { ChaserEnemy } from '../enemy.js';
import { ChargerEnemy } from './charger.js';
import { RangedEnemy } from './ranged.js';
import { BomberEnemy } from './bomber.js';
import { ShieldEnemy } from './shield.js';

const ENEMY_CLASSES = {
  chaser: ChaserEnemy,
  charger: ChargerEnemy,
  ranged: RangedEnemy,
  bomber: BomberEnemy,
  shield: ShieldEnemy,
};

export function createEnemyByType(type, x, y, elapsed) {
  const EnemyClass = ENEMY_CLASSES[type] ?? ChaserEnemy;
  return new EnemyClass(x, y, elapsed);
}

export function chooseEnemyType(elapsed, enemies) {
  const aliveByType = {};
  for (const enemy of enemies) {
    if (enemy.dead) continue;
    aliveByType[enemy.type] = (aliveByType[enemy.type] ?? 0) + 1;
  }

  const choices = [];
  let totalWeight = 0;
  for (const [type, config] of Object.entries(CONFIG.enemyTypes)) {
    if (elapsed < config.unlockAt) continue;
    if ((aliveByType[type] ?? 0) >= config.maxAlive) continue;
    if (config.weight <= 0) continue;
    totalWeight += config.weight;
    choices.push({ type, limit: totalWeight });
  }

  if (choices.length === 0) return 'chaser';
  const roll = rand(0, totalWeight);
  return choices.find((choice) => roll < choice.limit)?.type ?? choices[choices.length - 1].type;
}
