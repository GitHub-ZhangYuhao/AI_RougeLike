import { CONFIG } from './config.js';

const CARD_W = 210;
const CARD_H = 292;
const CARD_W_SMALL = 200;  // >3 张时（开局选武器）用紧凑卡
const CARD_H_SMALL = 252;
const GAP = 24;

// 计算 count 张卡牌的居中布局矩形（渲染与鼠标命中检测共用）
// <=3 张：单行大卡；>3 张：两行紧凑卡（开局展示全部武器）
export function getCardRects(viewW, viewH, count) {
  const rects = [];
  if (count <= 3) {
    const total = count * CARD_W + (count - 1) * GAP;
    const startX = (viewW - total) / 2;
    const y = (viewH - CARD_H) / 2 + 8;
    for (let i = 0; i < count; i++) {
      rects.push({ x: startX + i * (CARD_W + GAP), y, w: CARD_W, h: CARD_H });
    }
    return rects;
  }
  const rows = 2;
  const cols = Math.ceil(count / rows);
  const w = CARD_W_SMALL, h = CARD_H_SMALL;
  const totalW = cols * w + (cols - 1) * GAP;
  const totalH = rows * h + (rows - 1) * GAP;
  const startX = (viewW - totalW) / 2;
  const startY = (viewH - totalH) / 2 + 16;
  for (let i = 0; i < count; i++) {
    const row = Math.floor(i / cols), col = i % cols;
    // 最后一行不满时居中
    const inRow = row === rows - 1 ? count - cols * (rows - 1) : cols;
    const rowOff = row === rows - 1 ? ((cols - inRow) * (w + GAP)) / 2 : 0;
    rects.push({ x: startX + rowOff + col * (w + GAP), y: startY + row * (h + GAP), w, h });
  }
  return rects;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

// 按字符逐字换行（中文友好）
function wrapText(ctx, text, maxWidth) {
  const lines = [];
  let line = '';
  for (const ch of text) {
    const test = line + ch;
    if (ctx.measureText(test).width > maxWidth && line) {
      lines.push(line);
      line = ch;
    } else {
      line = test;
    }
  }
  if (line) lines.push(line);
  return lines;
}

const TAG_LABEL = {
  new: '\u65b0\u6b66\u5668',
  upgrade: '\u5347\u7ea7!',
  attr: '\u5c5e\u6027',
  taskWeapon: '\u4efb\u52a1\u00b7\u6b66\u5668',
  taskStat: '\u4efb\u52a1\u00b7\u5f3a\u5316',
  taskBlessing: '\u4efb\u52a1\u00b7\u795d\u798f',
};
const TAG_COLOR = {
  new: '#66bb6a',
  upgrade: '#ffb74d',
  attr: '#5ac8fa',
  taskWeapon: '#ffb74d',
  taskStat: '#4dd0e1',
  taskBlessing: '#ce93d8',
};

export function drawChoiceUI(ctx, viewW, viewH, game) {
  const offers = game.currentOffers || [];
  ctx.save();

  // 暗色遮罩
  ctx.fillStyle = 'rgba(6, 6, 14, 0.74)';
  ctx.fillRect(0, 0, viewW, viewH);

  const rects = getCardRects(viewW, viewH, offers.length);
  const topY = rects.length > 0 ? rects[0].y : viewH / 2;

  ctx.textAlign = 'center';
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 30px "Segoe UI", "Microsoft YaHei", sans-serif';
  const title = game.state === 'opening'
    ? '\u9009\u62e9\u521d\u59cb\u6b66\u5668'
    : game.choiceOrigin === 'task'
      ? '\u4efb\u52a1\u5b8c\u6210 \u00b7 \u9009\u62e9\u4e00\u9879\u5f3a\u529b\u5956\u52b1'
      : '\u5347\u7ea7! Lv ' + game.level + ' \u9009\u62e9\u4e00\u5f20\u5361\u724c';
  ctx.fillText(title, viewW / 2, topY - 42);

  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.font = '14px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillText('点击卡片 或 按数字键 1-' + offers.length + ' 选择', viewW / 2, topY - 16);

  const mx = game.input.mouse.x;
  const my = game.input.mouse.y;

  for (let i = 0; i < offers.length; i++) {
    const r = rects[i];
    const offer = offers[i];
    const card = offer.card;
    const hover = mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h;
    const cx = r.x + r.w / 2;
    const k = r.h / CARD_H; // 垂直位置缩放系数（紧凑卡自适应）

    // 卡面底色与描边（hover 高亮）
    roundRect(ctx, r.x, r.y, r.w, r.h, 14);
    ctx.fillStyle = hover ? '#2b2b40' : '#1c1c2b';
    ctx.fill();
    ctx.lineWidth = hover ? 2.5 : 1.5;
    ctx.strokeStyle = hover ? '#ffd54f' : 'rgba(255,255,255,0.28)';
    ctx.stroke();

    // 按键提示（左上）
    roundRect(ctx, r.x + 10, r.y + 10, 26, 26, 6);
    ctx.fillStyle = 'rgba(255,255,255,0.16)';
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.font = 'bold 15px "Segoe UI", sans-serif';
    ctx.fillText(String(i + 1), r.x + 23, r.y + 29);

    // 类型标签（右上）
    ctx.fillStyle = TAG_COLOR[offer.type] || '#ffffff';
    ctx.font = 'bold 13px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(TAG_LABEL[offer.type] || '', r.x + r.w - 12, r.y + 28);
    ctx.textAlign = 'center';

    // 图标
    ctx.font = Math.round(50 * k) + 'px "Segoe UI Emoji", "Segoe UI Symbol", sans-serif';
    ctx.fillStyle = '#ffffff';
    ctx.fillText(card.icon, cx, r.y + 102 * k);

    // 名称
    ctx.font = 'bold ' + Math.round(22 * (k < 1 ? 0.92 : 1)) + 'px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = '#ffffff';
    ctx.fillText(card.name, cx, r.y + 136 * k);

    // 等级 / 层数信息
    ctx.font = '14px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = '#ffd54f';
    let levelInfo;
    if (card.kind === 'taskReward') {
      levelInfo = offer.levelInfo ?? '\u672c\u5c40\u6301\u7eed\u751f\u6548';
    } else if (card.kind === 'weapon') {
      if (offer.type === 'upgrade') {
        const owned = game.weapons.find((w) => w.card.id === card.id);
        const lv = owned ? owned.level : 1;
        levelInfo = 'Lv ' + lv + ' -> Lv ' + (lv + 1);
      } else {
        levelInfo = 'Lv 1';
      }
    } else {
      const n = game.attrStacks[card.id] || 0;
      levelInfo = '已叠 ' + n + ' 层 · 选后 ' + (n + 1) + ' / ' + CONFIG.cards.attrMaxStack;
    }
    ctx.fillText(levelInfo, cx, r.y + 160 * k);

    // 描述（自动换行）
    ctx.font = '13px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = 'rgba(255,255,255,0.72)';
    const lines = wrapText(ctx, card.desc, r.w - 28);
    const lineH = 19 * k;
    const maxLines = k < 1 ? 5 : 6;
    for (let li = 0; li < lines.length && li < maxLines; li++) {
      ctx.fillText(lines[li], cx, r.y + 188 * k + li * lineH);
    }
  }

  ctx.restore();
}
