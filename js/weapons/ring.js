import { WeaponBase } from './base.js';
import { dist2 } from '../utils.js';

const RING_HIT_COOLDOWN = 0.42;
const FRENZY_KILL_STEP = 80;

// ---------- 玉环：环绕玩家旋转的玉环 ----------
export class RingWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.angle = 0;
    // 血滴子（Lv4+）：周期性外扩再收回
    this.dropT = 0;            // 扩/收周期计时器
    this.expandFactor = 0;     // 当前扩张幅度 0~1（ringPositions / draw 共用）
    this.expanding = false;    // 是否正处于扩张段（扩张段伤害加成）
    // Lv6 质变：击杀狂暴
    this.frenzyTimer = 0;      // 血滴子狂暴剩余时间
    this.nextFrenzyKills = FRENZY_KILL_STEP; // 下次触发狂暴的累计击杀阈值
    // Lv6 质变：受击反制（冰霜新星）
    this.lastHurtSeen = -1;    // 上次观察到的 player.lastHurtAt
    this.counterCd = 0;        // 受击反制剩余内置 CD
    this.counterFx = [];       // 受击反制临时特效（存在武器实例内部）
  }
  // 玉环位置（含血滴子扩张半径，命中判定与 draw 同步）
  ringPositions(world) {
    const s = this.stats;
    const orbitR = s.orbitRadius + this.expandFactor * (s.expandRadius || 0);
    const out = [];
    for (let i = 0; i < s.count; i++) {
      const a = this.angle + (i * Math.PI * 2) / s.count;
      out.push({
        x: world.player.x + Math.cos(a) * orbitR,
        y: world.player.y + Math.sin(a) * orbitR,
      });
    }
    return out;
  }
  update(dt, world) {
    const s = this.stats;
    this.angle += s.orbitSpeed * dt;
    const frenzy = !!s.ultimate && this.frenzyTimer > 0;

    // Lv6 frenzy: every 80 cumulative kills grants 3 seconds of frenzy.
    if (s.ultimate) {
      this.frenzyTimer = Math.max(0, this.frenzyTimer - dt);
      this.counterCd = Math.max(0, this.counterCd - dt);
      while (world.kills >= this.nextFrenzyKills) {
        this.nextFrenzyKills += FRENZY_KILL_STEP;
        this.frenzyTimer = 3;  // 狂暴 3 秒
        this.dropT = 0;        // 立即进入扩张段，狂暴即时生效
      }
      // 受击监听：lastHurtAt 变化且内置 CD 转好 → 冰霜新星反制
      const hurtAt = world.player.lastHurtAt;
      if (hurtAt !== this.lastHurtSeen) {
        this.lastHurtSeen = hurtAt;
        if (hurtAt >= 0 && this.counterCd <= 0) {
          this.counterCd = (s.counterCd || 24); // 内置 CD（基准 24s，保证减 CD 后仍 ≥20s 左右）
          const radius = (s.counterRadius || 240);
          const dmg = (s.counterDamage || 130) * world.mods.damageMult;
          for (const e of world.enemies) {
            if (e.dead) continue;
            if (dist2(world.player.x, world.player.y, e.x, e.y) <= (radius + e.radius) ** 2) {
              world.applyFreeze(e, 1.5); // 冻结 1.5s
              world.damageEnemy(e, dmg); // 一次高额范围伤害（走统一伤害入口）
            }
          }
          this.counterFx.push({ t: 0, dur: 0.6, r: radius });
        }
      }
    }

    // —— 血滴子（Lv4+）：周期性全部玉环外扩再收回，扩张段伤害 ×1.5 ——
    let expanding = false;
    if (s.bloodDrop) {
      const speed = frenzy ? 2 : 1;               // 狂暴：扩张速度 ×2
      const expandDur = 1 / speed;                // 扩张段 ~1s
      const contractDur = 1 / speed;              // 收回段对称 ~1s
      const period = 4; // fixed four-second cycle
      this.dropT += dt;
      while (this.dropT >= period) this.dropT -= period;
      if (this.dropT < expandDur) {
        this.expandFactor = this.dropT / expandDur;                      // 0→1 外扩
        expanding = true;
      } else if (this.dropT < expandDur + contractDur) {
        this.expandFactor = 1 - (this.dropT - expandDur) / contractDur;  // 1→0 收回
      } else {
        this.expandFactor = 0;                                           // 其余时间停在基础半径
      }
    } else {
      this.expandFactor = 0;
    }
    this.expanding = expanding;

    // Shared contact cooldown prevents multiple rings from dealing damage in the same frame.
    // 扩张段伤害 ×1.5；狂暴期间再 ×2（即扩张段 ×3）
    const damage = s.damage * world.mods.damageMult * (frenzy ? 2 : 1) * (expanding ? 1.5 : 1);
    const positions = this.ringPositions(world);
    for (const e of world.enemies) {
      if (e.dead || e.ringCd > 0) continue;
      for (const p of positions) {
        if (dist2(p.x, p.y, e.x, e.y) <= (12 + e.radius) ** 2) {
          e.ringCd = RING_HIT_COOLDOWN;
          world.damageEnemy(e, damage);
          if (s.coldJade) world.applySlow(e, 0.25, 1.2); // 寒玉：减速 25%，持续 1.2s
          break;
        }
      }
    }

    // 受击反制特效老化
    for (let i = this.counterFx.length - 1; i >= 0; i--) {
      this.counterFx[i].t += dt;
      if (this.counterFx[i].t >= this.counterFx[i].dur) this.counterFx.splice(i, 1);
    }
  }
  draw(ctx, world, phase) {
    if (phase !== 'over') return;
    const s = this.stats;
    const frenzy = !!s.ultimate && this.frenzyTimer > 0;
    const expanding = !!s.bloodDrop && this.expanding;
    // 血滴子视觉：扩张段变血红并略微放大；狂暴期间亮红
    const ringR = expanding ? 14 : 12;
    const color = frenzy ? '#ff1744' : expanding ? '#ff5252' : '#69f0ae';
    for (const p of this.ringPositions(world)) {
      ctx.beginPath();
      ctx.arc(p.x, p.y, ringR, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.fill();
      ctx.beginPath();
      ctx.arc(p.x, p.y, 6, 0, Math.PI * 2);
      ctx.fillStyle = '#0e0e16';
      ctx.fill();
    }
    // 血滴子扩张指示环：当前轨道半径细圈，让外扩过程可见
    if (s.bloodDrop && this.expandFactor > 0) {
      const orbitR = s.orbitRadius + this.expandFactor * (s.expandRadius || 0);
      ctx.beginPath();
      ctx.arc(world.player.x, world.player.y, orbitR, 0, Math.PI * 2);
      ctx.strokeStyle = frenzy ? 'rgba(255,23,68,0.5)' : 'rgba(255,82,82,0.35)';
      ctx.lineWidth = 2;
      ctx.stroke();
    }
    // 受击反制：扩散的冰霜新星特效
    for (const fx of this.counterFx) {
      const k = fx.t / fx.dur;
      ctx.beginPath();
      ctx.arc(world.player.x, world.player.y, fx.r * (0.3 + 0.7 * k), 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(128,216,255,${((1 - k) * 0.8).toFixed(3)})`;
      ctx.lineWidth = 4 * (1 - k) + 1;
      ctx.stroke();
    }
  }
}

export const CARD = {
  id: 'ring', kind: 'weapon', name: '玉环', icon: '💍', maxLevel: 6,
  desc: '玉环围绕玩家旋转，触碰的敌人受到伤害。升级增加玉环数量与转速，高阶解锁寒玉减速、血滴子外扩与狂暴反制。',
  levels: [
    // Lv1：基础数值
    { damage: 10, count: 1, orbitRadius: 84, orbitSpeed: 2.4 },
    // Lv2：寒玉——命中的敌人减速 25%，持续 1.2s
    { damage: 13, count: 1, orbitRadius: 91, orbitSpeed: 2.7, coldJade: true },
    // Lv3：数值成长 + 环数加一
    { damage: 16, count: 2, orbitRadius: 99, orbitSpeed: 2.9, coldJade: true },
    // Lv4：血滴子——周期性全部玉环外扩再收回（一个来回），扩张段伤害 ×1.5
    { damage: 20, count: 2, orbitRadius: 107, orbitSpeed: 3.2, coldJade: true, bloodDrop: true, expandRadius: 96 },
    // Lv5：数值成长 + 环数加一
    { damage: 24, count: 3, orbitRadius: 114, orbitSpeed: 3.5, coldJade: true, bloodDrop: true, expandRadius: 103 },
    // Lv6: frenzy every 80 kills plus the reactive frost nova.
    { damage: 28, count: 3, orbitRadius: 122, orbitSpeed: 3.8, coldJade: true, bloodDrop: true, expandRadius: 110,
      ultimate: true, counterDamage: 130, counterRadius: 275, counterCd: 24 },
  ],
  create() { return new RingWeapon(this); },
};
