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
    this.loopCooldown = 0;
    this.healTimer = 0;
    this.lastDropAt = -Infinity;
  }

  update(dt, world) {
    const s = this.stats;
    this.loopCooldown = Math.max(0, this.loopCooldown - dt);
    this._updateBursts(dt);
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
      life: FURNACE_DURATION,
      maxLife: FURNACE_DURATION,
      tickTimer: FURNACE_TICK,
      damage: s.damage * world.mods.damageMult,
      pullSpeed: 25,
      fuel: 0,
      opens: 0,
      maxOpens: s.enhancedFurnace ? 2 : 1,
      openCooldown: 0,
      eliteFuelAt: new Map(),
      dead: false,
    };
    this.furnaces.push(zone);
    while (this.furnaces.length > FURNACE_CAP) this.furnaces.shift();

    this._damageZone(zone, world, zone.damage * 4, true);
    this._addBurst(zone, 'ignite');
    this._tryOpen(zone, world, s);
  }

  _updateFurnaces(dt, world, s) {
    for (const zone of this.furnaces) {
      zone.life -= dt;
      zone.openCooldown = Math.max(0, zone.openCooldown - dt);
      if (zone.life <= 0) { zone.dead = true; continue; }

      for (const e of world.enemies) {
        if (e.dead || !circleTouchesPolygon(e.x, e.y, e.radius, zone.points)) continue;
        const dx = zone.center.x - e.x;
        const dy = zone.center.y - e.y;
        const distance = Math.hypot(dx, dy);
        if (distance > 1) {
          const step = Math.min(distance, zone.pullSpeed * dt);
          e.x += dx / distance * step;
          e.y += dy / distance * step;
        }
      }

      zone.tickTimer -= dt;
      if (zone.tickTimer <= 0) {
        zone.tickTimer += FURNACE_TICK;
        this._damageZone(zone, world, zone.damage * 1.25, true);
        this._tryOpen(zone, world, s);
      }
    }
    this.furnaces = this.furnaces.filter((zone) => !zone.dead);
  }

  _damageZone(zone, world, damage, grantsFuel) {
    for (const e of world.enemies) {
      if (e.dead || !circleTouchesPolygon(e.x, e.y, e.radius, zone.points)) continue;
      const wasAlive = !e.dead;
      world.damageEnemy(e, damage);
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

  _tryOpen(zone, world, s) {
    if (zone.fuel < FURNACE_FUEL || zone.opens >= zone.maxOpens || zone.openCooldown > 0) return;
    zone.fuel -= FURNACE_FUEL;
    zone.opens++;
    zone.openCooldown = 0.75;
    this._damageZone(zone, world, zone.damage * 6, false);
    zone.life = Math.min(FURNACE_MAX_REMAINING, zone.life + 2);
    zone.maxLife = Math.max(zone.maxLife, zone.life);
    this._addBurst(zone, 'open');

    if (s.nineTurn) {
      this.hotZones.push({
        points: zone.points.map((p) => ({ ...p })),
        center: { ...zone.center },
        life: 3,
        maxLife: 3,
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
          world.damageEnemy(e, zone.damage);
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
      ttl: kind === 'open' ? 0.5 : 0.35,
      maxTtl: kind === 'open' ? 0.5 : 0.35,
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
      return;
    }
    if (phase !== 'over') return;
    for (const burst of this.bursts) {
      const progress = 1 - burst.ttl / burst.maxTtl;
      ctx.globalAlpha = (1 - progress) * (burst.kind === 'open' ? 0.9 : 0.6);
      drawPolygon(ctx, burst.points);
      ctx.strokeStyle = burst.kind === 'open' ? '#fff59d' : '#ff7043';
      ctx.lineWidth = burst.kind === 'open' ? 7 : 4;
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(burst.x, burst.y, burst.radius * (0.35 + progress * 0.9), 0, Math.PI * 2);
      ctx.strokeStyle = burst.kind === 'open' ? '#ffffff' : '#ffca28';
      ctx.lineWidth = 5 * (1 - progress) + 1;
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
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
        world.damageEnemy(e, t.damage);
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
    { damage: 8, radius: 32, life: 3.0, dropInterval: 0.22 },
    { damage: 11, radius: 35, life: 3.4, dropInterval: 0.22, burn: true, burnDps: 12 },
    { damage: 15, radius: 38, life: 3.9, dropInterval: 0.18, burn: true, burnDps: 14 },
    { damage: 18, radius: 42, life: 4.2, dropInterval: 0.18, burn: true, burnDps: 14, furnace: true },
    { damage: 23, radius: 46, life: 4.6, dropInterval: 0.18, burn: true, burnDps: 14, furnace: true, enhancedFurnace: true },
    { damage: 29, radius: 50, life: 5.0, dropInterval: 0.18, burn: true, burnDps: 14, furnace: true, enhancedFurnace: true, nineTurn: true },
  ],
  create() { return new TrailWeapon(this); },
};
