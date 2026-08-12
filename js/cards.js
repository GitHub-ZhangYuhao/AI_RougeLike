import { CONFIG } from './config.js';
import {
  SWORD_CARD, CLOAK_CARD, TALISMAN_CARD,
  TRAIL_CARD, RING_CARD, STAFF_CARD,
} from './weapons/index.js';

// ================= 武器卡 =================
// 卡牌定义（含每级数值/机制开关 levels[]）住在各自的武器文件里，这里只做聚合
// 重复抽到同名武器卡 = 升级（最高 maxLevel）
export const WEAPON_CARDS = [
  SWORD_CARD, CLOAK_CARD, TALISMAN_CARD, TRAIL_CARD, RING_CARD, STAFF_CARD,
];

// ================= 属性卡 =================
// 可重复抽取叠加（上限 CONFIG.cards.attrMaxStack）；apply(mods, n) 把 n 层效果叠加到 mods
export const ATTR_CARDS = [
  {
    id: 'damage', kind: 'attr', name: '伤害提升', icon: '💪',
    desc: '每层 +15% 武器伤害',
    apply(mods, n) { mods.damageMult += 0.15 * n; },
  },
  {
    id: 'armor', kind: 'attr', name: '护甲提升', icon: '🛡️',
    desc: '每层 +15 护甲（递减减伤，最高 50%）',
    apply(mods, n) { mods.armor += 15 * n; },
  },
  {
    id: 'magnet', kind: 'attr', name: '拾取范围', icon: '🧲',
    desc: '每层 +50px 经验吸附范围',
    apply(mods, n) { mods.magnetRadiusBonus += 50 * n; },
  },
  {
    id: 'xp', kind: 'attr', name: '经验倍率', icon: '📖',
    desc: '每层 +15% 经验获取',
    apply(mods, n) { mods.xpMult += 0.15 * n; },
  },
  {
    id: 'maxHp', kind: 'attr', name: '血量提升', icon: '❤️',
    desc: '每层 +20 最大生命，并立即恢复 20',
    apply(mods, n) { mods.maxHpBonus += 20 * n; },
    onAcquire(game) {
      if (typeof game.increaseMaxHp === 'function') game.increaseMaxHp(20, 20);
      else {
        game.player.maxHp += 20;
        game.player.hp = Math.min(game.player.maxHp, game.player.hp + 20);
      }
    },
  },
  {
    id: 'moveSpeed', kind: 'attr', name: '移动速度', icon: '👟',
    desc: '每层 +6% 移动速度',
    apply(mods, n) { mods.moveSpeedMult += 0.06 * n; },
  },
];

export const CARD_BY_ID = new Map(
  [...WEAPON_CARDS, ...ATTR_CARDS].map((c) => [c.id, c]),
);

// 由属性卡叠加层数计算最终乘数（供武器每帧读取）
// attrStacks：局内属性卡层数；metaStacks：局外商城永久属性等级（每级等效 1 层，加法叠加）
export function computeMods(attrStacks, metaStacks = {}) {
  const mods = {
    damageMult: 1,
    xpMult: 1,
    moveSpeedMult: 1,
    armor: 0,
    damageReduction: 0,
    magnetRadiusBonus: 0,
    maxHpBonus: 0,
    // Neutral compatibility fields for old saves and external debug tools. Weapons no longer consume them.
    projectileBonus: 0,
    areaMult: 1,
    attackSpeedMult: 1,
    cooldownMult: 1,
  };
  for (const card of ATTR_CARDS) {
    const n = (attrStacks[card.id] || 0) + (metaStacks[card.id] || 0);
    if (n > 0) card.apply(mods, n);
  }
  mods.damageReduction = Math.min(0.5, mods.armor / (mods.armor + 100));
  return mods;
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// 开局：展示全部武器卡任选 1 张（不再随机 3 张）
export function openingOffers() {
  return WEAPON_CARDS.map((card) => ({ card, type: 'new' }));
}

// 升级选项池：已有武器升级 + 有空槽时的新武器卡 + 未叠满的属性卡；洗牌后取 N 张
export function generateOffers(game) {
  const pool = [];

  // 已持有武器的升级卡
  for (const w of game.weapons) {
    if (w.level < w.card.maxLevel) pool.push({ card: w.card, type: 'upgrade' });
  }

  // 只有还有空武器槽时，才可能出现新武器卡（槽位数走配置，不写死）
  if (game.weapons.length < CONFIG.cards.maxWeaponSlots) {
    for (const card of WEAPON_CARDS) {
      if (!game.weapons.some((w) => w.card.id === card.id)) {
        pool.push({ card, type: 'new' });
      }
    }
  }

  // 未叠满的属性卡
  for (const card of ATTR_CARDS) {
    const n = game.attrStacks[card.id] || 0;
    if (n < CONFIG.cards.attrMaxStack) pool.push({ card, type: 'attr' });
  }

  return shuffle(pool).slice(0, CONFIG.cards.choicesCount);
}