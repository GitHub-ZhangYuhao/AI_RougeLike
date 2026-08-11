import { WeaponBase, hitEnemiesInRadius } from './base.js';
import { dist2, rand } from '../utils.js';

// ---------- 死灵法杖：周期召唤不可死亡的仆从 ----------
// 每个召唤槽位独立循环：冷却(内置CD) -> 召唤 -> 存活固定时长 -> 回到冷却
// Lv2 尸毒（命中挂 poison）；Lv4 消散自爆；Lv6「百鬼夜行」尸体转化 + 连接回血 + 全员强化

// 尸毒参数（dps 参考契约 6~10，持续 3s）
const POISON_DPS = 8;
const POISON_DUR = 3;
const POISON_RADIUS = 40;      // 尸毒溅射的小范围

// 自爆特效时长
const BLAST_FX_DUR = 0.35;
const BLAST_DMG_MULT = 2;      // 自爆伤害 = 仆从伤害 x2（su.damage 已含 damageMult）

// 百鬼夜行参数
const CORPSE_LIFE = 10;        // 尸体仆从存活时间（建议区间 8~12s）
const CORPSE_CAP = 4;          // 尸体仆从上限（规格 3~5，取 4）
const CONVERT_CHANCE = 0.2;    // 每次击杀转化概率
const PITY_KILLS = 10;         // 保底：每 10 杀至少转化 1 个
const NIGHT_DMG_MULT = 1.5;    // 夜行强化：伤害
const NIGHT_SPD_MULT = 1.3;    // 夜行强化：移速
const NIGHT_REACH = 22;        // 夜行强化：接触攻击范围（平时 14）
const NIGHT_RADIUS = 17;       // 夜行强化：体型（规格 16~18，取 17）

export class StaffWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.slots = [];      // {phase: 'cd'|'active', timer, summon}
    this.corpses = [];    // 尸体仆从列表（用于上限管理，最旧优先顶替）
    this.blasts = [];     // 自爆特效（武器实例自持，draw 里画）
    this.lastKillId = 0;  // killLog 增量消费游标
    this.pity = 0;        // 距上次成功转化的击杀数（保底计数）
  }
  update(dt, world) {
    const s = this.stats;
    // 槽位数随等级变化
    while (this.slots.length < s.count) {
      const isFirst = this.slots.length === 0;
      this.slots.push({ phase: 'cd', timer: isFirst ? 0.5 : s.cd, summon: null });
    }
    if (this.slots.length > s.count) this.slots.length = s.count;

    for (const slot of this.slots) {
      if (slot.phase === 'cd') {
        slot.timer -= dt;
        if (slot.timer <= 0) {
          const summon = {
            x: world.player.x + rand(-24, 24),
            y: world.player.y + rand(-24, 24),
            damage: s.damage * world.mods.damageMult,
            life: s.life,
            speed: s.speed,
            hitTimer: 0,
            wander: Math.random() * Math.PI * 2,
            dead: false,
          };
          slot.summon = summon;
          slot.phase = 'active';
          slot.timer = s.life;
          world.summons.push(summon);
        }
      } else {
        slot.timer -= dt;
        if (slot.timer <= 0) {
          // 存活时间结束：仆从消散，槽位进入内置 CD；若已解锁自爆，在消散那一刻结算
          if (slot.summon) {
            if (s.blast) this.detonate(slot.summon, s, world);
            slot.summon.dead = true;
          }
          slot.summon = null;
          slot.phase = 'cd';
          slot.timer = s.cd * world.mods.cooldownMult;
        }
      }
    }

    for (const slot of this.slots) {
      if (slot.summon && !slot.summon.dead) updateSummon(slot.summon, world, s, dt);
    }

    // killLog 增量消费：游标始终推进（避免低等级积压、升 Lv6 时转化陈旧击杀）；
    // 仅百鬼夜行期间进行尸体转化
    for (const k of world.killLog) {
      if (k.id <= this.lastKillId) continue;
      this.lastKillId = k.id;
      if (!s.nightParade) continue;
      this.pity++;
      if (Math.random() < CONVERT_CHANCE || this.pity >= PITY_KILLS) {
        this.pity = 0;
        this.spawnCorpse(k.x, k.y, s, world);
      }
    }

    // 尸体仆从维护：与召唤仆从共用 AI；存活结束同样自爆
    for (let i = this.corpses.length - 1; i >= 0; i--) {
      const su = this.corpses[i];
      if (su.dead) { this.corpses.splice(i, 1); continue; } // 被上限顶掉等原因
      updateSummon(su, world, s, dt);
      if (su.life <= 0) {
        this.detonate(su, s, world);
        su.dead = true;
        this.corpses.splice(i, 1);
      }
    }

    // 连接回血：按当前存活仆从总数，1 点/秒 + 每多 1 个 +0.5，封顶 3 点/秒
    if (s.nightParade) {
      let alive = 0;
      for (const su of world.summons) if (!su.dead) alive++;
      if (alive > 0) {
        const hps = Math.min(3, 1 + 0.5 * (alive - 1));
        world.healPlayer(hps * dt);
      }
    }

    // 自爆特效寿命
    for (let i = this.blasts.length - 1; i >= 0; i--) {
      const b = this.blasts[i];
      b.t -= dt;
      if (b.t <= 0) this.blasts.splice(i, 1);
    }
  }

  // 自爆：消散瞬间对半径内敌人结算伤害（走统一伤害入口），并记录特效
  detonate(su, s, world) {
    const r = (s.blastRadius || 70) * world.mods.areaMult;
    hitEnemiesInRadius(world, su.x, su.y, r, su.damage * BLAST_DMG_MULT);
    this.blasts.push({ x: su.x, y: su.y, maxR: r, t: BLAST_FX_DUR, dur: BLAST_FX_DUR });
  }

  // 在击杀点转化一具尸体仆从；超出上限时顶掉最旧的
  spawnCorpse(x, y, s, world) {
    while (this.corpses.length >= CORPSE_CAP) {
      const oldest = this.corpses.shift();
      oldest.dead = true; // 顶替不算存活到期，不触发自爆
    }
    const summon = {
      x: x + rand(-8, 8),
      y: y + rand(-8, 8),
      damage: s.damage * world.mods.damageMult,
      life: CORPSE_LIFE,
      speed: s.speed,
      hitTimer: 0,
      wander: Math.random() * Math.PI * 2,
      dead: false,
      corpse: true, // drawSummon 自动换色
    };
    this.corpses.push(summon);
    world.summons.push(summon);
  }

  // 自爆特效画在 over 层
  draw(ctx, world, phase) {
    if (phase !== 'over') return;
    for (const b of this.blasts) {
      const k = 1 - b.t / b.dur; // 0 -> 1
      const r = b.maxR * (0.4 + 0.6 * k);
      ctx.save();
      // 扩散冲击环
      ctx.globalAlpha = (1 - k) * 0.85;
      ctx.strokeStyle = '#ce93d8';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(b.x, b.y, r, 0, Math.PI * 2);
      ctx.stroke();
      // 内部残光
      ctx.globalAlpha = (1 - k) * 0.25;
      ctx.fillStyle = '#7e57c2';
      ctx.beginPath();
      ctx.arc(b.x, b.y, r * 0.75, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }
}

// 召唤物 AI：追击 leash 范围内最近的敌人；无目标时绕玩家盘旋；不会离开 leash
// 召唤仆从与尸体仆从共用；百鬼夜行期间体型/伤害/攻击范围/移速大幅提升
function updateSummon(su, world, s, dt) {
  su.life -= dt;
  su.hitTimer -= dt;
  const p = world.player;
  const leash = s.leash;
  const night = !!s.nightParade;

  // 体型：夜行 17 / 尸体 12 / 普通 11（drawSummon 已支持 su.radius）
  su.radius = night ? NIGHT_RADIUS : (su.corpse ? 12 : 11);

  let target = null;
  let best = Infinity;
  for (const e of world.enemies) {
    if (e.dead) continue;
    if (dist2(p.x, p.y, e.x, e.y) > leash * leash) continue; // 不追击 leash 外敌人
    const d = dist2(su.x, su.y, e.x, e.y);
    if (d < best) { best = d; target = e; }
  }

  let tx, ty;
  if (target) {
    tx = target.x; ty = target.y;
  } else {
    su.wander += dt * 1.3;
    tx = p.x + Math.cos(su.wander) * 52;
    ty = p.y + Math.sin(su.wander) * 52;
  }
  const dx = tx - su.x, dy = ty - su.y;
  const d = Math.hypot(dx, dy) || 1;
  const spd = su.speed * (night ? NIGHT_SPD_MULT : 1);
  if (d > 6) {
    su.x += (dx / d) * spd * dt;
    su.y += (dy / d) * spd * dt;
  }

  // 硬 leash：任何情况下不离玩家太远
  const dp = Math.hypot(su.x - p.x, su.y - p.y);
  if (dp > leash) {
    su.x = p.x + ((su.x - p.x) / dp) * leash;
    su.y = p.y + ((su.y - p.y) / dp) * leash;
  }

  // 接触攻击（夜行期间范围与伤害提升）
  const reach = (night ? NIGHT_REACH : 14) + (target ? target.radius : 0);
  if (target && best <= reach * reach && su.hitTimer <= 0) {
    su.hitTimer = 0.5;
    world.damageEnemy(target, su.damage * (night ? NIGHT_DMG_MULT : 1));
    // 尸毒：对目标及其小范围内敌人挂 poison（不叠加只刷新）
    if (s.poison) {
      world.applyDot(target, 'poison', POISON_DPS, POISON_DUR);
      for (const e of world.enemies) {
        if (e.dead || e === target) continue;
        if (dist2(target.x, target.y, e.x, e.y) <= (POISON_RADIUS + e.radius) ** 2) {
          world.applyDot(e, 'poison', POISON_DPS, POISON_DUR);
        }
      }
    }
  }
}

export function drawSummon(ctx, su) {
  const fading = su.life < 1 && Math.floor(su.life * 8) % 2 === 0;
  ctx.save();
  ctx.globalAlpha = fading ? 0.35 : 1;
  ctx.beginPath();
  ctx.arc(su.x, su.y, su.radius || 11, 0, Math.PI * 2);
  ctx.fillStyle = su.corpse ? '#8d9e63' : '#b39ddb';
  ctx.fill();
  ctx.fillStyle = '#311b92';
  ctx.beginPath();
  ctx.arc(su.x - 3.5, su.y - 2, 1.8, 0, Math.PI * 2);
  ctx.arc(su.x + 3.5, su.y - 2, 1.8, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

export const CARD = {
  id: 'staff', kind: 'weapon', name: '死灵法杖', icon: '🦴', maxLevel: 6,
  desc: '周期性召唤仆从作战。仆从无法被击杀，但有固定存活时间，消散时自爆；高级解锁尸毒，最终化为百鬼夜行：转化尸体仆从并连接回血。',
  levels: [
    // Lv1 基线
    { damage: 7,  count: 1, life: 6,   cd: 4,   speed: 170, leash: 260 },
    // Lv2 机制：召唤 CD 减少 + 数量 2 + 尸毒
    { damage: 9,  count: 2, life: 6.8, cd: 3.6, speed: 180, leash: 260, poison: true },
    // Lv3 数值：伤害 + 存活时间 + CD
    { damage: 12, count: 2, life: 7.5, cd: 3.2, speed: 190, leash: 260, poison: true },
    // Lv4 机制：消散自爆（半径 70）
    { damage: 14, count: 2, life: 8.2, cd: 2.8, speed: 200, leash: 260, poison: true, blast: true, blastRadius: 70 },
    // Lv5 数值：数量 3 + 自爆半径 +50% + 存活时间
    { damage: 17, count: 3, life: 9,   cd: 2.5, speed: 210, leash: 260, poison: true, blast: true, blastRadius: 105 },
    // Lv6 质变「百鬼夜行」：尸体转化 + 连接回血 + 全员强化
    { damage: 20, count: 3, life: 9.8, cd: 2.2, speed: 220, leash: 280, poison: true, blast: true, blastRadius: 105, nightParade: true },
  ],
  create() { return new StaffWeapon(this); },
};