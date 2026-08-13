import { WeaponBase, nearestEnemy, hitEnemiesInRadius } from './base.js';
import { dist2, angleDiff } from '../utils.js';
import { createProjectile } from '../projectile.js';

const COMMAND_SYNERGY_ID = 'sword-staff-command';
const TALISMAN_MARK_SYNERGY_ID = 'sword-talisman-mark';
const FLAME_BLADE_SYNERGY_ID = 'sword-cloak-flame';
const RING_RETURN_SYNERGY_ID = 'sword-ring-return';
const FURNACE_CUT_SYNERGY_ID = 'sword-trail-cut';
const COMMAND_MARK_DURATION = 3;
const FLAME_BLADE_COOLDOWN = 0.4;
const FLAME_BLADE_DAMAGE_MULT = 0.4;
const FLAME_BLADE_LENGTH = 145;
const FLAME_BLADE_WIDTH = 34;
const RING_RETURN_TOUCH_RADIUS = 52;
const RING_RETURN_SEARCH_RADIUS = 360;
const FURNACE_CUT_DAMAGE_MULT = 0.45;
const FLAME_BLADE_DAMAGE_META = {
  synergyId: FLAME_BLADE_SYNERGY_ID,
  noSynergy: true,
  noSummon: true,
  sourceWeaponId: 'sword',
  sourceAction: 'flame-blade',
  sourceTags: ['fire', 'area'],
};
function pointSegmentDist2(x, y, x1, y1, x2, y2) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const length2 = dx * dx + dy * dy;
  if (length2 <= 0.0001) return dist2(x, y, x1, y1);
  const t = Math.max(0, Math.min(1, ((x - x1) * dx + (y - y1) * dy) / length2));
  return dist2(x, y, x1 + dx * t, y1 + dy * t);
}

const SWORD_DAMAGE_META = {
  melee: { sourceWeaponId: 'sword', sourceAction: 'melee', sourceTags: ['melee'] },
  projectile: { sourceWeaponId: 'sword', sourceAction: 'projectile', sourceTags: ['projectile'] },
  ring: { sourceWeaponId: 'sword', sourceAction: 'ring', sourceTags: ['area'] },
  flyingSword: { sourceWeaponId: 'sword', sourceAction: 'flying-sword', sourceTags: ['projectile'] },
};

// Dao sword: Lv1 melee, Lv2+ becomes a single ranged sword with unlimited piercing.
export class SwordWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.attackCount = 0;
    this.pendingRing = false; // 拔剑斩命中充能后延迟到下一帧释放（使用当前帧敌人列表）
    this.hitCarry = 0; // 剑意累积：每命中 10 次凝一柄飞剑（Lv6）
    this.flyingSwords = [];
    this.rings = [];
    this.flameBladeReadyAt = 0;
  }

  update(dt, world) {
    const s = this.stats;
    this._updateProjectileSynergies(world, s);
    if (this.flyingSwords.length) this._updateFlyingSwords(dt, world, s);

    for (const r of this.rings) r.ttl -= dt;
    this.rings = this.rings.filter((r) => r.ttl > 0);

    if (this.pendingRing) {
      this.pendingRing = false;
      this._fireRing(world, s, s.damage * world.mods.damageMult);
    }

    this.timer -= dt;
    if (this.timer > 0) return;
    this.timer = s.interval;

    const px = world.player.x;
    const py = world.player.y;
    const targetRange = s.projectile ? s.projectileRange : s.meleeRange * 1.8;
    const target = nearestEnemy(world.enemies, px, py, targetRange * targetRange);
    const angle = target ? Math.atan2(target.y - py, target.x - px) : world.player.facing;
    const damage = s.damage * world.mods.damageMult;

    if (s.projectile) this._fireMainSword(world, s, px, py, angle, damage);
    else if (this._meleeSlash(world, s, px, py, angle, damage)) this._countMainHit(s);
  }

  _meleeSlash(world, s, px, py, angle, damage) {
    const halfArc = ((s.arc * Math.PI) / 180) / 2;
    let hitAny = false;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(px, py, e.x, e.y) > (s.meleeRange + e.radius) ** 2) continue;
      const enemyAngle = Math.atan2(e.y - py, e.x - px);
      if (angleDiff(enemyAngle, angle) <= halfArc) {
        world.damageEnemy(e, damage, SWORD_DAMAGE_META.melee);
        this._onDamageHit(e, world, s, true, 'melee');
        hitAny = true;
      }
    }
    world.effects.push({
      type: 'slash', x: px, y: py, angle,
      range: s.meleeRange, arc: halfArc * 2, ttl: 0.18, maxTtl: 0.18,
    });
    return hitAny;
  }

  _fireMainSword(world, s, px, py, angle, damage) {
    const p = createProjectile(px, py, angle, {
      speed: s.projectileSpeed,
      radius: 11,
      damage,
      lifetime: s.projectileRange / s.projectileSpeed,
      color: '#aee9ff',
    });
    p.pierce = true;
    p.maxHits = s.maxHits;
    p.swordQi = true;
    p.damageOptions = SWORD_DAMAGE_META.projectile;
    let counted = false;
    p.onHit = (e) => {
      if (!counted) { counted = true; this._countMainHit(s); }
      this._onDamageHit(e, world, s, true, 'projectile');
      this._tryRingReturn(p, e, world);
    };
    p.synergyPrevX = px;
    p.synergyPrevY = py;
    world.projectiles.push(p);
  }

  _updateProjectileSynergies(world, s) {
    const ringReturnActive = world.hasSynergy?.(RING_RETURN_SYNERGY_ID) ?? false;
    const furnaceCutActive = world.hasSynergy?.(FURNACE_CUT_SYNERGY_ID) ?? false;
    const ring = ringReturnActive ? world.getWeapon?.('ring') : null;
    const ringPositions = ring?.ringPositions?.(world) ?? [];
    const trail = furnaceCutActive ? world.getWeapon?.('trail') : null;

    for (const projectile of world.projectiles) {
      if (!projectile.swordQi || projectile.dead) continue;
      const x1 = projectile.synergyPrevX ?? projectile.x;
      const y1 = projectile.synergyPrevY ?? projectile.y;
      const x2 = projectile.x;
      const y2 = projectile.y;

      if (!ringReturnActive) {
        projectile.ringReturnCharged = false;
      } else if (!projectile.ringReturnCharged && !projectile.ringReturnUsed) {
        const touchRadius2 = (RING_RETURN_TOUCH_RADIUS + projectile.radius) ** 2;
        const touchedRing = ringPositions.find((position) => (
          pointSegmentDist2(position.x, position.y, x1, y1, x2, y2) <= touchRadius2
        ));
        if (touchedRing) {
          projectile.ringReturnCharged = true;
          projectile.color = '#fff59d';
          world.effects.push({
            type: 'synergyArc',
            x1: touchedRing.x,
            y1: touchedRing.y,
            x2: projectile.x,
            y2: projectile.y,
            color: '#d1ff8a',
            ttl: 0.18,
            maxTtl: 0.18,
          });
        }
      }

      if (trail && typeof trail.cutFurnacesAlongSegment === 'function') {
        projectile.furnaceCuts ??= new Set();
        const cutDamage = s.damage * world.mods.damageMult * FURNACE_CUT_DAMAGE_MULT;
        trail.cutFurnacesAlongSegment(
          x1,
          y1,
          x2,
          y2,
          cutDamage,
          world,
          projectile.furnaceCuts,
        );
      } else if (!furnaceCutActive) {
        projectile.furnaceCuts = null;
      }

      projectile.synergyPrevX = projectile.x;
      projectile.synergyPrevY = projectile.y;
    }
  }

  _tryRingReturn(projectile, enemy, world) {
    if (!projectile.ringReturnCharged || projectile.ringReturnUsed) return false;
    projectile.ringReturnCharged = false;
    projectile.ringReturnUsed = true;

    const target = this._nearestEnemyNear(
      world,
      projectile.x,
      projectile.y,
      RING_RETURN_SEARCH_RADIUS ** 2,
      enemy,
    );
    let dx = target ? target.x - projectile.x : -projectile.vx;
    let dy = target ? target.y - projectile.y : -projectile.vy;
    const distance = Math.hypot(dx, dy) || 1;
    dx /= distance;
    dy /= distance;
    projectile.vx = dx * projectile.speed;
    projectile.vy = dy * projectile.speed;
    projectile.angle = Math.atan2(dy, dx);
    projectile.hitSet = new Set([enemy]);
    projectile.hitCount = 0;
    projectile.lifetime = Math.max(projectile.lifetime, 0.8);
    projectile.color = '#c6ff70';

    world.recordSynergyTrigger?.(RING_RETURN_SYNERGY_ID, 1);
    world.effects.push({
      type: 'synergyBurst',
      x: projectile.x,
      y: projectile.y,
      radius: 48,
      color: '#b2ff59',
      accent: '#fff59d',
      ttl: 0.24,
      maxTtl: 0.24,
    });
    return true;
  }

  // 拔剑斩只为「命中敌人的攻击」充能；空挥不计次，避免周围无怪时 CD 空转浪费
  _countMainHit(s) {
    this.attackCount++;
    if (s.drawSlash && this.attackCount % 3 === 0) this.pendingRing = true;
  }

  _fireRing(world, s, mainDamage) {
    const px = world.player.x;
    const py = world.player.y;
    hitEnemiesInRadius(world, px, py, s.ringRadius, mainDamage * 2.5, (e) => {
      if (!e.dead) world.applyDot(e, 'bleed', s.ringBleedDps || 10, 2.5);
      this._onDamageHit(e, world, s, true, 'ring');
    }, SWORD_DAMAGE_META.ring);
    this.rings.push({ x: px, y: py, r: s.ringRadius, ttl: 0.28, maxTtl: 0.28 });
  }

  _onDamageHit(enemy, world, s, countIntent = true, action = 'projectile') {
    if (world.hasSynergy?.(COMMAND_SYNERGY_ID)
      && (action === 'projectile' || action === 'flyingSword')) {
      enemy.synergyMarks ??= {};
      enemy.synergyMarks.swordCommandUntil = world.elapsed + COMMAND_MARK_DURATION;
      world.effects.push({
        type: 'synergyCommandMark',
        x: enemy.x,
        y: enemy.y,
        ttl: 0.32,
        maxTtl: 0.32,
      });
    }
    if (world.hasSynergy?.(TALISMAN_MARK_SYNERGY_ID)) {
      const talisman = world.getWeapon?.('talisman');
      talisman?.triggerSwordThunder?.(enemy, world);
    }
    if (action === 'melee' || action === 'ring') this._tryFlameBlade(enemy, world, s);
    if (countIntent) this._registerHit(world, s);
  }

  _tryFlameBlade(enemy, world, s) {
    if (!world.hasSynergy?.(FLAME_BLADE_SYNERGY_ID)) return;
    if (enemy.dead || !enemy.dots?.burn || enemy.dots.burn.timer <= 0) return;
    if (world.elapsed < this.flameBladeReadyAt) return;

    this.flameBladeReadyAt = world.elapsed + FLAME_BLADE_COOLDOWN;
    let dx = enemy.x - world.player.x;
    let dy = enemy.y - world.player.y;
    const distance = Math.hypot(dx, dy);
    if (distance > 0.001) {
      dx /= distance;
      dy /= distance;
    } else {
      dx = Math.cos(world.player.facing);
      dy = Math.sin(world.player.facing);
    }
    const x1 = enemy.x;
    const y1 = enemy.y;
    const x2 = x1 + dx * FLAME_BLADE_LENGTH;
    const y2 = y1 + dy * FLAME_BLADE_LENGTH;
    const damage = s.damage * world.mods.damageMult * FLAME_BLADE_DAMAGE_MULT;
    let hits = 0;
    for (const target of world.enemies) {
      if (target.dead) continue;
      const radius = FLAME_BLADE_WIDTH + target.radius;
      if (pointSegmentDist2(target.x, target.y, x1, y1, x2, y2) > radius * radius) continue;
      world.damageEnemy(target, damage, FLAME_BLADE_DAMAGE_META);
      hits++;
    }
    world.recordSynergyTrigger?.(FLAME_BLADE_SYNERGY_ID, hits);
    world.effects.push({
      type: 'synergyFlameBlade',
      x1,
      y1,
      x2,
      y2,
      width: FLAME_BLADE_WIDTH,
      ttl: 0.25,
      maxTtl: 0.25,
    });
  }

  // 剑意累积：任意攻击命中敌人 +1（同一目标多次命中也计数，Boss 战可正常积攒）
  _registerHit(world, s, count = 1) {
    if (!s.swordIntent) return;
    this.hitCarry += count;
    while (this.hitCarry >= 10) {
      this.hitCarry -= 10;
      if (this.flyingSwords.length < s.flyMax) this._spawnFlyingSword(world);
    }
  }

  // 穿梭选靶：以飞剑当前位置为中心找范围内最近的活敌人；exclude 用于排除刚飞离的目标
  _nearestEnemyNear(world, x, y, rangeR2, exclude = null) {
    let best = null;
    let bestD = rangeR2;
    for (const e of world.enemies) {
      if (e.dead || e === exclude) continue;
      const d = dist2(x, y, e.x, e.y);
      if (d < bestD) { bestD = d; best = e; }
    }
    return best;
  }

  _spawnFlyingSword(world) {
    this.flyingSwords.push({
      x: world.player.x,
      y: world.player.y,
      angle: Math.random() * Math.PI * 2,
      orbitR: 48 + (this.flyingSwords.length % 3) * 12,
      ttl: 15,
      atkTimer: 0.4,
      state: 'orbit',
      target: null,
      face: 0,
      dirX: 0,
      dirY: 1,
      travel: 0,
      chains: 0,
      legTravel: 0,
      legLength: 0,
      visited: new Set(),
      hitSet: new Set(),
    });
  }

  _updateFlyingSwords(dt, world, s) {
    const px = world.player.x;
    const py = world.player.y;
    const flyDamage = s.damage * world.mods.damageMult * 0.3;
    const searchR2 = s.flyRange * s.flyRange;

    for (const f of this.flyingSwords) {
      f.ttl -= dt;
      f.atkTimer -= dt;
      if (f.ttl <= 0) continue;

      if (f.state === 'orbit') {
        f.angle += dt * 2.4;
        const tx = px + Math.cos(f.angle) * f.orbitR;
        const ty = py + Math.sin(f.angle) * f.orbitR;
        f.x += (tx - f.x) * Math.min(1, dt * 10);
        f.y += (ty - f.y) * Math.min(1, dt * 10);
        f.face = f.angle + Math.PI / 2;
        if (f.atkTimer <= 0) {
          const target = nearestEnemy(world.enemies, px, py, searchR2);
          if (target) {
            f.state = 'strike';
            f.target = target;
            f.chains = 1;
            f.atkTimer = s.flyInterval;
            f.travel = 0;
            f.legTravel = 0;
            f.legLength = Math.max(48, Math.hypot(target.x - f.x, target.y - f.y));
            f.visited = new Set([target]);
            f.hitSet = new Set();
            const dx = target.x - f.x;
            const dy = target.y - f.y;
            const d = Math.hypot(dx, dy) || 1;
            f.dirX = dx / d;
            f.dirY = dy / d;
          } else {
            f.atkTimer = 0.15;
          }
        }
      } else if (f.state === 'strike') {
        // 觉醒·穿梭：锁定目标直飞，越过目标后立刻在敌群中锁定下一个目标来回穿梭，
        // 每一段飞行都贯穿沿途所有敌人（同一段内每个敌人只结算一次，换段重新计数）
        const target = f.target;
        if (target && !target.dead) {
          const dx = target.x - f.x;
          const dy = target.y - f.y;
          const distance = Math.hypot(dx, dy) || 1;
          f.face = Math.atan2(dy, dx);
          f.dirX = dx / distance;
          f.dirY = dy / distance;
          // 段长在锁定目标时一次性确定，这里不可回写，否则会在抵达目标前半程就结束本段
        }
        const step = 640 * dt;
        f.x += f.dirX * step;
        f.y += f.dirY * step;
        f.travel += step;
        f.legTravel += step;
        for (const e of world.enemies) {
          if (e.dead || f.hitSet.has(e)) continue;
          if (dist2(f.x, f.y, e.x, e.y) <= (e.radius + 8) ** 2) {
            f.hitSet.add(e);
            world.damageEnemy(e, flyDamage, SWORD_DAMAGE_META.flyingSword);
            this._onDamageHit(e, world, s, false, 'flyingSword');
            if (!e.dead) world.applyDot(e, 'bleed', 9, 2.5);
          }
        }
        // 本段飞完（越过目标约一个身位）：找下一个目标继续穿梭，否则回收
        if (f.legTravel >= f.legLength + 16) {
          let next = null;
          if (f.chains < (s.flyChain ?? 1)) {
            const rangeR2 = (s.flyChainRange ?? 240) ** 2;
            // 优先飞向本次穿梭尚未访问过的敌人，保证贯穿整条敌群
            let bestD = rangeR2;
            for (const e of world.enemies) {
              if (e.dead || f.visited.has(e)) continue;
              const d = dist2(f.x, f.y, e.x, e.y);
              if (d < bestD) { bestD = d; next = e; }
            }
            if (!next) {
              // 全部访问过：在敌人之间来回穿梭锯割；仅剩单目标（Boss）时原地反复切割
              next = this._nearestEnemyNear(world, f.x, f.y, rangeR2, f.target);
              if (!next && f.target && !f.target.dead && dist2(f.x, f.y, f.target.x, f.target.y) <= rangeR2) next = f.target;
            }
          }
          if (next) {
            f.chains++;
            f.target = next;
            f.visited.add(next);
            f.hitSet = new Set();
            f.legTravel = 0;
            f.legLength = Math.max(48, Math.hypot(next.x - f.x, next.y - f.y));
          } else {
            f.state = 'return';
            f.target = null;
          }
        }
        // 总航程或离玩家过远时强制回收
        if (f.travel > 1600 || dist2(f.x, f.y, px, py) > 460 * 460) {
          f.state = 'return';
          f.target = null;
        }
      } else {
        const tx = px + Math.cos(f.angle) * f.orbitR;
        const ty = py + Math.sin(f.angle) * f.orbitR;
        const dx = tx - f.x;
        const dy = ty - f.y;
        const distance = Math.hypot(dx, dy) || 1;
        f.face = Math.atan2(dy, dx);
        const step = 700 * dt;
        if (distance <= step) {
          f.x = tx;
          f.y = ty;
          f.state = 'orbit';
        } else {
          f.x += (dx / distance) * step;
          f.y += (dy / distance) * step;
        }
      }
    }
    this.flyingSwords = this.flyingSwords.filter((f) => f.ttl > 0);
  }

  draw(ctx, world, phase) {
    if (phase !== 'over') return;

    for (const r of this.rings) {
      const progress = 1 - r.ttl / r.maxTtl;
      const radius = r.r * (0.35 + 0.65 * progress);
      ctx.save();
      ctx.beginPath();
      ctx.arc(r.x, r.y, radius, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(190,240,255,${((1 - progress) * 0.85).toFixed(3)})`;
      ctx.lineWidth = 5;
      ctx.stroke();
      ctx.restore();
    }

    for (const p of world.projectiles) {
      if (!p.swordQi || p.dead) continue;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.angle);
      ctx.beginPath();
      ctx.moveTo(-22, 0);
      ctx.lineTo(0, -4.5);
      ctx.lineTo(14, 0);
      ctx.lineTo(0, 4.5);
      ctx.closePath();
      ctx.fillStyle = p.ringReturnUsed
        ? 'rgba(198,255,112,0.95)'
        : p.ringReturnCharged
          ? 'rgba(255,245,157,0.95)'
          : 'rgba(174,233,255,0.9)';
      ctx.fill();
      ctx.restore();
    }

    for (const f of this.flyingSwords) {
      const fade = Math.min(1, f.ttl / 1.5);
      ctx.save();
      ctx.translate(f.x, f.y);
      ctx.rotate(f.face);
      ctx.beginPath();
      ctx.moveTo(-11, 0);
      ctx.lineTo(0, -3.2);
      ctx.lineTo(13, 0);
      ctx.lineTo(0, 3.2);
      ctx.closePath();
      ctx.fillStyle = `rgba(255,214,120,${(0.95 * fade).toFixed(3)})`;
      ctx.fill();
      ctx.restore();
    }
  }
}

export const CARD = {
  id: 'sword', kind: 'weapon', name: '道剑', icon: '⚔️', maxLevel: 6,
  desc: 'Lv1 近战挥砍，Lv2 起御剑远程无限贯穿；Lv4 命中 3 次攻击后追加拔剑斩（空挥不充能）；Lv6 觉醒剑意：每命中 10 次凝一柄飞剑，飞剑在敌群间来回穿梭，贯穿沿途所有敌人。',
  levels: [
    { damage: 16, meleeRange: 125, interval: 1.15, arc: 120 },
    { damage: 20, projectile: true, projectileRange: 520, projectileSpeed: 500, maxHits: Infinity, interval: 1.08 },
    { damage: 26, projectile: true, projectileRange: 550, projectileSpeed: 560, maxHits: Infinity, interval: 1.00 },
    { damage: 32, projectile: true, projectileRange: 570, projectileSpeed: 580, maxHits: Infinity, interval: 0.94,
      drawSlash: true, ringRadius: 350, ringBleedDps: 10 },
    { damage: 40, projectile: true, projectileRange: 600, projectileSpeed: 620, maxHits: Infinity, interval: 0.87,
      drawSlash: true, ringRadius: 380, ringBleedDps: 11 },
    { damage: 48, projectile: true, projectileRange: 640, projectileSpeed: 660, maxHits: Infinity, interval: 0.80,
      drawSlash: true, ringRadius: 344, ringBleedDps: 12, swordIntent: true,
      flyMax: 10, flyInterval: 1.2, flyRange: 260, flyChain: 6, flyChainRange: 240 },
  ],
  create() { return new SwordWeapon(this); },
};
