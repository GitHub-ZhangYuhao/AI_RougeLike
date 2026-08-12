import { CONFIG } from '../config.js';
import { META_ITEM_LIST } from '../meta/items.js';
import { SHOP_ATTRS, SHOP_MAX_LEVEL, priceForLevel } from '../meta/shop.js';
import { CARD_BY_ID } from '../cards.js';
import { formatTime } from '../utils.js';

// 局外界面：主菜单 / 商城 / 仓库 / 撤离抉择 / 撤离结算
// update* 读输入并调用 game 方法改状态（按钮命中检测在这里）；draw* 纯渲染

const UI_FONT = '"Segoe UI", "Microsoft YaHei", sans-serif';
const EMOJI_FONT = '"Segoe UI Emoji", "Segoe UI Symbol", sans-serif';

// ---------- 本地小助手（不导出） ----------

function rectHit(r, x, y) {
  return !!r && x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
}

// update* 拿画布尺寸：main.js 把 canvas 撑满窗口，直接读 window（headless 同样有 window 桩）
function viewSize() {
  if (typeof window !== 'undefined' && window.innerWidth > 0) {
    return { w: window.innerWidth, h: window.innerHeight };
  }
  return { w: 1280, h: 720 };
}

function darkCrystalsOf(game) {
  return game.save?.darkCrystals ?? 0;
}

function metaLevelOf(game, attrId) {
  return game.save?.metaLevels?.[attrId] ?? 0;
}

function storageCountOf(game, itemId) {
  return game.save?.storage?.[itemId] ?? 0;
}

// 按 META_ITEM_LIST 顺序收集数量 > 0 的材料（临时背包 / 入库材料共用）
function materialEntries(source) {
  const src = source ?? {};
  return META_ITEM_LIST
    .map((item) => ({ item, count: src[item.id] ?? 0 }))
    .filter((entry) => entry.count > 0);
}

function drawOverlay(ctx, viewW, viewH, alpha) {
  ctx.fillStyle = `rgba(0,0,0,${alpha})`;
  ctx.fillRect(0, 0, viewW, viewH);
}

function drawPanel(ctx, r) {
  ctx.fillStyle = 'rgba(16,16,28,0.94)';
  ctx.fillRect(r.x, r.y, r.w, r.h);
  ctx.strokeStyle = 'rgba(255,255,255,0.20)';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1);
}

// 按钮：fillRect 底 + strokeRect 边 + 居中文本；hover 提亮、disabled 置灰
function drawButton(ctx, r, label, opts = {}) {
  const { hover = false, disabled = false, accent = '#ffd54f', fontSize = 17 } = opts;
  if (disabled) {
    ctx.fillStyle = 'rgba(255,255,255,0.05)';
    ctx.fillRect(r.x, r.y, r.w, r.h);
    ctx.strokeStyle = 'rgba(255,255,255,0.14)';
    ctx.lineWidth = 1;
    ctx.strokeRect(r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1);
    ctx.fillStyle = 'rgba(255,255,255,0.30)';
  } else {
    ctx.fillStyle = hover ? '#2e2e48' : '#1c1c2b';
    ctx.fillRect(r.x, r.y, r.w, r.h);
    ctx.strokeStyle = hover ? accent : 'rgba(255,255,255,0.32)';
    ctx.lineWidth = hover ? 2 : 1;
    ctx.strokeRect(r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1);
    ctx.fillStyle = hover ? accent : '#ffffff';
  }
  ctx.textAlign = 'center';
  ctx.font = `bold ${fontSize}px ${UI_FONT}`;
  ctx.fillText(label, r.x + r.w / 2, r.y + r.h / 2 + Math.round(fontSize * 0.35));
}

// ---------- 主菜单 ----------

const MENU_LABELS = ['开始游戏', '商城', '仓库'];

function menuLayout(viewW, viewH) {
  const bw = 240, bh = 52, gap = 18;
  const x = (viewW - bw) / 2;
  const startY = viewH / 2 - (bh * 3 + gap * 2) / 2 + 30;
  return MENU_LABELS.map((label, i) => ({
    label,
    rect: { x, y: startY + i * (bh + gap), w: bw, h: bh },
  }));
}

export function updateMenu(game) {
  const input = game.input;
  if (input.wasPressed('Enter') || input.wasPressed('Space')) {
    game.startRun();
    return;
  }
  if (!input.mouseClicked()) return;
  const { w, h } = viewSize();
  const { x, y } = input.mouse;
  const buttons = menuLayout(w, h);
  if (rectHit(buttons[0].rect, x, y)) { game.startRun(); return; }
  if (rectHit(buttons[1].rect, x, y)) { game.openShop(); return; }
  if (rectHit(buttons[2].rect, x, y)) game.openStorage();
}

export function drawMenu(ctx, viewW, viewH, game) {
  ctx.save();
  drawOverlay(ctx, viewW, viewH, 0.66);

  const stats = game.save?.stats ?? {};
  const mx = game.input.mouse.x;
  const my = game.input.mouse.y;

  ctx.textAlign = 'center';
  ctx.font = `bold 54px ${UI_FONT}`;
  ctx.fillStyle = '#ffffff';
  ctx.fillText('暗夜幸存者', viewW / 2, viewH * 0.24);

  // 暗晶用 🌑，与灵魂结晶 💎 区分
  ctx.font = `bold 22px ${UI_FONT}`;
  ctx.fillStyle = '#b39ddb';
  ctx.fillText(`🌑 暗晶：${darkCrystalsOf(game)}`, viewW / 2, viewH * 0.335);

  for (const { label, rect } of menuLayout(viewW, viewH)) {
    drawButton(ctx, rect, label, { hover: rectHit(rect, mx, my), fontSize: 19 });
  }

  ctx.font = `14px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.fillText(
    `累计 ${stats.runs ?? 0} 局 · 成功撤离 ${stats.extractions ?? 0} 次 · 最佳波数 ${stats.bestWave ?? 0}`,
    viewW / 2, viewH * 0.84,
  );
  ctx.fillStyle = 'rgba(255,255,255,0.35)';
  ctx.fillText('按 Enter / Space 快速开始', viewW / 2, viewH * 0.89);

  ctx.restore();
}

// ---------- 商城 ----------

function shopLayout(viewW, viewH) {
  const pw = Math.min(760, viewW - 60);
  const ph = Math.min(560, viewH - 60);
  const panel = { x: (viewW - pw) / 2, y: (viewH - ph) / 2, w: pw, h: ph };
  const rowH = 54, rowGap = 6, buyW = 96, buyH = 36;
  const rowsTop = panel.y + 92;
  const rows = SHOP_ATTRS.map((attrId, i) => {
    const y = rowsTop + i * (rowH + rowGap);
    return {
      attrId,
      y,
      buy: { x: panel.x + pw - 26 - buyW, y: y + (rowH - buyH) / 2, w: buyW, h: buyH },
    };
  });
  const backW = 168, backH = 44;
  const back = { x: (viewW - backW) / 2, y: panel.y + ph - 72, w: backW, h: backH };
  return { panel, rows, back, rowH };
}

function canBuyAttr(game, attrId) {
  const level = metaLevelOf(game, attrId);
  if (level >= SHOP_MAX_LEVEL) return false;
  return darkCrystalsOf(game) >= priceForLevel(level + 1);
}

export function updateShop(game) {
  const input = game.input;
  if (input.wasPressed('Escape')) { game.backToMenu(); return; }
  if (!input.mouseClicked()) return;
  const { w, h } = viewSize();
  const layout = shopLayout(w, h);
  const { x, y } = input.mouse;
  if (rectHit(layout.back, x, y)) { game.backToMenu(); return; }
  for (const row of layout.rows) {
    if (!rectHit(row.buy, x, y)) continue;
    // 禁用按钮（满级 / 余额不足）点击无效
    if (canBuyAttr(game, row.attrId)) game.buyShopItem(row.attrId);
    return;
  }
}

export function drawShop(ctx, viewW, viewH, game) {
  ctx.save();
  drawOverlay(ctx, viewW, viewH, 0.7);

  const layout = shopLayout(viewW, viewH);
  const panel = layout.panel;
  drawPanel(ctx, panel);

  const crystals = darkCrystalsOf(game);
  const mx = game.input.mouse.x;
  const my = game.input.mouse.y;

  ctx.textAlign = 'center';
  ctx.font = `bold 28px ${UI_FONT}`;
  ctx.fillStyle = '#ffffff';
  ctx.fillText('商城 · 永久属性', panel.x + panel.w / 2, panel.y + 48);

  ctx.textAlign = 'right';
  ctx.font = `bold 18px ${UI_FONT}`;
  ctx.fillStyle = '#b39ddb';
  ctx.fillText(`🌑 暗晶：${crystals}`, panel.x + panel.w - 24, panel.y + 46);

  for (const row of layout.rows) {
    const card = CARD_BY_ID.get(row.attrId);
    const level = metaLevelOf(game, row.attrId);
    const maxed = level >= SHOP_MAX_LEVEL;
    const price = maxed ? 0 : priceForLevel(level + 1);
    const enabled = canBuyAttr(game, row.attrId);

    ctx.fillStyle = 'rgba(255,255,255,0.03)';
    ctx.fillRect(panel.x + 16, row.y, panel.w - 32, layout.rowH);

    ctx.textAlign = 'center';
    ctx.font = `22px ${EMOJI_FONT}`;
    ctx.fillStyle = '#ffffff';
    ctx.fillText(card?.icon ?? '?', panel.x + 44, row.y + 35);

    ctx.textAlign = 'left';
    ctx.font = `bold 16px ${UI_FONT}`;
    ctx.fillStyle = '#ffffff';
    ctx.fillText(card?.name ?? row.attrId, panel.x + 68, row.y + 24);
    if (card?.desc) {
      ctx.font = `12px ${UI_FONT}`;
      ctx.fillStyle = 'rgba(255,255,255,0.50)';
      ctx.fillText(card.desc, panel.x + 68, row.y + 43);
    }

    ctx.textAlign = 'right';
    ctx.font = `bold 15px ${UI_FONT}`;
    ctx.fillStyle = '#ffd54f';
    ctx.fillText(`Lv ${level}/${SHOP_MAX_LEVEL}`, row.buy.x - 148, row.y + 33);
    ctx.fillStyle = maxed ? 'rgba(255,255,255,0.40)' : (enabled ? '#b39ddb' : '#ef5350');
    ctx.fillText(maxed ? 'MAX' : `🌑 ${price}`, row.buy.x - 16, row.y + 33);

    drawButton(ctx, row.buy, '购买', { hover: enabled && rectHit(row.buy, mx, my), disabled: !enabled, fontSize: 15 });
  }

  drawButton(ctx, layout.back, '返回', { hover: rectHit(layout.back, mx, my), fontSize: 16 });
  ctx.textAlign = 'center';
  ctx.font = `13px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.40)';
  ctx.fillText('按 Esc 返回主菜单', panel.x + panel.w / 2, panel.y + panel.h - 12);

  ctx.restore();
}

// ---------- 仓库 ----------

function storageLayout(viewW, viewH) {
  const pw = Math.min(680, viewW - 60);
  const ph = Math.min(480, viewH - 80);
  const panel = { x: (viewW - pw) / 2, y: (viewH - ph) / 2, w: pw, h: ph };
  const rowH = 58, rowGap = 10, sellW = 96, sellH = 36;
  const rowsTop = panel.y + 96;
  const rows = META_ITEM_LIST.map((item, i) => {
    const y = rowsTop + i * (rowH + rowGap);
    return {
      item,
      y,
      sell: { x: panel.x + pw - 26 - sellW, y: y + (rowH - sellH) / 2, w: sellW, h: sellH },
    };
  });
  const allW = 200, allH = 46;
  const sellAll = {
    x: (viewW - allW) / 2,
    y: rowsTop + META_ITEM_LIST.length * (rowH + rowGap) + 6,
    w: allW,
    h: allH,
  };
  const backW = 168, backH = 44;
  const back = { x: (viewW - backW) / 2, y: panel.y + ph - 70, w: backW, h: backH };
  return { panel, rows, sellAll, back, rowH };
}

export function updateStorage(game) {
  const input = game.input;
  if (input.wasPressed('Escape')) { game.backToMenu(); return; }
  if (!input.mouseClicked()) return;
  const { w, h } = viewSize();
  const layout = storageLayout(w, h);
  const { x, y } = input.mouse;
  if (rectHit(layout.back, x, y)) { game.backToMenu(); return; }
  for (const row of layout.rows) {
    if (!rectHit(row.sell, x, y)) continue;
    if (storageCountOf(game, row.item.id) > 0) game.sellStorageItem(row.item.id);
    return;
  }
  if (rectHit(layout.sellAll, x, y)) {
    const total = META_ITEM_LIST.reduce((sum, item) => sum + storageCountOf(game, item.id), 0);
    if (total > 0) game.sellAllStorage();
  }
}

export function drawStorage(ctx, viewW, viewH, game) {
  ctx.save();
  drawOverlay(ctx, viewW, viewH, 0.7);

  const layout = storageLayout(viewW, viewH);
  const panel = layout.panel;
  drawPanel(ctx, panel);

  const mx = game.input.mouse.x;
  const my = game.input.mouse.y;

  ctx.textAlign = 'center';
  ctx.font = `bold 28px ${UI_FONT}`;
  ctx.fillStyle = '#ffffff';
  ctx.fillText('仓库', panel.x + panel.w / 2, panel.y + 48);

  ctx.textAlign = 'right';
  ctx.font = `bold 18px ${UI_FONT}`;
  ctx.fillStyle = '#b39ddb';
  ctx.fillText(`🌑 暗晶：${darkCrystalsOf(game)}`, panel.x + panel.w - 24, panel.y + 46);

  for (const row of layout.rows) {
    const count = storageCountOf(game, row.item.id);
    const enabled = count > 0;

    ctx.fillStyle = 'rgba(255,255,255,0.03)';
    ctx.fillRect(panel.x + 16, row.y, panel.w - 32, layout.rowH);

    ctx.textAlign = 'center';
    ctx.font = `24px ${EMOJI_FONT}`;
    ctx.fillStyle = '#ffffff';
    ctx.fillText(row.item.icon, panel.x + 46, row.y + 38);

    ctx.textAlign = 'left';
    ctx.font = `bold 16px ${UI_FONT}`;
    ctx.fillStyle = '#ffffff';
    ctx.fillText(row.item.name, panel.x + 72, row.y + 27);
    ctx.font = `12px ${UI_FONT}`;
    ctx.fillStyle = 'rgba(255,255,255,0.50)';
    ctx.fillText(`阶级 ${row.item.tier}`, panel.x + 72, row.y + 45);

    ctx.font = `bold 18px ${UI_FONT}`;
    ctx.fillStyle = enabled ? '#ffd54f' : 'rgba(255,255,255,0.35)';
    ctx.fillText(`×${count}`, panel.x + 220, row.y + 36);

    ctx.textAlign = 'right';
    ctx.font = `14px ${UI_FONT}`;
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    ctx.fillText(`单价 🌑${row.item.sellPrice}`, row.sell.x - 16, row.y + 35);

    drawButton(ctx, row.sell, '卖出', { hover: enabled && rectHit(row.sell, mx, my), disabled: !enabled, fontSize: 15 });
  }

  const total = META_ITEM_LIST.reduce((sum, item) => sum + storageCountOf(game, item.id), 0);
  drawButton(ctx, layout.sellAll, '全部卖出', {
    hover: total > 0 && rectHit(layout.sellAll, mx, my),
    disabled: total <= 0,
    fontSize: 16,
  });

  drawButton(ctx, layout.back, '返回', { hover: rectHit(layout.back, mx, my), fontSize: 16 });
  ctx.textAlign = 'center';
  ctx.font = `13px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.40)';
  ctx.fillText('按 Esc 返回主菜单', panel.x + panel.w / 2, panel.y + panel.h - 12);

  ctx.restore();
}

// ---------- 撤离抉择 ----------

function extractionLayout(viewW, viewH) {
  const bw = Math.min(300, viewW * 0.3), bh = 68, gap = 36;
  const y = viewH * 0.58;
  return {
    extract: { x: viewW / 2 - bw - gap / 2, y, w: bw, h: bh },
    continue: { x: viewW / 2 + gap / 2, y, w: bw, h: bh },
  };
}

export function updateExtraction(game) {
  const input = game.input;
  if (input.wasPressed('KeyE')) { game.chooseExtraction(true); return; }
  if (input.wasPressed('KeyC')) { game.chooseExtraction(false); return; }
  if (!input.mouseClicked()) return;
  const { w, h } = viewSize();
  const layout = extractionLayout(w, h);
  const { x, y } = input.mouse;
  if (rectHit(layout.extract, x, y)) { game.chooseExtraction(true); return; }
  if (rectHit(layout.continue, x, y)) game.chooseExtraction(false);
}

export function drawExtraction(ctx, viewW, viewH, game) {
  ctx.save();
  drawOverlay(ctx, viewW, viewH, 0.72);

  const wave = game.waveDirector?.wave ?? 1;
  const waveRewardMult = CONFIG.meta?.waveRewardMult ?? 1.5;
  const reward = Math.round(wave * waveRewardMult);
  const backpack = materialEntries(game.tempBackpack);
  const layout = extractionLayout(viewW, viewH);
  const mx = game.input.mouse.x;
  const my = game.input.mouse.y;

  ctx.textAlign = 'center';
  ctx.font = `bold 36px ${UI_FONT}`;
  ctx.fillStyle = '#ffd54f';
  ctx.fillText('Boss 已击破 · 抉择时刻', viewW / 2, viewH * 0.24);

  ctx.font = `14px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.50)';
  ctx.fillText('战斗已暂停', viewW / 2, viewH * 0.30);

  // 临时背包（空则显示「（空）」）
  ctx.font = `15px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.60)';
  ctx.fillText('临时背包（本次战利品）', viewW / 2, viewH * 0.375);
  if (backpack.length === 0) {
    ctx.font = `18px ${UI_FONT}`;
    ctx.fillStyle = 'rgba(255,255,255,0.45)';
    ctx.fillText('（空）', viewW / 2, viewH * 0.43);
  } else {
    ctx.font = `22px ${EMOJI_FONT}`;
    ctx.fillStyle = '#ffffff';
    ctx.fillText(backpack.map((e) => `${e.item.icon} ×${e.count}`).join('    '), viewW / 2, viewH * 0.43);
  }

  ctx.font = `bold 18px ${UI_FONT}`;
  ctx.fillStyle = '#b39ddb';
  ctx.fillText(`撤离保底奖励：🌑 暗晶 +${reward}（第 ${wave} 波 × ${waveRewardMult}）`, viewW / 2, viewH * 0.505);

  drawButton(ctx, layout.extract, '撤离（E）', {
    hover: rectHit(layout.extract, mx, my), accent: '#66bb6a', fontSize: 22,
  });
  drawButton(ctx, layout.continue, '继续深入（C）', {
    hover: rectHit(layout.continue, mx, my), accent: '#ff8a80', fontSize: 22,
  });

  ctx.font = `14px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.fillText('提示：继续深入后若死亡，将丢失临时背包中的全部材料', viewW / 2, layout.extract.y + layout.extract.h + 36);

  ctx.restore();
}

// ---------- 撤离结算 ----------

function summaryLayout(viewW, viewH) {
  const pw = Math.min(640, viewW - 60);
  const ph = Math.min(480, viewH - 80);
  const panel = { x: (viewW - pw) / 2, y: (viewH - ph) / 2, w: pw, h: ph };
  const backW = 220, backH = 50;
  const back = { x: (viewW - backW) / 2, y: panel.y + ph - 96, w: backW, h: backH };
  return { panel, back };
}

export function updateSummary(game) {
  const input = game.input;
  if (input.wasPressed('Enter')) { game.confirmSummary(); return; }
  if (!input.mouseClicked()) return;
  const { w, h } = viewSize();
  const { back } = summaryLayout(w, h);
  const { x, y } = input.mouse;
  if (rectHit(back, x, y)) game.confirmSummary();
}

export function drawSummary(ctx, viewW, viewH, game) {
  ctx.save();
  drawOverlay(ctx, viewW, viewH, 0.7);

  const layout = summaryLayout(viewW, viewH);
  const panel = layout.panel;
  drawPanel(ctx, panel);

  const summary = game.lastRunSummary ?? {};
  const banked = materialEntries(summary.itemsBanked);
  const mx = game.input.mouse.x;
  const my = game.input.mouse.y;

  ctx.textAlign = 'center';
  ctx.font = `bold 34px ${UI_FONT}`;
  ctx.fillStyle = '#66bb6a';
  ctx.fillText('成功撤离', panel.x + panel.w / 2, panel.y + 56);

  // 本局统计
  const statRows = [
    ['到达波数', `第 ${summary.wave ?? 0} 波`],
    ['击杀数', `${summary.kills ?? 0}`],
    ['等级', `Lv ${summary.level ?? 1}`],
    ['Boss 击杀', `${summary.bossesDefeated ?? 0}`],
    ['存活时间', formatTime(summary.elapsed ?? 0)],
  ];
  ctx.font = `16px ${UI_FONT}`;
  for (let i = 0; i < statRows.length; i++) {
    const y = panel.y + 106 + i * 30;
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(255,255,255,0.65)';
    ctx.fillText(statRows[i][0], panel.x + 64, y);
    ctx.textAlign = 'right';
    ctx.fillStyle = '#ffffff';
    ctx.fillText(statRows[i][1], panel.x + panel.w - 64, y);
  }

  // 分隔线
  ctx.fillStyle = 'rgba(255,255,255,0.14)';
  ctx.fillRect(panel.x + 48, panel.y + 264, panel.w - 96, 1);

  ctx.textAlign = 'center';
  ctx.font = `bold 18px ${UI_FONT}`;
  ctx.fillStyle = '#ffd54f';
  ctx.fillText('撤离收益', panel.x + panel.w / 2, panel.y + 296);

  ctx.font = `bold 17px ${UI_FONT}`;
  ctx.fillStyle = '#b39ddb';
  ctx.fillText(`🌑 暗晶 +${summary.darkCrystalsGained ?? 0}`, panel.x + panel.w / 2, panel.y + 326);

  ctx.font = `15px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.80)';
  const bankedText = banked.length > 0
    ? '入库材料：' + banked.map((e) => `${e.item.icon} ${e.item.name} ×${e.count}`).join('   ')
    : '入库材料：（无）';
  ctx.fillText(bankedText, panel.x + panel.w / 2, panel.y + 356);

  drawButton(ctx, layout.back, '返回主菜单', { hover: rectHit(layout.back, mx, my), fontSize: 18 });
  ctx.textAlign = 'center';
  ctx.font = `13px ${UI_FONT}`;
  ctx.fillStyle = 'rgba(255,255,255,0.40)';
  ctx.fillText('或按 Enter', panel.x + panel.w / 2, layout.back.y + layout.back.h + 22);

  ctx.restore();
}