import { CONFIG } from './config.js';
import { RARE_ITEM_BY_ID } from './rare-items.js';
import { META_ITEMS } from './meta/items.js';
import { formatTime } from './utils.js';

export function getWeaponSlotRects() {
  const pad = 14;
  const slotW = 46;
  const slotH = 52;
  const slotGap = 8;
  const slotsY = 8 + 30 + 14 + 32;
  return Array.from({ length: CONFIG.cards.maxWeaponSlots }, (_, index) => ({
    x: pad + index * (slotW + slotGap),
    y: slotsY,
    w: slotW,
    h: slotH,
  }));
}

// HUD：经验、生命、武器、波次、Boss、稀有物品与战斗统计。
export function drawHUD(ctx, viewW, viewH, game) {
  const pad = 14;
  ctx.save();
  ctx.font = CONFIG.hud.font;

  const xpH = 8;
  const need = game.xpToNext();
  const xpRatio = need > 0 ? Math.max(0, Math.min(1, game.xp / need)) : 0;
  ctx.fillStyle = 'rgba(255,255,255,0.10)';
  ctx.fillRect(0, 0, viewW, xpH);
  ctx.fillStyle = '#5ac8fa';
  ctx.fillRect(0, 0, Math.round(viewW * xpRatio), xpH);

  const topY = xpH + 8;
  ctx.textAlign = 'left';
  ctx.font = 'bold 18px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#ffd54f';
  ctx.fillText('Lv ' + game.level, pad, topY + 14);

  const barW = 220, barH = 14;
  const hpY = xpH + 30;
  const hpRatio = Math.max(0, game.player.hp / game.player.maxHp);
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.fillRect(pad, hpY, barW, barH);
  ctx.fillStyle = hpRatio > 0.35 ? '#66bb6a' : '#ef5350';
  ctx.fillRect(pad, hpY, barW * hpRatio, barH);
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.strokeRect(pad + 0.5, hpY + 0.5, barW - 1, barH - 1);
  ctx.fillStyle = '#ffffff';
  ctx.font = CONFIG.hud.font;
  ctx.fillText('HP ' + Math.ceil(Math.max(0, game.player.hp)) + ' / ' + game.player.maxHp, pad, hpY + barH + 18);

  const slotRects = getWeaponSlotRects();
  const slotsY = slotRects[0].y;
  const slotH = slotRects[0].h;
  const selectedWeaponIds = game.synergies?.selectedWeaponIds ?? [];
  for (let i = 0; i < slotRects.length; i++) {
    const rect = slotRects[i];
    const weapon = game.weapons[i];
    const selectedIndex = weapon ? selectedWeaponIds.indexOf(weapon.card.id) : -1;
    const selected = selectedIndex >= 0;
    ctx.fillStyle = selected ? 'rgba(128,222,234,0.18)' : 'rgba(0,0,0,0.40)';
    ctx.fillRect(rect.x, rect.y, rect.w, rect.h);
    ctx.lineWidth = selected ? 3 : 1;
    ctx.strokeStyle = selected ? '#80deea' : 'rgba(255,255,255,0.22)';
    ctx.strokeRect(rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1);
    ctx.lineWidth = 1;
    if (weapon) {
      ctx.textAlign = 'center';
      ctx.font = '22px "Segoe UI Emoji", "Segoe UI Symbol", sans-serif';
      ctx.fillStyle = '#ffffff';
      ctx.fillText(weapon.card.icon, rect.x + rect.w / 2, rect.y + 28);
      ctx.font = 'bold 11px "Segoe UI", "Microsoft YaHei", sans-serif';
      ctx.fillStyle = '#ffd54f';
      ctx.fillText('Lv' + weapon.level, rect.x + rect.w / 2, rect.y + rect.h - 8);
      if (selected) {
        ctx.font = 'bold 10px "Segoe UI", sans-serif';
        ctx.fillStyle = '#80deea';
        ctx.fillText(String(selectedIndex + 1), rect.x + rect.w - 8, rect.y + 11);
      }
      ctx.textAlign = 'left';
    }
  }

  const activeSynergies = game.synergies?.activeDefinitions ?? [];
  const selectedDefinition = game.synergies?.selectedDefinition ?? null;
  const buildLines = [];
  if (selectedWeaponIds.length === 1) {
    const selectedWeapon = game.weapons.find((weapon) => weapon.card.id === selectedWeaponIds[0]);
    buildLines.push({
      text: `Build · 已选 ${selectedWeapon?.card.name ?? selectedWeaponIds[0]}，再点击一把武器`,
      color: '#ffd54f',
    });
  } else if (selectedDefinition) {
    const active = game.synergies.isActive(selectedDefinition.id);
    const suffix = !selectedDefinition.implemented
      ? '（待实装）'
      : active ? '' : '（双方需 Lv4）';
    buildLines.push({
      text: `Build · ${selectedDefinition.name}${suffix}`,
      color: active ? '#80deea' : selectedDefinition.implemented ? '#ffd54f' : '#90a4ae',
    });
  } else {
    if (activeSynergies.length > 0) {
      buildLines.push({
        text: '联动 · ' + activeSynergies.map((entry) => entry.name).join(' · '),
        color: '#80deea',
      });
    }
    if (game.weapons.length >= 2) {
      buildLines.push({ text: '点击两个武器框锁定 Build 组合', color: '#90a4ae' });
    }
  }

  ctx.textAlign = 'left';
  ctx.font = 'bold 12px "Segoe UI", "Microsoft YaHei", sans-serif';
  for (let i = 0; i < buildLines.length; i++) {
    ctx.fillStyle = buildLines[i].color;
    ctx.fillText(buildLines[i].text, pad, slotsY + slotH + 17 + i * 17);
  }
  drawRareInventory(ctx, pad, slotsY + slotH + 14 + buildLines.length * 20, game);

  ctx.textAlign = 'center';
  ctx.font = 'bold 22px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#ffffff';
  ctx.fillText(formatTime(game.elapsed), viewW / 2, topY + 20);

  drawWaveStatus(ctx, viewW, topY, game);
  drawBossBar(ctx, viewW, game);

  ctx.textAlign = 'right';
  ctx.font = CONFIG.hud.font;
  ctx.fillStyle = '#ffffff';
  ctx.fillText('击杀 ' + game.kills, viewW - pad, topY + 14);
  ctx.fillText('敌人 ' + game.enemies.filter((enemy) => !enemy.dead).length, viewW - pad, topY + 34);
  if (game.bossesDefeated > 0) {
    ctx.fillStyle = '#d1c4e9';
    ctx.fillText('Boss ' + game.bossesDefeated, viewW - pad, topY + 54);
  }

  drawCenterMessages(ctx, viewW, viewH, game);

  // 临时背包：撤离入库、死亡全损
  const packEntries = Object.entries(game.tempBackpack ?? {}).filter(([, n]) => n > 0);
  if (packEntries.length > 0) {
    ctx.textAlign = 'right';
    ctx.font = 'bold 13px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = '#b39ddb';
    const packText = '临时背包 ' + packEntries.map(([id, n]) => `${META_ITEMS[id]?.icon ?? id}×${n}`).join(' ');
    ctx.fillText(packText, viewW - pad, viewH - pad - 22);
  }

  ctx.textAlign = 'left';
  ctx.font = CONFIG.hud.font;
  ctx.fillStyle = 'rgba(255,255,255,0.45)';
  ctx.fillText('WASD / 方向键移动 · 武器自动攻击 · 每波持续 90 秒', pad, viewH - pad);
  ctx.restore();
}

function drawWaveStatus(ctx, viewW, topY, game) {
  const director = game.waveDirector;
  if (!director) return;

  ctx.textAlign = 'center';
  ctx.font = 'bold 15px "Segoe UI", "Microsoft YaHei", sans-serif';
  if (director.phase === 'rest') {
    ctx.fillStyle = '#80cbc4';
    ctx.fillText(`第 ${director.wave}/${CONFIG.waves.maxWave} 波完成 · 休整 ${Math.max(0, director.restTimer).toFixed(1)}s`, viewW / 2, topY + 43);
  } else if (director.phase === 'overtime') {
    ctx.fillStyle = '#ff5252';
    ctx.fillText(`第 ${director.wave}/${CONFIG.waves.maxWave} 波 · BOSS 超时，击败后结算`, viewW / 2, topY + 43);
  } else if (director.isBossWave) {
    ctx.fillStyle = '#ff8a80';
    ctx.fillText(`第 ${director.wave}/${CONFIG.waves.maxWave} 波 · BOSS · ${formatTime(Math.ceil(director.timeRemaining))}`, viewW / 2, topY + 43);
  } else {
    ctx.fillStyle = '#e0e0e0';
    ctx.fillText(`第 ${director.wave}/${CONFIG.waves.maxWave} 波 · ${formatTime(Math.ceil(director.timeRemaining))}`, viewW / 2, topY + 43);
  }
}
function drawBossBar(ctx, viewW, game) {
  const boss = game.enemies.find((enemy) => !enemy.dead && enemy.rank === 'boss');
  if (!boss) return;

  const width = Math.min(520, viewW * 0.54);
  const height = 16;
  const x = (viewW - width) / 2;
  const y = 78;
  const ratio = Math.max(0, boss.hp / boss.maxHp);

  ctx.fillStyle = 'rgba(0,0,0,0.72)';
  ctx.fillRect(x, y, width, height);
  ctx.fillStyle = ratio > 0.5 ? '#7c4dff' : '#d32f2f';
  ctx.fillRect(x, y, width * ratio, height);
  ctx.strokeStyle = '#d1c4e9';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(x + 0.5, y + 0.5, width - 1, height - 1);
  ctx.textAlign = 'center';
  ctx.font = 'bold 13px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#ffffff';
  ctx.fillText(`${boss.name ?? 'Boss'}  ${Math.ceil(boss.hp)} / ${Math.ceil(boss.maxHp)}`, viewW / 2, y + 13);
}

function drawRareInventory(ctx, x, y, game) {
  const entries = Object.entries(game.rareInventory ?? {}).filter(([, count]) => count > 0);
  if (entries.length === 0) return;

  ctx.textAlign = 'left';
  ctx.font = 'bold 12px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#fff3b0';
  ctx.fillText('稀有物品', x, y);
  let offset = 0;
  for (const [id, count] of entries) {
    const item = RARE_ITEM_BY_ID.get(id);
    if (!item) continue;
    ctx.fillStyle = item.color;
    ctx.fillText(`${item.icon} ${item.name}${count > 1 ? ` ×${count}` : ''}`, x, y + 18 + offset);
    offset += 17;
  }
}

function drawCenterMessages(ctx, viewW, viewH, game) {
  const director = game.waveDirector;
  if (director?.bannerTimer > 0) {
    const alpha = Math.min(1, director.bannerTimer * 1.5);
    const label = director.phase === 'rest'
      ? '波次完成 · 准备休整'
      : (director.isBossWave ? `第 ${director.wave} 波 · BOSS 来袭` : `第 ${director.wave} 波`);
    ctx.textAlign = 'center';
    ctx.font = 'bold 34px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = director.isBossWave ? `rgba(255,82,82,${alpha})` : `rgba(255,255,255,${alpha})`;
    ctx.fillText(label, viewW / 2, viewH * 0.2);
  }

  const message = game.rareMessage ?? game.synergies?.announcement;
  if (!message) return;
  const alpha = Math.min(1, message.ttl * 2, (message.maxTtl - message.ttl) * 4);
  ctx.textAlign = 'center';
  ctx.font = 'bold 25px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = message.color;
  ctx.globalAlpha = Math.max(0, alpha);
  ctx.fillText(message.text, viewW / 2, viewH * 0.3);
  ctx.font = '15px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#ffffff';
  ctx.fillText(message.detail, viewW / 2, viewH * 0.3 + 25);
  ctx.globalAlpha = 1;
}

export function drawGameOver(ctx, viewW, viewH, game) {
  ctx.save();
  ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
  ctx.fillRect(0, 0, viewW, viewH);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#ff5252';
  ctx.font = 'bold 44px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillText('你死了', viewW / 2, viewH / 2 - 40);
  ctx.fillStyle = '#ffffff';
  ctx.font = '20px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillText('存活 ' + formatTime(game.elapsed) + ' · Lv ' + game.level + ' · 击杀 ' + game.kills, viewW / 2, viewH / 2 + 4);
  ctx.fillStyle = 'rgba(255,255,255,0.75)';
  ctx.font = '16px "Segoe UI", "Microsoft YaHei", sans-serif';
  const lostEntries = Object.entries(game.lastDeathLoss ?? {}).filter(([, n]) => n > 0);
  if (lostEntries.length > 0) {
    ctx.fillStyle = '#ff8a80';
    const lostText = '临时背包损失：' + lostEntries.map(([id, n]) => `${META_ITEMS[id]?.name ?? id}×${n}`).join(' ');
    ctx.fillText(lostText, viewW / 2, viewH / 2 + 34);
    ctx.fillStyle = 'rgba(255,255,255,0.75)';
    ctx.fillText('按 R 返回主菜单', viewW / 2, viewH / 2 + 60);
  } else {
    ctx.fillText('按 R 返回主菜单', viewW / 2, viewH / 2 + 38);
  }
  ctx.restore();
}
