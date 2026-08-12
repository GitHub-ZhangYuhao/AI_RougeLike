import { CONFIG } from '../config.js';
import { ITEM_BY_TIER } from './items.js';

// Boss 材料掉落概率：基础值 + 每阶增量，受 cap 限制。bossTier<1 按 1 处理。
export function dropChanceFor(bossTier) {
  const tier = Math.max(1, bossTier);
  const { base, perTier, cap } = CONFIG.meta.dropChance;
  return Math.min(base + perTier * (tier - 1), cap);
}

// 保底最低材料阶：取 guaranteedMinTier 中 ≤bossTier 的最大键对应值，没有则 1。
export function minTierFor(bossTier) {
  const table = CONFIG.meta.guaranteedMinTier;
  let minTier = 1;
  let bestKey = -Infinity;
  for (const key of Object.keys(table)) {
    const k = Number(key);
    if (k <= bossTier && k > bestKey) {
      bestKey = k;
      minTier = table[key];
    }
  }
  return minTier;
}

// 加权掷骰：rng 为 0~1 均匀随机，返回落点所在的档位（1 起）。
function rollWeightedTier(weights, rng) {
  const total = weights.reduce((sum, w) => sum + w, 0);
  let roll = rng() * total;
  for (let i = 0; i < weights.length; i++) {
    roll -= weights[i];
    if (roll < 0) return i + 1;
  }
  return weights.length;
}

// Boss 材料掉落：先掷掉落概率，再掷数量，最后逐件掷材料阶（保底抬升下限）。
// 纯函数，rng 可注入以便确定性测试。
export function rollBossDrops(bossTier, rng = Math.random) {
  if (rng() >= dropChanceFor(bossTier)) return [];
  const tierKey = Math.min(Math.max(1, bossTier), 5);
  const [min, max] = CONFIG.meta.dropCount[tierKey];
  const count = min + Math.floor(rng() * (max - min + 1));
  const weights = CONFIG.meta.tierWeights[tierKey];
  const minTier = minTierFor(bossTier);
  const drops = [];
  for (let i = 0; i < count; i++) {
    const tier = Math.max(rollWeightedTier(weights, rng), minTier);
    drops.push(ITEM_BY_TIER[tier].id);
  }
  return drops;
}
