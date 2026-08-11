import { CONFIG } from './config.js';
import { formatTime } from './utils.js';

// HUD：顶部经验条 / 等级 / 血条 / 武器槽 / 计时 / 击杀数
export function drawHUD(ctx, viewW, viewH, game) {
  const pad = 14;
  ctx.save();
  ctx.font = CONFIG.hud.font;

  // ---- 顶部全宽经验条 ----
  const xpH = 8;
  const need = game.xpToNext();
  const xpRatio = need > 0 ? Math.max(0, Math.min(1, game.xp / need)) : 0;
  ctx.fillStyle = 'rgba(255,255,255,0.10)';
  ctx.fillRect(0, 0, viewW, xpH);
  ctx.fillStyle = '#5ac8fa';
  ctx.fillRect(0, 0, Math.round(viewW * xpRatio), xpH);

  const topY = xpH + 8;

  // 等级（左上）
  ctx.textAlign = 'left';
  ctx.font = 'bold 18px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#ffd54f';
  ctx.fillText('Lv ' + game.level, pad, topY + 14);

  // ---- 血条（经验条下方） ----
  const barW = 220, barH = 14;
  const hpY = xpH + 30;
  const ratio = Math.max(0, game.player.hp / game.player.maxHp);
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.fillRect(pad, hpY, barW, barH);
  ctx.fillStyle = ratio > 0.35 ? '#66bb6a' : '#ef5350';
  ctx.fillRect(pad, hpY, barW * ratio, barH);
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.strokeRect(pad + 0.5, hpY + 0.5, barW - 1, barH - 1);
  ctx.fillStyle = '#ffffff';
  ctx.font = CONFIG.hud.font;
  ctx.fillText('HP ' + Math.ceil(Math.max(0, game.player.hp)) + ' / ' + game.player.maxHp, pad, hpY + barH + 18);

  // ---- 武器槽（槽位数走配置，不写死） ----
  const slotW = 46, slotH = 52, slotGap = 8;
  const slotsY = hpY + barH + 32;
  for (let i = 0; i < CONFIG.cards.maxWeaponSlots; i++) {
    const x = pad + i * (slotW + slotGap);
    ctx.fillStyle = 'rgba(0,0,0,0.40)';
    ctx.fillRect(x, slotsY, slotW, slotH);
    ctx.strokeStyle = 'rgba(255,255,255,0.22)';
    ctx.strokeRect(x + 0.5, slotsY + 0.5, slotW - 1, slotH - 1);
    const w = game.weapons[i];
    if (w) {
      ctx.textAlign = 'center';
      ctx.font = '22px "Segoe UI Emoji", "Segoe UI Symbol", sans-serif';
      ctx.fillStyle = '#ffffff';
      ctx.fillText(w.card.icon, x + slotW / 2, slotsY + 28);
      ctx.font = 'bold 11px "Segoe UI", "Microsoft YaHei", sans-serif';
      ctx.fillStyle = '#ffd54f';
      ctx.fillText('Lv' + w.level, x + slotW / 2, slotsY + slotH - 8);
      ctx.textAlign = 'left';
    }
  }

  // ---- 计时（顶部居中） ----
  ctx.textAlign = 'center';
  ctx.font = 'bold 22px "Segoe UI", "Microsoft YaHei", sans-serif';
  ctx.fillStyle = '#ffffff';
  ctx.fillText(formatTime(game.elapsed), viewW / 2, topY + 20);

  // ---- 击杀 / 敌人数（右上） ----
  ctx.textAlign = 'right';
  ctx.font = CONFIG.hud.font;
  ctx.fillStyle = '#ffffff';
  ctx.fillText('击杀 ' + game.kills, viewW - pad, topY + 14);
  ctx.fillText('敌人 ' + game.enemies.length, viewW - pad, topY + 34);

  // ---- 操作提示（左下） ----
  ctx.textAlign = 'left';
  ctx.fillStyle = 'rgba(255,255,255,0.45)';
  ctx.fillText('WASD / 方向键移动 · 武器自动攻击 · 升级弹出三选一卡牌（点击或按 1-3）', pad, viewH - pad);

  ctx.restore();
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
  ctx.fillText('按 R 重新开始', viewW / 2, viewH / 2 + 38);
  ctx.restore();
}