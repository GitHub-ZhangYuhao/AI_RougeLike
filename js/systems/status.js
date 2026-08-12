// ================= 状态系统：DoT / 减速 / 冰冻 =================
// 四种独立 DoT（设计上互相独立，各武器挂各的）：
//   burn   灼烧（炽热披风）
//   blaze  烈焰（丹火）
//   bleed  流血（道剑飞剑）
//   poison 尸毒（死灵法杖仆从）
// 规则：同类 debuff 不叠加，只刷新持续时间；dps 取较高者
export const DOT_TYPES = ['burn', 'blaze', 'bleed', 'poison'];

// 挂 debuff（由 world.applyDot 转发）
export function applyDot(e, type, dps, duration) {
  if (!e.dots) e.dots = {};
  const cur = e.dots[type];
  if (cur) {
    cur.dps = Math.max(cur.dps, dps);
    cur.timer = Math.max(cur.timer, duration);
  } else {
    e.dots[type] = { dps, timer: duration };
  }
}

export function hasDot(e, type) {
  return !!(e.dots && e.dots[type] && e.dots[type].timer > 0);
}

// factor = 减速比例（0.25 = 减速 25%），取最强减速
export function applySlow(e, factor, duration) {
  e.slowFactor = Math.max(e.slowFactor || 0, factor);
  e.slowTimer = Math.max(e.slowTimer || 0, duration);
}

export function applyFreeze(e, duration) {
  e.frozenTimer = Math.max(e.frozenTimer || 0, duration);
}

// 每帧推进状态计时器，返回本帧 DoT 应结算的伤害（由 game 统一扣血，保证击杀归属）
export function tickStatus(e, dt) {
  let dotDamage = 0;
  if (e.dots) {
    for (const type of DOT_TYPES) {
      const d = e.dots[type];
      if (!d) continue;
      d.timer -= dt;
      if (d.timer <= 0) { delete e.dots[type]; continue; }
      dotDamage += d.dps * dt;
    }
  }
  if (e.slowTimer > 0) e.slowTimer -= dt;
  if (e.frozenTimer > 0) e.frozenTimer -= dt;
  return dotDamage;
}

// 移动速度乘数（冰冻=0；减速=1-factor）
export function speedMultOf(e) {
  if (e.frozenTimer > 0) return 0;
  if (e.slowTimer > 0) return 1 - (e.slowFactor || 0);
  return 1;
}

// 状态指示物绘制：冰冻/减速描边 + 头顶 debuff 小圆点（橙=灼烧 红=流血 绿=尸毒）
export function drawStatus(ctx, e) {
  if (e.frozenTimer > 0) {
    ctx.beginPath();
    ctx.arc(e.x, e.y, e.radius + 3, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(129,212,250,0.9)';
    ctx.lineWidth = 2;
    ctx.stroke();
  } else if (e.slowTimer > 0) {
    ctx.beginPath();
    ctx.arc(e.x, e.y, e.radius + 3, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(129,212,250,0.4)';
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }
  if (!e.dots) return;
  const marks = [];
  if (e.dots.burn) marks.push('#ff9800');
  if (e.dots.blaze) marks.push('#ff5722');
  if (e.dots.bleed) marks.push('#e53935');
  if (e.dots.poison) marks.push('#9ccc65');
  for (let i = 0; i < marks.length; i++) {
    ctx.beginPath();
    ctx.arc(e.x - (marks.length - 1) * 4 + i * 8, e.y - e.radius - 6, 2.5, 0, Math.PI * 2);
    ctx.fillStyle = marks[i];
    ctx.fill();
  }
}