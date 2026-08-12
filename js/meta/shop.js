import { CONFIG } from '../config.js';

// 局外商店可购买的属性 id，与 save.metaLevels 的键一一对应
export const SHOP_ATTRS = ['damage', 'armor', 'magnet', 'xp', 'maxHp', 'moveSpeed'];

export const SHOP_MAX_LEVEL = CONFIG.meta.shopMaxLevel;

// 升到目标等级 k 的价格：base 起按 growth 等比增长并四舍五入；k<1 返回 0。
export function priceForLevel(k) {
  if (k < 1) return 0;
  const { base, growth } = CONFIG.meta.shopPrice;
  return Math.round(base * Math.pow(growth, k - 1));
}

export function canBuy(save, attrId) {
  const current = save.metaLevels[attrId];
  return current < SHOP_MAX_LEVEL && save.darkCrystals >= priceForLevel(current + 1);
}

// 购买成功时原地修改 save 并返回 true；失败时不做任何修改。
export function tryBuy(save, attrId) {
  if (!canBuy(save, attrId)) return false;
  save.darkCrystals -= priceForLevel(save.metaLevels[attrId] + 1);
  save.metaLevels[attrId] += 1;
  return true;
}
