import { WeaponBase, hitEnemiesInRadius } from './base.js';
import { dist2, rand } from '../utils.js';

// ---------- 死灵法杖：周期召唤不可死亡的仆从 ----------
// 每个召唤槽位独立循环：冷却(内置CD) -> 待命(附近有敌才部署) -> 存活固定时长 -> 回到冷却
// Lv2 尸毒（命中挂 poison）；Lv4 消散自爆；Lv6「百鬼夜行」尸体转化 + 连接回血 + 全员强化

// 尸毒参数（dps 参考契约 6~10，持续 3s）
const POISON_DPS = 8;
const POISON_DUR = 3;
const POISON_RADIUS = 50;      // 尸毒溅射的小范围

// 自爆特效时长
const BLAST_FX_DUR = 0.35;
const BLAST_DMG_MULT = 2;      // 自爆伤害 = 仆从伤害 x2（su.damage 已含 damageMult）
const SUMMON_DAMAGE_META = { sourceWeaponId: 'staff', sourceAction: 'summon', sourceTags: ['summon'] };

const GHOSTFIRE_SYNERGY_ID = 'cloak-staff-ghostfire';
const GHOSTFIRE_RADIUS = 55;
const GHOSTFIRE_TICK = 0.5;
const GHOSTFIRE_LINGER = 0.5;
const GHOSTFIRE_DAMAGE_MULT = 0.35;
const GHOSTFIRE_DAMAGE_META = {
  sourceWeaponId: 'staff',
  sourceAction: 'ghostfire',
  sourceTags: ['summon', 'fire', 'aura'],
  synergyId: GHOSTFIRE_SYNERGY_ID,
  noSynergy: true,
  noSummon: true,
};
const CORPSE_FIRE_SYNERGY_ID = 'trail-staff-corpse-fire';
const CORPSE_FIRE_FUEL = 1.5;
const GUARDIAN_SYNERGY_ID = 'ring-staff-guardian';
const GUARDIAN_WARD_CAP = 2;
const GUARDIAN_ROTATION_INTERVAL = 2.4;
const GUARDIAN_SLOW_FACTOR = 0.35;
const GUARDIAN_SLOW_DURATION = 1.6;
const GUARDIAN_PULSE_DURATION = 0.24;

// 百鬼夜行参数
const CORPSE_LIFE = 10;        // 尸体仆从存活时间（建议区间 8~12s）
const REGULAR_CAP = 3;
const CORPSE_CAP = 5;
const TOTAL_CAP = 8;          // regular + corpse summon hard cap
const CONVERT_CHANCE = 0.2;    // 每次击杀转化概率
const PITY_KILLS = 10;         // 保底：每 10 杀至少转化 1 个
const NIGHT_DMG_MULT = 1.5;    // 夜行强化：伤害
const NIGHT_SPD_MULT = 1.3;    // 夜行强化：移速
const NIGHT_REACH = 22;        // 夜行强化：接触攻击范围（平时 14）
const NIGHT_RADIUS = 17;       // 夜行强化：体型（规格 16~18，取 17）

export class StaffWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.slots = [];      // {phase: 'cd'|'ready'|'active', timer, summon}
    this.corpses = [];    // 尸体仆从列表（用于上限管理，最旧优先顶替）
    this.blasts = [];     // 自爆特效（武器实例自持，draw 里画）
    this.lastKillId = 0;  // killLog 增量消费游标
    this.pity = 0;        // 距上次成功转化的击杀数（保底计数）
    this.guardianWards = [];
    this.guardianRotationTimer = 0;
    this.guardianCursor = 0;
  }

  // 缰绳范围内是否有活着的敌人（召唤待命判定用）
  _enemyInLeash(world, leash) {
    const p = world.player;
    const r2 = leash * leash;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(p.x, p.y, e.x, e.y) <= r2) return true;
    }
    return false;
  }


  _aliveStaffSummons() {
    const alive = [];
    const seen = new Set();
    for (const slot of this.slots) {
      const summon = slot.summon;
      if (!summon || summon.dead || summon.life <= 0 || seen.has(summon)) continue;
      seen.add(summon);
      alive.push(summon);
    }
    for (const summon of this.corpses) {
      if (!summon || summon.dead || summon.life <= 0 || seen.has(summon)) continue;
      seen.add(summon);
      alive.push(summon);
    }
    return alive;
  }

  _clearGuardianWards(world) {
    for (const ward of this.guardianWards) clearGuardianWardState(ward.summon, this);
    for (const summon of world.summons ?? []) clearGuardianWardState(summon, this);
    this.guardianWards = [];
    this.guardianRotationTimer = 0;
    this.guardianCursor = 0;
  }

  _syncGuardianWards(dt, world) {
    const active = world.hasSynergy?.(GUARDIAN_SYNERGY_ID) ?? false;
    const ring = active ? world.getWeapon?.('ring') : null;
    if (!ring) {
      this._clearGuardianWards(world);
      return;
    }

    const alive = this._aliveStaffSummons();
    const cap = Math.min(GUARDIAN_WARD_CAP, ring.stats.count || 0, alive.length);
    if (cap <= 0) {
      this._clearGuardianWards(world);
      return;
    }

    this.guardianRotationTimer -= dt;
    const aliveSet = new Set(alive);
    const currentValid = this.guardianWards.length === cap
      && this.guardianWards.every((ward) => aliveSet.has(ward.summon));
    if (currentValid && this.guardianRotationTimer > 0) {
      for (const ward of this.guardianWards) activateGuardianWard(ward.summon, this);
      return;
    }

    for (const ward of this.guardianWards) clearGuardianWardState(ward.summon, this);
    const startIndex = this.guardianCursor % alive.length;
    this.guardianWards = [];
    for (let i = 0; i < cap; i++) {
      const summon = alive[(startIndex + i) % alive.length];
      activateGuardianWard(summon, this);
      this.guardianWards.push({ summon, phase: (startIndex + i) * Math.PI * 0.73 });
    }
    this.guardianCursor = (startIndex + cap) % alive.length;
    this.guardianRotationTimer = GUARDIAN_ROTATION_INTERVAL;
  }

  getGuardianWards() {
    return this.guardianWards;
  }

  // 部署仆从：槽位由 cd/ready 转入 active，仆从寿命从此刻开始消耗
  _deploySummon(slot, s, world) {
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
  update(dt, world) {
    const s = this.stats;
    // 槽位数随等级变化
    const regularCount = Math.min(REGULAR_CAP, s.count);
    while (this.slots.length < regularCount) {
      const isFirst = this.slots.length === 0;
      this.slots.push({ phase: 'cd', timer: isFirst ? 0.5 : s.cd, summon: null });
    }
    while (this.slots.length > regularCount) {
      const removed = this.slots.pop();
      if (removed.summon) this._retireSummon(removed.summon, s, world, !!s.blast);
    }

    // 附近有敌人才召唤：CD 转好后进入待命，敌人进入缰绳范围立即部署，
    // 避免空闲期浪费仆从存活时间（仆从寿命只在战斗中消耗）
    const enemyInLeash = this._enemyInLeash(world, s.leash);
    for (const slot of this.slots) {
      if (slot.phase === 'cd') {
        slot.timer -= dt;
        if (slot.timer <= 0) {
          if (enemyInLeash) this._deploySummon(slot, s, world);
          else { slot.phase = 'ready'; slot.timer = 0; }
        }
      } else if (slot.phase === 'ready') {
        if (enemyInLeash) this._deploySummon(slot, s, world);
      } else {
        slot.timer -= dt;
        if (slot.timer <= 0) {
          // 存活时间结束：仆从消散，槽位进入内置 CD；若已解锁自爆，在消散那一刻结算
          if (slot.summon) this._retireSummon(slot.summon, s, world, !!s.blast);
          slot.summon = null;
          slot.phase = 'cd';
          slot.timer = s.cd;
        }
      }
    }

    this._syncGuardianWards(dt, world);
    for (const slot of this.slots) {
      if (slot.summon && !slot.summon.dead) updateSummon(slot.summon, world, s, dt);
    }

    // killLog 增量消费：游标始终推进（避免低等级积压、升 Lv6 时转化陈旧击杀）；
    // 仅百鬼夜行期间进行尸体转化
    for (const k of world.killLog) {
      if (k.id <= this.lastKillId) continue;
      this.lastKillId = k.id;
      if (!s.nightParade || k.noSummon) continue;
      this.pity++;
      if (Math.random() < CONVERT_CHANCE || this.pity >= PITY_KILLS) {
        this.pity = 0;
        this.spawnCorpse(k.x, k.y, s, world);
      }
    }

    // 尸体仆从维护：与召唤仆从共用 AI；存活结束同样自爆
    for (let i = this.corpses.length - 1; i >= 0; i--) {
      const su = this.corpses[i];
      if (su.dead) {
        this._retireSummon(su, s, world, true);
        this.corpses.splice(i, 1);
        continue;
      }
      updateSummon(su, world, s, dt);
      if (su.life <= 0) {
        this._retireSummon(su, s, world, true);
        this.corpses.splice(i, 1);
      }
    }

    // Link healing: 1 HP/s with one summon, +0.5 per extra summon, capped at 2 HP/s.
    if (s.nightParade) {
      let alive = 0;
      for (const su of world.summons) if (!su.dead) alive++;
      if (alive > 0) {
        const hps = Math.min(2, 1 + 0.5 * (alive - 1));
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

  // 尸火炼丹：仆从经任意受控消亡路径离场时尝试转化，每个仆从只结算一次
  _retireSummon(su, s, world, shouldDetonate) {
    if (!su || su.staffRetired) return false;
    su.staffRetired = true;
    this._convertCorpseFire(su, world);
    if (shouldDetonate) this.detonate(su, s, world);
    clearGuardianWardState(su, this);
    su.dead = true;
    return true;
  }

  _convertCorpseFire(su, world) {
    if (su.corpseFireConverted || !(world.hasSynergy?.(CORPSE_FIRE_SYNERGY_ID) ?? false)) return false;
    const trail = world.getWeapon?.('trail');
    if (!trail || typeof trail.findFurnaceAt !== 'function' || typeof trail.chargeFurnaceAt !== 'function') return false;
    if (!trail.findFurnaceAt(su.x, su.y)) return false;

    const furnace = trail.chargeFurnaceAt(su.x, su.y, CORPSE_FIRE_FUEL, world);
    if (!furnace) return false;
    su.corpseFireConverted = true;
    world.recordSynergyTrigger?.(CORPSE_FIRE_SYNERGY_ID, CORPSE_FIRE_FUEL);
    world.effects.push({
      type: 'synergyArc',
      x1: su.x,
      y1: su.y,
      x2: furnace.center.x,
      y2: furnace.center.y,
      color: '#d68cff',
      ttl: 0.32,
      maxTtl: 0.32,
    });
    world.effects.push({
      type: 'synergyBurst',
      style: 'corpseFire',
      x: furnace.center.x,
      y: furnace.center.y,
      radius: 42,
      color: '#ff7a2f',
      accent: '#d68cff',
      ttl: 0.32,
      maxTtl: 0.32,
    });
    return true;
  }

  // 自爆：消散瞬间对半径内敌人结算伤害（走统一伤害入口），并记录特效
  detonate(su, s, world) {
    const r = s.blastRadius || 70;
    hitEnemiesInRadius(world, su.x, su.y, r, su.damage * BLAST_DMG_MULT, null, {
      ...SUMMON_DAMAGE_META,
      noSummon: true,
    });
    this.blasts.push({ x: su.x, y: su.y, maxR: r, t: BLAST_FX_DUR, dur: BLAST_FX_DUR });
  }

  // 在击杀点转化一具尸体仆从；超出上限时顶掉最旧的
  spawnCorpse(x, y, s, world) {
    const regularAlive = this.slots.reduce((n, slot) => n + (slot.summon && !slot.summon.dead ? 1 : 0), 0);
    while (this.corpses.length >= CORPSE_CAP || regularAlive + this.corpses.length >= TOTAL_CAP) {
      const oldest = this.corpses.shift();
      if (!oldest) return;
      this._retireSummon(oldest, s, world, true);
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

  // 自爆特效画在 over 层；百鬼夜行时额外绘制仆从→玩家的连线回血指示
  draw(ctx, world, phase) {
    if (phase !== 'over') return;
    if (this.stats.nightParade && world.summons) {
      ctx.save();
      ctx.strokeStyle = 'rgba(140,255,170,0.55)';
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 9]);
      // 虚线向玩家方向流动（断断续续的连线，表示正在输送生命）
      ctx.lineDashOffset = -((world.elapsed * 36) % 14);
      for (const su of world.summons) {
        if (su.dead) continue;
        ctx.beginPath();
        ctx.moveTo(su.x, su.y);
        ctx.lineTo(world.player.x, world.player.y);
        ctx.stroke();
      }
      ctx.restore();
    }
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
  su.guardianPulseTimer = Math.max(0, (su.guardianPulseTimer || 0) - dt);
  const p = world.player;
  const leash = s.leash;
  const night = !!s.nightParade;

  // 体型：夜行 17 / 尸体 12 / 普通 11（drawSummon 已支持 su.radius）
  su.radius = night ? NIGHT_RADIUS : (su.corpse ? 12 : 11);
  updateGhostfire(su, world);

  let target = null;
  let best = Infinity;
  const commandActive = world.hasSynergy?.('sword-staff-command') ?? false;
  let commandedTarget = null;
  let commandedBest = Infinity;
  for (const e of world.enemies) {
    if (e.dead) continue;
    if (dist2(p.x, p.y, e.x, e.y) > leash * leash) continue; // 不追击 leash 外敌人
    const d = dist2(su.x, su.y, e.x, e.y);
    if (d < best) { best = d; target = e; }
    if (commandActive && e.synergyMarks?.swordCommandUntil > world.elapsed && d < commandedBest) {
      commandedBest = d;
      commandedTarget = e;
    }
  }
  if (commandedTarget) {
    target = commandedTarget;
    best = commandedBest;
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
    world.damageEnemy(target, su.damage * (night ? NIGHT_DMG_MULT : 1), SUMMON_DAMAGE_META);
    shareGuardianSlow(su, target, world);
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

function activateGuardianWard(summon, owner) {
  summon.guardianWardActive = true;
  summon.guardianWardOwner = owner;
}

function clearGuardianWardState(summon, owner) {
  if (!summon || summon.guardianWardOwner !== owner) return;
  summon.guardianWardActive = false;
  summon.guardianWardOwner = null;
  summon.guardianPulseTimer = 0;
}

function shareGuardianSlow(summon, target, world) {
  if (!summon.guardianWardActive || summon.life <= 0 || target.dead) return false;
  if (!(world.hasSynergy?.(GUARDIAN_SYNERGY_ID) ?? false)) return false;
  const ring = world.getWeapon?.('ring');
  if (!ring?.stats?.coldJade) return false;

  world.applySlow(target, GUARDIAN_SLOW_FACTOR, GUARDIAN_SLOW_DURATION);
  summon.guardianPulseTimer = GUARDIAN_PULSE_DURATION;
  world.recordSynergyTrigger?.(GUARDIAN_SYNERGY_ID, 1);
  return true;
}

function updateGhostfire(su, world) {
  const active = world.hasSynergy?.(GHOSTFIRE_SYNERGY_ID) ?? false;
  if (!active) {
    su.ghostfireActive = false;
    su.ghostfireUntil = -Infinity;
    return;
  }

  const cloak = world.getWeapon?.('cloak');
  const cloakRadius = cloak?.stats?.radius ?? 0;
  if (cloakRadius > 0 && dist2(su.x, su.y, world.player.x, world.player.y) <= cloakRadius * cloakRadius) {
    su.ghostfireUntil = world.elapsed + GHOSTFIRE_LINGER;
  }

  const wasActive = !!su.ghostfireActive;
  su.ghostfireActive = (su.ghostfireUntil ?? -Infinity) > world.elapsed;
  if (!su.ghostfireActive) return;
  if (!wasActive) su.ghostfireNextTickAt = world.elapsed;
  if (world.elapsed < (su.ghostfireNextTickAt ?? -Infinity)) return;
  su.ghostfireNextTickAt = world.elapsed + GHOSTFIRE_TICK;

  let hits = 0;
  for (const e of world.enemies) {
    if (e.dead || world.elapsed < (e.ghostfireCdUntil ?? -Infinity)) continue;
    if (dist2(su.x, su.y, e.x, e.y) > (GHOSTFIRE_RADIUS + e.radius) ** 2) continue;
    e.ghostfireCdUntil = world.elapsed + GHOSTFIRE_TICK;
    world.damageEnemy(e, su.damage * GHOSTFIRE_DAMAGE_MULT, GHOSTFIRE_DAMAGE_META);
    hits++;
  }
  if (hits > 0) world.recordSynergyTrigger?.(GHOSTFIRE_SYNERGY_ID, hits);
}

export function drawSummon(ctx, su) {
  const fading = su.life < 1 && Math.floor(su.life * 8) % 2 === 0;
  const alpha = fading ? 0.35 : 1;
  ctx.save();
  ctx.globalAlpha = alpha;
  if (su.guardianWardActive) {
    const pulse = su.guardianPulseTimer > 0
      ? su.guardianPulseTimer / GUARDIAN_PULSE_DURATION
      : 0;
    const radius = (su.radius || 11) + 10 + pulse * 6;
    ctx.globalAlpha = alpha * (0.18 + pulse * 0.2);
    ctx.fillStyle = '#69f0ae';
    ctx.beginPath();
    ctx.arc(su.x, su.y, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = alpha * (0.72 + pulse * 0.2);
    ctx.strokeStyle = '#b2ffef';
    ctx.lineWidth = 2 + pulse * 2;
    ctx.beginPath();
    ctx.arc(su.x, su.y, radius - 4, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = alpha;
  }
  if (su.ghostfireActive) {
    const radius = (su.radius || 11) + 9;
    ctx.globalAlpha = alpha * 0.24;
    ctx.fillStyle = '#00e5ff';
    ctx.beginPath();
    ctx.arc(su.x, su.y, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = alpha * 0.8;
    ctx.strokeStyle = '#80ffea';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(su.x, su.y, radius - 3, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = alpha;
  }
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
  desc: '周期性召唤仆从作战（附近有敌人才召唤）。仆从无法被击杀，但有固定存活时间，消散时自爆；高级解锁尸毒，最终化为百鬼夜行：转化尸体仆从，仆从连线持续为玩家回复生命。',
  levels: [
    // Lv1 基线
    { damage: 7,  count: 1, life: 6,   cd: 4,   speed: 170, leash: 260 },
    // Lv2 机制：召唤 CD 减少 + 数量 2 + 尸毒
    { damage: 9,  count: 2, life: 6.8, cd: 3.6, speed: 180, leash: 260, poison: true },
    // Lv3 数值：伤害 + 存活时间 + CD
    { damage: 12, count: 2, life: 7.5, cd: 3.2, speed: 190, leash: 260, poison: true },
    // Lv4 机制：消散自爆（半径 70）
    { damage: 14, count: 2, life: 8.2, cd: 2.8, speed: 200, leash: 260, poison: true, blast: true, blastRadius: 85 },
    // Lv5 数值：数量 3 + 自爆半径 +50% + 存活时间
    { damage: 17, count: 3, life: 9,   cd: 2.5, speed: 210, leash: 260, poison: true, blast: true, blastRadius: 125 },
    // Lv6 质变「百鬼夜行」：尸体转化 + 连接回血 + 全员强化
    { damage: 20, count: 3, life: 9.8, cd: 2.2, speed: 220, leash: 280, poison: true, blast: true, blastRadius: 125, nightParade: true },
  ],
  create() { return new StaffWeapon(this); },
};
