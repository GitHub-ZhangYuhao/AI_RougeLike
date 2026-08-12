const ITEMS = [
  {
    id: 'warRune', name: '战意符石', icon: '◆', color: '#ffca28',
    desc: '永久提升 20% 武器伤害',
    apply(game) { game.rareBonuses.damageMult *= 1.2; },
  },
  {
    id: 'bloodJade', name: '血玉', icon: '♥', color: '#ef5350',
    desc: '最大生命 +25，并立即恢复 25',
    apply(game) {
      game.player.maxHp += 25;
      game.healPlayer(25);
    },
  },
  {
    id: 'magnetCore', name: '聚灵核心', icon: '◎', color: '#40c4ff',
    desc: '经验吸附范围永久增加 80',
    apply(game) { game.rareBonuses.magnetRadiusBonus += 80; },
  },
  {
    id: 'spiritBook', name: '悟道残卷', icon: '✦', color: '#b388ff',
    desc: '永久提升 25% 经验获取',
    apply(game) { game.rareBonuses.xpMult *= 1.25; },
  },
  {
    id: 'windFeather', name: '疾风羽', icon: '➤', color: '#69f0ae',
    desc: '永久提升 10% 移动速度',
    apply(game) { game.rareBonuses.moveSpeedMult *= 1.1; },
  },
];

export const RARE_ITEM_BY_ID = new Map(ITEMS.map((item) => [item.id, item]));

export function rollRareItem() {
  return ITEMS[Math.floor(Math.random() * ITEMS.length)];
}

export function createRarePickup(x, y, item = rollRareItem()) {
  return {
    x, y,
    kind: 'rare',
    itemId: item.id,
    pulse: Math.random() * Math.PI * 2,
    dead: false,
  };
}

export function applyRareItem(game, pickup) {
  const item = RARE_ITEM_BY_ID.get(pickup.itemId);
  if (!item) return null;
  item.apply(game);
  game.rareInventory[item.id] = (game.rareInventory[item.id] ?? 0) + 1;
  game.recomputeMods();
  return item;
}

export function drawRarePickup(ctx, pickup) {
  const item = RARE_ITEM_BY_ID.get(pickup.itemId);
  if (!item) return;
  pickup.pulse += 0.06;
  const radius = 11 + Math.sin(pickup.pulse) * 2;

  ctx.save();
  ctx.translate(pickup.x, pickup.y);
  ctx.shadowColor = item.color;
  ctx.shadowBlur = 16;
  ctx.beginPath();
  ctx.arc(0, 0, radius, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(20, 18, 35, 0.92)';
  ctx.fill();
  ctx.strokeStyle = item.color;
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = 'bold 16px "Segoe UI Symbol", sans-serif';
  ctx.fillStyle = item.color;
  ctx.fillText(item.icon, 0, 1);
  ctx.restore();
}
