import { dist2 } from '../utils.js';

// ---------- 索敌工具（所有武器共用） ----------
export function nearestEnemy(enemies, x, y, maxDist2 = Infinity) {
  let best = null;
  let bestD = maxDist2;
  for (const e of enemies) {
    if (e.dead) continue;
    const d = dist2(x, y, e.x, e.y);
    if (d < bestD) { bestD = d; best = e; }
  }
  return best;
}

export function nearestN(enemies, x, y, n, maxDist2 = Infinity) {
  const list = [];
  for (const e of enemies) {
    if (e.dead) continue;
    const d = dist2(x, y, e.x, e.y);
    if (d <= maxDist2) list.push({ e, d });
  }
  list.sort((a, b) => a.d - b.d);
  return list.slice(0, n).map((o) => o.e);
}

// AoE 辅助：对 (x,y) 半径内所有敌人结算伤害（走 world.damageEnemy，保证击杀计数/掉宝石）
// onHit(e) 可选：对每个被命中的敌人额外做事（如挂 debuff）。返回命中数
export function hitEnemiesInRadius(world, x, y, radius, damage, onHit, damageOptions) {
  let hits = 0;
  for (const e of world.enemies) {
    if (e.dead) continue;
    if (dist2(x, y, e.x, e.y) <= (radius + e.radius) ** 2) {
      world.damageEnemy(e, damage, damageOptions);
      if (onHit) onHit(e);
      hits++;
    }
  }
  return hits;
}

// ---------- 武器基类 ----------
// 卡牌定义（card）在创建时注入，避免与 cards.js 循环依赖
export class WeaponBase {
  constructor(card) {
    this.card = card;
    this.level = 1;
    this.timer = 0;
  }
  // 当前等级数值表（levels 下标 0 = Lv1）。机制开关也放在这里（如 stats.swordQi === true）
  get stats() { return this.card.levels[this.level - 1]; }
  update(dt, world) {}
  // phase: 'under' 画在实体下层（光环/地面），'over' 画在上层（玉环/特效）
  // 武器自己的临时特效请存在武器实例内部，在 draw 里画，不要依赖 game 的 effects 新类型
  draw(ctx, world, phase) {}
}