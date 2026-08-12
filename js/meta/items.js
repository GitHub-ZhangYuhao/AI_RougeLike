// 局外成长材料：Boss 掉落的三阶材料，用于出售兑换暗晶或局外成长。
export const META_ITEMS = {
  shard: { id: 'shard', name: '碎片', icon: '🔹', tier: 1, sellPrice: 5 },
  essence: { id: 'essence', name: '辉光精华', icon: '✨', tier: 2, sellPrice: 20 },
  soulCrystal: { id: 'soulCrystal', name: '灵魂结晶', icon: '💎', tier: 3, sellPrice: 80 },
};

// 按 tier 升序排列，供遍历与展示
export const META_ITEM_LIST = [META_ITEMS.shard, META_ITEMS.essence, META_ITEMS.soulCrystal];

// 材料阶 → 物品 的反查表
export const ITEM_BY_TIER = {
  1: META_ITEMS.shard,
  2: META_ITEMS.essence,
  3: META_ITEMS.soulCrystal,
};
