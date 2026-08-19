import { WeaponBase } from './base.js';
import { dist2 } from '../utils.js';

const LOOP_MIN_LENGTH = 260;
const LOOP_MIN_AREA = 9000;
const LOOP_CLOSE_RADIUS = 55;
const LOOP_MIN_AGE = 1.2;
const LOOP_COOLDOWN = 1.5;
const FURNACE_DURATION = 4.5;
const FURNACE_TICK = 0.4;
const FURNACE_FUEL = 9;
const FURNACE_MAX_REMAINING = 8;
const PATH_POINT_CAP = 180;
const FURNACE_CAP = 6;
const HOT_ZONE_CAP = 8;
const EFFECT_CAP = 16;
const CUT_ZONE_CAP = 8;
const CUT_ZONE_LIFE = 2.2;
const CUT_ZONE_TICK = 0.35;
const CUT_ZONE_HALF_WIDTH = 24;

function polygonArea(points) {
  let sum = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return Math.abs(sum) * 0.5;
}

function polygonCenter(points) {
  let crossSum = 0;
  let xSum = 0;
  let ySum = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    const cross = a.x * b.y - b.x * a.y;
    crossSum += cross;
    xSum += (a.x + b.x) * cross;
    ySum += (a.y + b.y) * cross;
  }
  if (Math.abs(crossSum) < 0.001) {
    const total = points.reduce((acc, p) => ({ x: acc.x + p.x, y: acc.y + p.y }), { x: 0, y: 0 });
    return { x: total.x / points.length, y: total.y / points.length };
  }
  return { x: xSum / (3 * crossSum), y: ySum / (3 * crossSum) };
}

function pointInPolygon(x, y, points) {
  let inside = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    const a = points[i];
    const b = points[j];
    const crosses = ((a.y > y) !== (b.y > y))
      && x < ((b.x - a.x) * (y - a.y)) / (b.y - a.y || 0.00001) + a.x;
    if (crosses) inside = !inside;
  }
  return inside;
}

function pointSegmentDist2(x, y, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const length2 = dx * dx + dy * dy;
  if (length2 <= 0.0001) return dist2(x, y, a.x, a.y);
  const t = Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / length2));
  return dist2(x, y, a.x + dx * t, a.y + dy * t);
}

function segmentsIntersect(a, b, c, d) {
  const rx = b.x - a.x;
  const ry = b.y - a.y;
  const sx = d.x - c.x;
  const sy = d.y - c.y;
  const denominator = rx * sy - ry * sx;
  if (Math.abs(denominator) <= 0.0001) {
    return pointSegmentDist2(a.x, a.y, c, d) <= 0.25
      || pointSegmentDist2(b.x, b.y, c, d) <= 0.25
      || pointSegmentDist2(c.x, c.y, a, b) <= 0.25
      || pointSegmentDist2(d.x, d.y, a, b) <= 0.25;
  }
  const qpx = c.x - a.x;
  const qpy = c.y - a.y;
  const t = (qpx * sy - qpy * sx) / denominator;
  const u = (qpx * ry - qpy * rx) / denominator;
  return t >= 0 && t <= 1 && u >= 0 && u <= 1;
}

function segmentTouchesPolygon(a, b, points) {
  if (pointInPolygon(a.x, a.y, points) || pointInPolygon(b.x, b.y, points)) return true;
  for (let i = 0; i < points.length; i++) {
    if (segmentsIntersect(a, b, points[i], points[(i + 1) % points.length])) return true;
  }
  return false;
}

function circleTouchesPolygon(x, y, radius, points) {
  if (pointInPolygon(x, y, points)) return true;
  const radius2 = radius * radius;
  for (let i = 0; i < points.length; i++) {
    if (pointSegmentDist2(x, y, points[i], points[(i + 1) % points.length]) <= radius2) return true;
  }
  return false;
}

function pathLength(points) {
  let length = 0;
  for (let i = 1; i < points.length; i++) {
    length += Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y);
  }
  if (points.length > 1) {
    length += Math.hypot(points[0].x - points.at(-1).x, points[0].y - points.at(-1).y);
  }
  return length;
}

function drawPolygon(ctx, points) {
  if (points.length < 3) return;
  ctx.beginPath();
  ctx.moveTo(points[0].x, points[0].y);
  for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
  ctx.closePath();
}

// ---------- 丹火：移动铺火，闭环后画地为炉 ----------
export class TrailWeapon extends WeaponBase {
  constructor(card) {
    super(card);
    this.pathPoints = [];
    this.furnaces = [];
    this.hotZones = [];
    this.bursts = [];
    this.cutZones = [];
    this.loopCooldown = 0;
    this.healTimer = 0;
    this.lastDropAt = -Infinity;
  }

  update(dt, world) {
    const s = this.stats;
    this.loopCooldown = Math.max(0, this.loopCooldown - dt);
    this._updateBursts(dt);
    this._updateCutZones(dt, world);
    this._updateFurnaces(dt, world, s);
    this._updateHotZones(dt, world, s);

    this.timer = Math.max(0, this.timer - dt);
    if (this.timer > 0 || !world.player.moving) return;
    this.timer = s.dropInterval;

    // 长时间停步后从新路径开始，避免两段不连续轨迹被误判为闭环。
    if (world.elapsed - this.lastDropAt > 0.7) this.pathPoints.length = 0;
    this.lastDropAt = world.elapsed;

    const trail = {
      x: world.player.x,
      y: world.player.y,
      radius: s.radius,
      damage: s.damage * world.mods.damageMult,
      life: s.life,
      maxLife: s.life,
      tickTimer: 0,
      tick: 0.4,
      burnDps: s.burn ? s.burnDps : 0,
      damageOptions: {
        sourceWeaponId: 'trail',
        sourceAction: 'trail',
        sourceTags: ['fire', 'field'],
      },
      dead: false,
    };
    world.trails.push(trail);
    while (world.trails.length > 80) world.trails.shift();

    this.pathPoints.push({ x: trail.x, y: trail.y, at: world.elapsed, trail });
    if (this.pathPoints.length > PATH_POINT_CAP) this.pathPoints.shift();

    if (s.furnace && this.loopCooldown <= 0) this._tryCreateFurnace(world, s);
  }

  _tryCreateFurnace(world, s) {
    const current = this.pathPoints.at(-1);
    if (!current) return;

    // 从最近的合格旧点开始找，优先生成玩家刚刚完成的闭环。
    for (let i = this.pathPoints.length - 2; i >= 0; i--) {
      const old = this.pathPoints[i];
      if (current.at - old.at < LOOP_MIN_AGE) continue;
      if (dist2(current.x, current.y, old.x, old.y) > LOOP_CLOSE_RADIUS ** 2) continue;

      const loop = this.pathPoints.slice(i).map((p) => ({ x: p.x, y: p.y }));
      if (loop.length < 4 || pathLength(loop) < LOOP_MIN_LENGTH) continue;
      const area = polygonArea(loop);
      if (area < LOOP_MIN_AREA) continue;

      const consumed = this.pathPoints.slice(i);
      for (const p of consumed) p.trail.dead = true;
      this.pathPoints.length = 0;
      this.loopCooldown = LOOP_COOLDOWN;
      this._createFurnace(loop, area, world, s);
      return;
    }
  }

  _createFurnace(points, area, world, s) {
    const zone = {
      points,
      center: polygonCenter(points),
      area,
      life: s.furnaceLife ?? FURNACE_DURATION,
      maxLife: s.furnaceLife ?? FURNACE_DURATION,
      tickTimer: FURNACE_TICK,
      damage: s.damage * world.mods.damageMult,
      pullSpeed: 25,
      fuel: 0,
      opens: 0,
      maxOpens: s.enhancedFurnace ? 2 : 1,
      openCooldown: 0,
      coreTickTimer: 0,
      eliteFuelAt: new Map(),
      dead: false,
    };
    this.furnaces.push(zone);
    while (this.furnaces.length > FURNACE_CAP) this.furnaces.shift();

    this._damageZone(zone, world, zone.damage * 4, true, 'furnace-ignite');
    this._addBurst(zone, 'ignite');
    this._tryOpen(zone, world, s);
  }

  _updateFurnaces(dt, world, s) {
    for (const zone of this.furnaces) {
      zone.life -= dt;
      zone.openCooldown = Math.max(0, zone.openCooldown - dt);
      if (zone.life <= 0) { zone.dead = true; continue; }

      const cloak = world.hasSynergy('cloak-trail-core') ? world.getWeapon('cloak') : null;
      zone.coreVisual = cloak ? {
        x: world.player.x,
        y: world.player.y,
        radius: cloak.stats.radius,
      } : null;
      let hasCoreTarget = false;
      for (const e of world.enemies) {
        if (e.dead || !circleTouchesPolygon(e.x, e.y, e.radius, zone.points)) continue;
        const inCore = cloak
          && dist2(world.player.x, world.player.y, e.x, e.y) <= (cloak.stats.radius + e.radius) ** 2;
        if (inCore) hasCoreTarget = true;
        const dx = zone.center.x - e.x;
        const dy = zone.center.y - e.y;
        const distance = Math.hypot(dx, dy);
        if (distance > 1) {
          const pullSpeed = zone.pullSpeed + (inCore ? 65 : 0);
          const step = Math.min(distance, pullSpeed * dt);
          e.x += dx / distance * step;
          e.y += dy / distance * step;
        }
      }

      if (cloak) {
        zone.coreTickTimer -= dt;
        if (hasCoreTarget && zone.coreTickTimer <= 0) {
          zone.coreTickTimer = 0.8;
          let hits = 0;
          for (const e of world.enemies) {
            if (e.dead || !circleTouchesPolygon(e.x, e.y, e.radius, zone.points)) continue;
            if (dist2(world.player.x, world.player.y, e.x, e.y) > (cloak.stats.radius + e.radius) ** 2) continue;
            world.damageEnemy(e, zone.damage * 1.5, {
              sourceWeaponId: 'trail',
              sourceAction: 'inner-outer-core',
              sourceTags: ['fire', 'field', 'synergy'],
              synergyId: 'cloak-trail-core',
              noSynergy: true,
            });
            hits++;
          }
          if (hits > 0) {
            this._addBurst(zone, 'core');
            world.recordSynergyTrigger('cloak-trail-core', hits);
          }
        }
      } else {
        zone.coreTickTimer = 0;
      }

      zone.tickTimer -= dt;
      if (zone.tickTimer <= 0) {
        zone.tickTimer += FURNACE_TICK;
        this._damageZone(zone, world, zone.damage * 1.25, true, 'furnace-tick');
        this._tryOpen(zone, world, s);
      }
    }
    this.furnaces = this.furnaces.filter((zone) => !zone.dead);
  }

  _damageZone(zone, world, damage, grantsFuel, sourceAction = 'furnace') {
    for (const e of world.enemies) {
      if (e.dead || !circleTouchesPolygon(e.x, e.y, e.radius, zone.points)) continue;
      const wasAlive = !e.dead;
      world.damageEnemy(e, damage, {
        sourceWeaponId: 'trail',
        sourceAction,
        sourceTags: ['fire', 'field'],
      });
      if (!grantsFuel) continue;

      if (wasAlive && e.dead) zone.fuel++;
      if (!e.dead && (e.rank === 'elite' || e.rank === 'boss')) {
        const nextFuelAt = zone.eliteFuelAt.get(e) ?? -Infinity;
        if (world.elapsed >= nextFuelAt) {
          zone.fuel++;
          zone.eliteFuelAt.set(e, world.elapsed + 1);
        }
      }
    }
  }

  findFurnaceAt(x, y, radius = 0) {
    let best = null;
    let bestDistance = Infinity;
    for (const zone of this.furnaces) {
      if (zone.dead || zone.opens >= zone.maxOpens) continue;
      if (!circleTouchesPolygon(x, y, radius, zone.points)) continue;
      const distance = dist2(x, y, zone.center.x, zone.center.y);
      if (distance < bestDistance) { bestDistance = distance; best = zone; }
    }
    return best;
  }

  cutFurnacesAlongSegment(x1, y1, x2, y2, damage, world, visited = new Set()) {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const distance = Math.hypot(dx, dy);
    if (distance <= 0.001) return 0;

    const directionX = dx / distance;
    const directionY = dy / distance;
    const segmentStart = { x: x1, y: y1 };
    const segmentEnd = { x: x2, y: y2 };
    let cuts = 0;
    for (const zone of this.furnaces) {
      if (zone.dead || visited.has(zone)) continue;
      if (!segmentTouchesPolygon(segmentStart, segmentEnd, zone.points)) continue;
      visited.add(zone);

      let halfLength = 48;
      for (const point of zone.points) {
        halfLength = Math.max(halfLength, Math.hypot(point.x - zone.center.x, point.y - zone.center.y) + 24);
      }
      this.cutZones.push({
        x1: zone.center.x - directionX * halfLength,
        y1: zone.center.y - directionY * halfLength,
        x2: zone.center.x + directionX * halfLength,
        y2: zone.center.y + directionY * halfLength,
        width: CUT_ZONE_HALF_WIDTH,
        damage,
        life: CUT_ZONE_LIFE,
        maxLife: CUT_ZONE_LIFE,
        tickTimer: 0,
        dead: false,
      });
      while (this.cutZones.length > CUT_ZONE_CAP) this.cutZones.shift();
      world.recordSynergyTrigger?.('sword-trail-cut', 1);
      world.effects.push({
        type: 'synergyBurst',
        x: zone.center.x,
        y: zone.center.y,
        radius: Math.min(110, halfLength * 0.7),
        color: '#ff6d00',
        accent: '#fff176',
        ttl: 0.3,
        maxTtl: 0.3,
      });
      cuts++;
    }
    return cuts;
  }

  _updateCutZones(dt, world) {
    if (!world.hasSynergy?.('sword-trail-cut')) {
      this.cutZones = [];
      return;
    }
    for (const zone of this.cutZones) {
      zone.life -= dt;
      if (zone.life <= 0) { zone.dead = true; continue; }
      zone.tickTimer -= dt;
      if (zone.tickTimer > 0) continue;
      zone.tickTimer += CUT_ZONE_TICK;
      for (const enemy of world.enemies) {
        if (enemy.dead) continue;
        const radius = zone.width + enemy.radius;
        if (pointSegmentDist2(enemy.x, enemy.y, { x: zone.x1, y: zone.y1 }, { x: zone.x2, y: zone.y2 }) > radius ** 2) continue;
        world.damageEnemy(enemy, zone.damage, {
          sourceWeaponId: 'sword',
          sourceAction: 'furnace-cut',
          sourceTags: ['sword', 'fire', 'field', 'synergy'],
          synergyId: 'sword-trail-cut',
          noSynergy: true,
          noSummon: true,
        });
      }
    }
    this.cutZones = this.cutZones.filter((zone) => !zone.dead);
  }

  chargeFurnaceAt(x, y, amount, world) {
    const best = this.findFurnaceAt(x, y);
    if (!best) return null;
    best.fuel = Math.min(FURNACE_FUEL * 2, best.fuel + amount);
    this._tryOpen(best, world, this.stats);
    return best;
  }

  _tryOpen(zone, world, s) {
    if (zone.fuel < FURNACE_FUEL || zone.opens >= zone.maxOpens || zone.openCooldown > 0) return;
    zone.fuel -= FURNACE_FUEL;
    zone.opens++;
    zone.openCooldown = 0.75;
    this._damageZone(zone, world, zone.damage * 6, false, 'furnace-open');
    zone.life = Math.min(FURNACE_MAX_REMAINING, zone.life + 2);
    zone.maxLife = Math.max(zone.maxLife, zone.life);
    this._addBurst(zone, 'open');

    if (s.nineTurn) {
      this.hotZones.push({
        points: zone.points.map((p) => ({ ...p })),
        center: { ...zone.center },
        life: s.hotZoneLife ?? 3,
        maxLife: s.hotZoneLife ?? 3,
        tickTimer: 0,
        damage: zone.damage * 1.25 * 1.5,
        dead: false,
      });
      while (this.hotZones.length > HOT_ZONE_CAP) this.hotZones.shift();
    }
  }

  _updateHotZones(dt, world, s) {
    let playerInHotZone = false;
    for (const zone of this.hotZones) {
      zone.life -= dt;
      if (zone.life <= 0) { zone.dead = true; continue; }
      if (circleTouchesPolygon(world.player.x, world.player.y, world.player.radius, zone.points)) {
        playerInHotZone = true;
      }
      zone.tickTimer -= dt;
      if (zone.tickTimer <= 0) {
        zone.tickTimer += FURNACE_TICK;
        for (const e of world.enemies) {
          if (e.dead || !circleTouchesPolygon(e.x, e.y, e.radius, zone.points)) continue;
          world.damageEnemy(e, zone.damage, {
            sourceWeaponId: 'trail',
            sourceAction: 'hot-zone',
            sourceTags: ['fire', 'field'],
          });
        }
      }
    }
    this.hotZones = this.hotZones.filter((zone) => !zone.dead);

    if (!s.nineTurn || !playerInHotZone) {
      this.healTimer = 0;
      return;
    }
    world.setPlayerMoveSpeedBonus(this, 1.12, 0.12);
    this.healTimer -= dt;
    if (this.healTimer <= 0) {
      world.healPlayer(1);
      this.healTimer = 0.5;
    }
  }

  _addBurst(zone, kind) {
    const radius = Math.sqrt(zone.area / Math.PI);
    this.bursts.push({
      x: zone.center.x,
      y: zone.center.y,
      radius,
      points: zone.points.map((p) => ({ ...p })),
      kind,
      ttl: kind === 'open' ? 0.5 : kind === 'core' ? 0.42 : 0.35,
      maxTtl: kind === 'open' ? 0.5 : kind === 'core' ? 0.42 : 0.35,
    });
    while (this.bursts.length > EFFECT_CAP) this.bursts.shift();
  }

  _updateBursts(dt) {
    for (const burst of this.bursts) burst.ttl -= dt;
    this.bursts = this.bursts.filter((burst) => burst.ttl > 0);
  }

  draw(ctx, world, phase) {
    if (phase === 'under') {
      for (const zone of this.furnaces) this._drawFurnace(ctx, zone);
      for (const zone of this.hotZones) this._drawHotZone(ctx, zone);
      for (const zone of this.cutZones) this._drawCutZone(ctx, zone);
      return;
    }
    if (phase !== 'over') return;
    for (const burst of this.bursts) {
      const progress = 1 - burst.ttl / burst.maxTtl;
      ctx.globalAlpha = (1 - progress) * (burst.kind === 'open' ? 0.9 : 0.6);
      drawPolygon(ctx, burst.points);
      ctx.strokeStyle = burst.kind === 'open' ? '#fff59d' : burst.kind === 'core' ? '#ff1744' : '#ff7043';
      ctx.lineWidth = burst.kind === 'open' ? 7 : burst.kind === 'core' ? 6 : 4;
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(burst.x, burst.y, burst.radius * (0.35 + progress * 0.9), 0, Math.PI * 2);
      ctx.strokeStyle = burst.kind === 'open' ? '#ffffff' : burst.kind === 'core' ? '#ffd54f' : '#ffca28';
      ctx.lineWidth = 5 * (1 - progress) + 1;
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  _drawCutZone(ctx, zone) {
    const lifeRatio = Math.max(0, zone.life / zone.maxLife);
    ctx.save();
    ctx.globalAlpha = 0.35 + lifeRatio * 0.45;
    ctx.strokeStyle = '#ff6d00';
    ctx.lineWidth = zone.width * 2;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(zone.x1, zone.y1);
    ctx.lineTo(zone.x2, zone.y2);
    ctx.stroke();
    ctx.globalAlpha = 0.65 + lifeRatio * 0.35;
    ctx.strokeStyle = '#fff176';
    ctx.lineWidth = 5;
    ctx.stroke();
    ctx.restore();
  }

  _drawFurnace(ctx, zone) {
    const lifeRatio = Math.max(0, zone.life / zone.maxLife);
    drawPolygon(ctx, zone.points);
    ctx.globalAlpha = 0.13 + lifeRatio * 0.09;
    ctx.fillStyle = '#e65100';
    ctx.fill();
    ctx.globalAlpha = 0.55 + lifeRatio * 0.25;
    ctx.strokeStyle = zone.opens > 0 ? '#ffd54f' : '#ff8f00';
    ctx.lineWidth = zone.opens > 0 ? 5 : 3;
    ctx.stroke();
    if (zone.coreVisual) {
      const pulse = 0.5 + Math.sin(zone.life * 8) * 0.5;
      ctx.save();
      drawPolygon(ctx, zone.points);
      ctx.clip();
      ctx.globalAlpha = 0.12 + pulse * 0.08;
      ctx.fillStyle = '#ff1744';
      ctx.beginPath();
      ctx.arc(zone.coreVisual.x, zone.coreVisual.y, zone.coreVisual.radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 0.55;
      ctx.strokeStyle = '#ffd54f';
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  _drawHotZone(ctx, zone) {
    const lifeRatio = Math.max(0, zone.life / zone.maxLife);
    drawPolygon(ctx, zone.points);
    ctx.globalAlpha = 0.18 + lifeRatio * 0.13;
    ctx.fillStyle = '#ffeb3b';
    ctx.fill();
    ctx.globalAlpha = 0.75;
    ctx.strokeStyle = '#fff9c4';
    ctx.lineWidth = 6;
    ctx.stroke();
    ctx.globalAlpha = 1;
  }
}

// 丹火轨迹段的更新与绘制（由 game 统一驱动）
export function updateTrail(t, world, dt) {
  if (t.dead) return;
  t.life -= dt;
  if (t.life <= 0) { t.dead = true; return; }
  t.tickTimer -= dt;
  if (t.tickTimer <= 0) {
    t.tickTimer += t.tick;
    for (const e of world.enemies) {
      if (e.dead) continue;
      if (dist2(t.x, t.y, e.x, e.y) <= (t.radius + e.radius) ** 2) {
        if (t.burnDps) world.applyDot(e, 'blaze', t.burnDps, 2);
        world.damageEnemy(e, t.damage, t.damageOptions);
      }
    }
  }
}

export function drawTrail(ctx, t) {
  const k = Math.max(0, t.life / t.maxLife);
  ctx.globalAlpha = 0.30 * k + 0.08;
  ctx.beginPath();
  ctx.arc(t.x, t.y, t.radius, 0, Math.PI * 2);
  ctx.fillStyle = '#ff9800';
  ctx.fill();
  ctx.globalAlpha = 0.5 * k;
  ctx.beginPath();
  ctx.arc(t.x, t.y, t.radius * 0.55, 0, Math.PI * 2);
  ctx.fillStyle = '#ffd54f';
  ctx.fill();
  ctx.globalAlpha = 1;
}

export const CARD = {
  id: 'trail', kind: 'weapon', name: '丹火', icon: '🔥', maxLevel: 6,
  desc: '移动留下丹火轨迹；四级起闭环成炉，积蓄炉火开炉爆发，满级生成九转高温火域。',
  levels: [
    { damage: 7, radius: 40, life: 3.5, dropInterval: 0.22 },
    { damage: 10, radius: 44, life: 4.5, dropInterval: 0.22, burn: true, burnDps: 12 },
    { damage: 14, radius: 48, life: 5.5, dropInterval: 0.18, burn: true, burnDps: 14 },
    { damage: 16, radius: 52, life: 7.0, dropInterval: 0.18, burn: true, burnDps: 14, furnace: true, furnaceLife: 6 },
    { damage: 21, radius: 57, life: 8.5, dropInterval: 0.18, burn: true, burnDps: 14, furnace: true, enhancedFurnace: true, furnaceLife: 7.5 },
    { damage: 28, radius: 62, life: 10.0, dropInterval: 0.18, burn: true, burnDps: 14, furnace: true, enhancedFurnace: true, nineTurn: true, furnaceLife: 9, hotZoneLife: 5 },
  ],
  create() { return new TrailWeapon(this); },
};
