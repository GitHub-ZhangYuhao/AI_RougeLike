import { WeaponBase } from './base.js';
import { dist2 } from '../utils.js';

const RING_HIT_COOLDOWN = 0.34;
const RING_RADIUS = 42;
const CHARGED_BURST_RADIUS = 55;
const CHARGED_DAMAGE_MULTIPLIER = 0.75;
const DEFAULT_BURN_DPS = 12;
const BURN_DURATION = 2;
const GUARDIAN_SYNERGY_ID = 'ring-staff-guardian';
const GUARDIAN_ORBIT_RADIUS = 25;
const GUARDIAN_AURA_RADIUS = 34;
const FRENZY_KILL_STEP = 50;

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
    this.burningRings = [];
    this.ringCharge = [];
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
  _syncRingSynergies(world, positions) {
    const burningActive = world.hasSynergy('ring-cloak-burning');
    const cloak = burningActive ? world.getWeapon('cloak') : null;
    if (cloak) {
      const cloakRadius = cloak.stats.radius || 0;
      const cloakRadius2 = cloakRadius ** 2;
      this.burningRings = positions.map((p) => (
        dist2(world.player.x, world.player.y, p.x, p.y) <= cloakRadius2
      ));
    } else {
      this.burningRings = positions.map(() => false);
    }

    const chargeActive = world.hasSynergy('ring-trail-charge');
    const trail = chargeActive ? world.getWeapon('trail') : null;
    if (!trail || typeof trail.findFurnaceAt !== 'function') {
      this.ringCharge = [];
      return cloak;
    }

    while (this.ringCharge.length < positions.length) {
      this.ringCharge.push({ charged: false, insideFurnace: null });
    }
    this.ringCharge.length = positions.length;
    for (let i = 0; i < positions.length; i++) {
      const p = positions[i];
      const state = this.ringCharge[i];
      const furnace = trail.findFurnaceAt(p.x, p.y, RING_RADIUS);
      if (furnace) {
        if (!state.insideFurnace && !state.charged) {
          state.charged = true;
          world.effects.push({
            type: 'synergyBurst',
            style: 'jadeCharge',
            x: p.x,
            y: p.y,
            radius: 28,
            color: '#ffb74d',
            accent: '#d1ff8a',
            ttl: 0.28,
            maxTtl: 0.28,
          });
        }
        state.insideFurnace = furnace;
      } else {
        state.insideFurnace = null;
      }
    }
    return cloak;
  }

  _releaseFurnaceCharge(ringIndex, position, damage, world) {
    const state = this.ringCharge[ringIndex];
    if (!state?.charged || state.insideFurnace) return;

    state.charged = false;
    const burstDamage = damage * CHARGED_DAMAGE_MULTIPLIER;
    let hits = 0;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(position.x, position.y, e.x, e.y) > (CHARGED_BURST_RADIUS + e.radius) ** 2) continue;
      world.damageEnemy(e, burstDamage, {
        sourceWeaponId: 'ring',
        sourceAction: 'furnace-charge-burst',
        sourceTags: ['ring', 'fire', 'area', 'synergy'],
        synergyId: 'ring-trail-charge',
        noSynergy: true,
        noSummon: true,
      });
      hits++;
    }
    world.recordSynergyTrigger('ring-trail-charge', Math.max(1, hits));
    world.effects.push({
      type: 'synergyBurst',
      style: 'jadeCharge',
      x: position.x,
      y: position.y,
      radius: CHARGED_BURST_RADIUS,
      color: '#ff8a50',
      accent: '#d1ff8a',
      ttl: 0.3,
      maxTtl: 0.3,
    });
  }

  update(dt, world) {
    const s = this.stats;
    this.angle += s.orbitSpeed * dt;
    const frenzy = !!s.ultimate && this.frenzyTimer > 0;

    // Lv6 狂暴：每累计 50 击杀获得 4 秒狂暴
    if (s.ultimate) {
      this.frenzyTimer = Math.max(0, this.frenzyTimer - dt);
      this.counterCd = Math.max(0, this.counterCd - dt);
      while (world.kills >= this.nextFrenzyKills) {
        this.nextFrenzyKills += FRENZY_KILL_STEP;
        this.frenzyTimer = 4;  // 狂暴 4 秒
        this.dropT = 0;        // 立即进入扩张段，狂暴即时生效
      }
      // 受击监听：lastHurtAt 变化且内置 CD 转好 → 冰霜新星反制
      const hurtAt = world.player.lastHurtAt;
      if (hurtAt !== this.lastHurtSeen) {
        this.lastHurtSeen = hurtAt;
        if (hurtAt >= 0 && this.counterCd <= 0) {
          this.counterCd = (s.counterCd || 16); // 内置 CD（基准 16s）
          const radius = (s.counterRadius || 240);
          const dmg = (s.counterDamage || 130) * world.mods.damageMult;
          for (const e of world.enemies) {
            if (e.dead) continue;
            if (dist2(world.player.x, world.player.y, e.x, e.y) <= (radius + e.radius) ** 2) {
              world.applyFreeze(e, 2); // 冻结 2s
              world.damageEnemy(e, dmg, {
                sourceWeaponId: 'ring',
                sourceAction: 'counter-nova',
                sourceTags: ['ring', 'cold', 'area'],
              });
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
      const period = 3.2; // 3.2s 一个来回，节奏更紧凑
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
    // 扩张段伤害 ×2；狂暴期间再 ×2（即扩张段 ×4）
    const damage = s.damage * world.mods.damageMult * (frenzy ? 2 : 1) * (expanding ? 2 : 1);
    const positions = this.ringPositions(world);
    const cloak = this._syncRingSynergies(world, positions);
    const burnDps = cloak?.stats.burnDps || DEFAULT_BURN_DPS;
    for (const e of world.enemies) {
      if (e.dead || e.ringCd > 0) continue;
      for (let ringIndex = 0; ringIndex < positions.length; ringIndex++) {
        const p = positions[ringIndex];
        if (dist2(p.x, p.y, e.x, e.y) <= (RING_RADIUS + e.radius) ** 2) {
          e.ringCd = RING_HIT_COOLDOWN;
          world.damageEnemy(e, damage, {
            sourceWeaponId: 'ring',
            sourceAction: 'contact',
            sourceTags: ['ring', 'contact'],
          });
          if (this.burningRings[ringIndex] && !e.dead) {
            world.applyDot(e, 'burn', burnDps, BURN_DURATION);
            world.recordSynergyTrigger('ring-cloak-burning', 1);
          }
          if (s.coldJade && !e.dead) world.applySlow(e, 0.35, 1.6);
          this._releaseFurnaceCharge(ringIndex, p, damage, world);
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
    const ringR = expanding ? 48 : RING_RADIUS;
    const color = frenzy ? '#ff1744' : expanding ? '#ff5252' : '#69f0ae';
    const positions = this.ringPositions(world);
    const staff = (world.hasSynergy?.(GUARDIAN_SYNERGY_ID) ?? false)
      ? world.getWeapon?.('staff')
      : null;
    const guardianWards = staff?.getGuardianWards?.() ?? [];
    for (let wardIndex = 0; wardIndex < guardianWards.length; wardIndex++) {
      const ward = guardianWards[wardIndex];
      const summon = ward.summon;
      if (!summon || summon.dead || summon.life <= 0 || !summon.guardianWardActive) continue;

      const pulse = 0.5 + Math.sin(world.elapsed * 5 + ward.phase) * 0.5;
      const auraRadius = GUARDIAN_AURA_RADIUS + pulse * 3;
      const orbitAngle = world.elapsed * 3.4 + ward.phase;
      const jadeX = summon.x + Math.cos(orbitAngle) * GUARDIAN_ORBIT_RADIUS;
      const jadeY = summon.y + Math.sin(orbitAngle) * GUARDIAN_ORBIT_RADIUS;

      ctx.save();
      ctx.globalAlpha = 0.16 + pulse * 0.08;
      ctx.fillStyle = '#80cbc4';
      ctx.beginPath();
      ctx.arc(summon.x, summon.y, auraRadius, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 0.72;
      ctx.strokeStyle = '#b2ffef';
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 7]);
      ctx.lineDashOffset = -world.elapsed * 20;
      ctx.beginPath();
      ctx.arc(summon.x, summon.y, auraRadius - 4, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.translate(jadeX, jadeY);
      ctx.rotate(orbitAngle + Math.PI / 4);
      ctx.fillStyle = '#69f0ae';
      ctx.strokeStyle = '#e0fff7';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, -7);
      ctx.lineTo(5, 0);
      ctx.lineTo(0, 7);
      ctx.lineTo(-5, 0);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }
    for (let ringIndex = 0; ringIndex < positions.length; ringIndex++) {
      const p = positions[ringIndex];
      ctx.beginPath();
      ctx.arc(p.x, p.y, ringR, 0, Math.PI * 2);
      const burning = this.burningRings[ringIndex];
      const charged = this.ringCharge[ringIndex]?.charged;
      ctx.fillStyle = burning ? '#ff5722' : color;
      ctx.fill();
      if (burning) {
        const pulse = 3 + Math.sin(world.elapsed * 9 + ringIndex) * 2;
        ctx.strokeStyle = '#ffca66';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(p.x, p.y, ringR + pulse, 0, Math.PI * 2);
        ctx.stroke();
      }
      if (charged) {
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(world.elapsed * 2.6 + ringIndex);
        ctx.strokeStyle = '#d1ff8a';
        ctx.lineWidth = 3;
        ctx.strokeRect(-ringR - 7, -ringR - 7, (ringR + 7) * 2, (ringR + 7) * 2);
        ctx.restore();
      }
      ctx.beginPath();
      ctx.arc(p.x, p.y, 18, 0, Math.PI * 2);
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
  desc: '玉环围绕玩家旋转，触碰的敌人受到伤害。升级增加玉环数量、轨道范围与转速，高阶解锁寒玉减速、血滴子外扩与狂暴反制。',
  levels: [
    // Lv1：两个玉环贴身环绕
    { damage: 12, count: 2, orbitRadius: 56, orbitSpeed: 2.6 },
    // Lv2：寒玉——命中的敌人减速 35%，持续 1.6s
    { damage: 16, count: 2, orbitRadius: 66, orbitSpeed: 2.8, coldJade: true },
    // Lv3：环数加一，轨道外扩、转速提升
    { damage: 20, count: 3, orbitRadius: 78, orbitSpeed: 3.0, coldJade: true },
    // Lv4：血滴子——周期性全部玉环外扩再收回（一个来回），扩张段伤害 ×2
    { damage: 26, count: 4, orbitRadius: 92, orbitSpeed: 3.3, coldJade: true, bloodDrop: true, expandRadius: 80 },
    // Lv5：环数加一，轨道继续外扩
    { damage: 32, count: 5, orbitRadius: 106, orbitSpeed: 3.6, coldJade: true, bloodDrop: true, expandRadius: 95 },
    // Lv6：六环护体；每 50 杀狂暴 4 秒 + 受击冰霜新星反制（CD 16s，冻结 2s）
    { damage: 40, count: 6, orbitRadius: 120, orbitSpeed: 4.0, coldJade: true, bloodDrop: true, expandRadius: 110,
      ultimate: true, counterDamage: 200, counterRadius: 300, counterCd: 16 },
  ],
  create() { return new RingWeapon(this); },
};
