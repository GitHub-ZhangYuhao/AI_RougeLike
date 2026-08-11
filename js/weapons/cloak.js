import { WeaponBase } from './base.js';
import { dist2 } from '../utils.js';

// ---------- 炽热披风：自身周围持续灼烧 ----------
// 升级路线：Lv1/3/5 数值成长；Lv2 解锁灼烧；Lv4 解锁震荡冲击；Lv6 震荡冲击质变
export class CloakWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.shockTimer = 0;  // 震荡冲击 CD 倒计时（≤0 即可释放）
    this.shocks = [];     // 震荡冲击扩散动画实例 { x, y, maxR, t, ttl }
    this.lastKills = -1;  // 上一帧 world.kills 快照（Lv6 按增量判断是否跨过 100 击杀）
  }

  update(dt, world) {
    const s = this.stats;
    const px = world.player.x;
    const py = world.player.y;

    // ---------- 光环 tick：每 0.5s 结算一次范围伤害（受冷却属性影响） ----------
    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 0.5 * world.mods.cooldownMult; // 伤害 tick 间隔
      const radius = s.radius * world.mods.areaMult;
      const damage = s.damage * world.mods.damageMult;
      for (const e of world.enemies) {
        if (e.dead) continue;
        if (dist2(px, py, e.x, e.y) <= (radius + e.radius) ** 2) {
          world.damageEnemy(e, damage);
          // Lv2 灼烧：tick 命中的敌人挂 burn（2 秒，同类不叠加只刷新）
          if (s.burn && !e.dead) world.applyDot(e, 'burn', s.burnDps, 2);
        }
      }
    }

    // ---------- Lv4 震荡冲击：内置 CD（×cooldownMult），从玩家中心向外扩散 ----------
    if (s.shock) {
      // Lv6 质变：每击杀 100 个敌人立即重置冲击 CD（按 world.kills 增量判断）
      if (s.shockKillReset && this.lastKills >= 0 &&
          Math.floor(world.kills / 100) > Math.floor(this.lastKills / 100)) {
        this.shockTimer = 0;
      }
      this.shockTimer -= dt;
      if (this.shockTimer <= 0) {
        this.shockTimer = s.shockCd * world.mods.cooldownMult;
        this.fireShock(world);
      }
    }
    this.lastKills = world.kills;

    // 推进冲击波动画（武器实例自管特效）
    if (this.shocks.length > 0) {
      for (const sh of this.shocks) sh.t += dt;
      this.shocks = this.shocks.filter((sh) => sh.t < sh.ttl);
    }
  }

  // 震荡冲击：以玩家为中心一次性大范围结算（伤害 ≈ 数个光环 tick，附加灼烧；Lv6 再减速）
  fireShock(world) {
    const s = this.stats;
    const px = world.player.x;
    const py = world.player.y;
    // 冲击半径 = 披风半径 × 1.5~1.8，吃 areaMult
    const radius = s.radius * s.shockRadiusMult * world.mods.areaMult;
    const damage = s.damage * s.shockTicks * world.mods.damageMult;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(px, py, e.x, e.y) <= (radius + e.radius) ** 2) {
        world.damageEnemy(e, damage);
        if (e.dead) continue; // 已击杀的敌人无需挂 debuff
        world.applyDot(e, 'burn', s.burnDps, 2);      // 冲击同样附加灼烧
        if (s.shockSlow) world.applySlow(e, 0.3, 2);  // Lv6：减速 30% 持续 2 秒
      }
    }
    // 扩散动画存入实例，draw() 里自己画
    this.shocks.push({ x: px, y: py, maxR: radius, t: 0, ttl: 0.45 });
  }

  draw(ctx, world, phase) {
    if (phase === 'under') {
      // 光环下层（原有视觉）
      const radius = this.stats.radius * world.mods.areaMult;
      ctx.save();
      ctx.globalAlpha = 0.10 + 0.04 * Math.sin(world.elapsed * 4);
      ctx.beginPath();
      ctx.arc(world.player.x, world.player.y, radius, 0, Math.PI * 2);
      ctx.fillStyle = '#ff7043';
      ctx.fill();
      ctx.globalAlpha = 0.4;
      ctx.strokeStyle = '#ff8a65';
      ctx.lineWidth = 1.5;
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (phase !== 'over' || this.shocks.length === 0) return;
    // 震荡冲击扩散环（上层特效）
    ctx.save();
    for (const sh of this.shocks) {
      const p = sh.t / sh.ttl; // 扩散进度 0→1
      const r = Math.max(1, sh.maxR * (1 - (1 - p) * (1 - p))); // ease-out 向外扩散
      const fade = 1 - p;
      // 外圈亮色锋线
      ctx.globalAlpha = 0.85 * fade;
      ctx.strokeStyle = '#ffd54f';
      ctx.lineWidth = 1.5 + 3.5 * fade;
      ctx.beginPath();
      ctx.arc(sh.x, sh.y, r, 0, Math.PI * 2);
      ctx.stroke();
      // 内圈厚重光带
      ctx.globalAlpha = 0.28 * fade;
      ctx.strokeStyle = '#ff7043';
      ctx.lineWidth = 2 + 10 * fade;
      ctx.beginPath();
      ctx.arc(sh.x, sh.y, Math.max(1, r * 0.9), 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }
}

export const CARD = {
  id: 'cloak', kind: 'weapon', name: '炽热披风', icon: '🔥', maxLevel: 6,
  desc: '以玩家为中心散发灼热，对范围内敌人造成持续伤害。Lv2 附带灼烧，Lv4 解锁周期性震荡冲击，Lv6 冲击连锁重置并减速敌人。',
  levels: [
    // Lv1 数值基础
    { damage: 5, radius: 70 },
    // Lv2 机制：灼烧 —— tick 命中的敌人挂 burn（dps 10，2 秒）
    { damage: 7, radius: 81, burn: true, burnDps: 10 },
    // Lv3 数值成长（灼烧随等级增强）
    { damage: 10, radius: 92, burn: true, burnDps: 12 },
    // Lv4 机制：震荡冲击 —— CD 5.5s，伤害 ≈ 6 个光环 tick，冲击半径 = 披风 ×1.7
    { damage: 12, radius: 104, burn: true, burnDps: 14, shock: true, shockCd: 5.5, shockTicks: 6, shockRadiusMult: 1.7 },
    // Lv5 数值成长（冲击增强至 ≈7 tick）
    { damage: 15, radius: 115, burn: true, burnDps: 16, shock: true, shockCd: 5.5, shockTicks: 7, shockRadiusMult: 1.7 },
    // Lv6 质变：冲击 CD 降至 3s、伤害 ≈8 tick、半径 ×1.8；每 100 击杀重置冲击 CD；冲击命中减速 2s
    { damage: 18, radius: 128, burn: true, burnDps: 16, shock: true, shockCd: 3, shockTicks: 8, shockRadiusMult: 1.8, shockSlow: true, shockKillReset: true },
  ],
  create() { return new CloakWeapon(this); },
};