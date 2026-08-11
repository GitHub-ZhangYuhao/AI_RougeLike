// 无头冒烟测试：无需浏览器，验证 Step 2 卡牌系统 + Step 3 武器升级与核心 game loop
// 运行：node tools/headless-smoke.mjs
const rafQueue = [];
globalThis.requestAnimationFrame = (cb) => { rafQueue.push(cb); return rafQueue.length; };

const listeners = {};
const windowStub = {
  innerWidth: 1280,
  innerHeight: 720,
  devicePixelRatio: 1,
  addEventListener: (type, fn) => { (listeners[type] ||= []).push(fn); },
};
globalThis.window = windowStub;

const CTX_METHODS = new Set([
  'fillRect', 'strokeRect', 'clearRect', 'beginPath', 'closePath', 'arc', 'ellipse',
  'fill', 'stroke', 'moveTo', 'lineTo', 'arcTo', 'save', 'restore', 'translate',
  'scale', 'rotate', 'setTransform', 'resetTransform', 'clip', 'fillText', 'strokeText',
]);
const ctxStore = {};
const ctxStub = new Proxy(ctxStore, {
  get(t, prop) {
    if (prop === 'canvas') return canvasStub;
    if (prop === 'measureText') return (text) => ({ width: String(text).length * 12 });
    if (CTX_METHODS.has(prop)) return () => undefined;
    return t[prop];
  },
  set(t, prop, v) { t[prop] = v; return true; },
});

// canvas 必须支持 addEventListener（input.js 在上面挂鼠标事件）与 getBoundingClientRect
const canvasListeners = {};
const canvasStub = {
  width: 0, height: 0, style: {},
  getContext: () => ctxStub,
  addEventListener: (type, fn) => { (canvasListeners[type] ||= []).push(fn); },
  getBoundingClientRect: () => ({ left: 0, top: 0 }),
};
globalThis.document = { getElementById: (id) => (id === 'game' ? canvasStub : null) };

await import('../js/main.js');
const { CONFIG } = await import('../js/config.js');
const { computeMods, generateOffers, WEAPON_CARDS, ATTR_CARDS, CARD_BY_ID } = await import('../js/cards.js');
const { getCardRects } = await import('../js/ui-cards.js');

const game = globalThis.__game;
if (!game) throw new Error('游戏未初始化');

// ---------- 事件 / 帧驱动工具 ----------
const DIGITS = ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5', 'Digit6'];

function key(type, code) {
  const ev = { code, preventDefault() {} };
  for (const fn of listeners[type] || []) fn(ev);
}

function mouseEvent(type, x, y) {
  const ev = { clientX: x, clientY: y };
  for (const fn of canvasListeners[type] || []) fn(ev);
}

const STEP_MS = 1000 / 60;
let t = 0;
function pump(frames) {
  for (let i = 0; i < frames; i++) {
    t += STEP_MS;
    const cbs = rafQueue.splice(0);
    for (const cb of cbs) cb(t);
  }
}

// 推进 frames 帧；遇到开局/升级选卡界面时自动按键选一张（prefer 可指定偏好）
function pumpWithChoices(frames, prefer) {
  for (let i = 0; i < frames; i++) {
    if (game.state === 'opening' || game.state === 'choice') {
      const offers = game.currentOffers || [];
      if (offers.length > 0) {
        let idx = 0;
        if (prefer) {
          const found = offers.findIndex(prefer);
          if (found >= 0) idx = found;
        }
        if (idx >= offers.length) idx = 0;
        key('keydown', DIGITS[idx]);
        key('keyup', DIGITS[idx]);
      }
    }
    pump(1);
  }
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

// 预热 1 帧：main.js 的第一帧只记录时间戳，不推进逻辑
pump(1);

// ========== [0] 武器卡结构：maxLevel===6 && levels.length===6 ==========
for (const card of WEAPON_CARDS) {
  assert(card.maxLevel === 6, '[0] ' + card.id + ' maxLevel 应为 6，实际 ' + card.maxLevel);
  assert(card.levels.length === 6, '[0] ' + card.id + ' levels 应有 6 条，实际 ' + card.levels.length);
  for (let lv = 0; lv < 5; lv++) {
    const a = Object.keys(card.levels[lv]);
    const b = new Set(Object.keys(card.levels[lv + 1]));
    const missing = a.filter((k) => !b.has(k));
    assert(missing.length === 0, '[0] ' + card.id + ' L' + (lv + 1) + '->L' + (lv + 2) + ' 丢失字段: ' + missing.join(','));
  }
}
console.log('[0] 武器卡结构 OK（6 武器 × 6 级，flag 逐级继承）');

// ========== [1] 开局：三张新武器卡，三选一 ==========
assert(game.state === 'opening', '[1] 初始状态应为 opening，实际 ' + game.state);
assert(game.currentOffers.length === WEAPON_CARDS.length, '[1] 开局应展示全部武器卡（' + WEAPON_CARDS.length + ' 张）');
for (const o of game.currentOffers) {
  assert(o.card.kind === 'weapon' && o.type === 'new', '[1] 开局卡牌应全部是新武器卡');
}
pumpWithChoices(3, (o) => o.card.id !== 'trail'); // 站桩测试避开丹火（需要移动）
assert(game.state === 'playing', '[1] 选卡后应进入 playing，实际 ' + game.state);
assert(game.weapons.length === 1, '[1] 选卡后应持有 1 把武器');
console.log('[1] 开局选卡 OK：' + game.weapons[0].card.name);

// ========== [2] 移动 ==========
const startX = game.player.x;
key('keydown', 'KeyD');
pump(60);
key('keyup', 'KeyD');
const moved = game.player.x - startX;
console.log('[2] 按住 D 一秒：x += ' + moved.toFixed(1) + 'px');
assert(moved > 100, '[2] 玩家移动异常');
// 作弊：站桩 60 秒不被打死
game.player.maxHp = 100000;
game.player.hp = 100000;

// ========== [3] 站桩 60 秒：击杀 / 升级选卡 / 武器槽上限 ==========
pumpWithChoices(60 * 60);
console.log('[3] 60 秒后：elapsed=' + game.elapsed.toFixed(1) + 's 击杀=' + game.kills
  + ' 等级=' + game.level + ' 武器=' + game.weapons.length);
assert(game.kills > 0, '[3] 没有产生击杀');
assert(game.level >= 2, '[3] 玩家应该至少升到 2 级');
assert(game.state === 'playing', '[3] 应处于战斗状态，实际 ' + game.state);
assert(game.weapons.length <= CONFIG.cards.maxWeaponSlots, '[3] 武器数量超过槽位上限');

// ========== [4] 强制升级：鼠标点击选卡 ==========
game.pendingChoices = 0;
game.xp = 0;
// 抵消经验倍率影响，保证恰好升 1 级（只触发一轮选卡）
game.gainXp(game.xpToNext() / game.mods.xpMult + 0.001);
pump(3);
assert(game.state === 'choice', '[4] 升级后应进入选卡界面，实际 ' + game.state);
{
  const offers = game.currentOffers;
  assert(offers.length > 0, '[4] 选卡选项为空');
  const rects = getCardRects(1280, 720, offers.length);
  const r = rects[0];
  const offer = offers[0];
  const owned = offer.card.kind === 'weapon'
    ? game.weapons.find((w) => w.card.id === offer.card.id)
    : null;
  const beforeLevel = owned ? owned.level : 0;
  const beforeCount = game.weapons.length;
  const beforeStacks = game.attrStacks[offer.card.id] || 0;

  mouseEvent('mousemove', r.x + r.w / 2, r.y + r.h / 2);
  mouseEvent('mousedown', r.x + r.w / 2, r.y + r.h / 2);
  pump(3);
  assert(game.state === 'playing', '[4] 鼠标选卡后应回到 playing，实际 ' + game.state);

  if (offer.type === 'new') {
    assert(game.weapons.length === beforeCount + 1, '[4] 新武器未入槽');
  } else if (offer.type === 'upgrade') {
    const w = game.weapons.find((x) => x.card.id === offer.card.id);
    assert(w && w.level === beforeLevel + 1, '[4] 武器等级未提升');
  } else {
    assert((game.attrStacks[offer.card.id] || 0) === beforeStacks + 1, '[4] 属性层数未增加');
  }
  console.log('[4] 鼠标选卡 OK：' + offer.card.name + '（' + offer.type + '）');
}

// ========== [5] computeMods 数值 ==========
{
  const m = computeMods({ damage: 2, projectile: 1, xp: 3, area: 2, moveSpeed: 1, attackSpeed: 2, cooldown: 2 });
  const expect = [
    ['damageMult', 1.3],
    ['projectileBonus', 1],
    ['xpMult', 1.75],
    ['areaMult', 1.2],
    ['moveSpeedMult', 1.08],
    ['attackSpeedMult', 1.2],
    ['cooldownMult', 0.84],
  ];
  for (const [k, v] of expect) {
    assert(Math.abs(m[k] - v) < 1e-6, '[5] ' + k + ' 数值错误：' + m[k] + '，期望 ' + v);
  }
  console.log('[5] computeMods 数值 OK');
}

// ========== [6] 「弹道数量」属性作用于弹道武器 ==========
{
  const talisman = CARD_BY_ID.get('talisman').create();
  const projectiles = [];
  const fakeWorld = {
    player: { x: 0, y: 0, facing: 0, moving: false },
    enemies: [{ x: 120, y: 0, radius: 13, dead: false, hp: 100 }],
    projectiles,
    trails: [],
    summons: [],
    effects: [],
    mods: computeMods({ projectile: 2 }), // +2 弹道 → 一次应射 3 发
    elapsed: 0,
    damageEnemy: () => {},
  };
  talisman.update(1 / 60, fakeWorld);
  assert(projectiles.length === 3, '[6] 雷符咒应射出 3 发弹道，实际 ' + projectiles.length);
  console.log('[6] 弹道数量加成 OK');
}

// ========== [7] generateOffers 卡池规则 ==========
{
  // 武器槽已满 → 不应再出现新武器卡
  const fullSlots = {
    weapons: WEAPON_CARDS.slice(0, CONFIG.cards.maxWeaponSlots).map((c) => ({ card: c, level: 1 })),
    attrStacks: {},
  };
  const offersA = generateOffers(fullSlots);
  assert(offersA.length > 0, '[7] 槽位满时仍应有候选（升级/属性）');
  assert(!offersA.some((o) => o.type === 'new'), '[7] 槽位满时不应出现新武器卡');

  // 武器全部满级 + 属性全部叠满 → 卡池为空
  const maxed = {
    weapons: WEAPON_CARDS.slice(0, CONFIG.cards.maxWeaponSlots).map((c) => ({ card: c, level: c.maxLevel })),
    attrStacks: {},
  };
  for (const c of ATTR_CARDS) maxed.attrStacks[c.id] = CONFIG.cards.attrMaxStack;
  const offersB = generateOffers(maxed);
  assert(offersB.length === 0, '[7] 全收集后卡池应为空，实际 ' + offersB.length);
  console.log('[7] generateOffers 规则 OK');
}

// ========== [8] 死亡与 R 重开 ==========
game.player.hp = 1;
game.player.iFrames = 0;
if (game.enemies.length === 0) pump(120);
assert(game.enemies.length > 0, '[8] 没有敌人，无法验证死亡');
game.player.x = game.enemies[0].x;
game.player.y = game.enemies[0].y;
pump(120);
assert(game.state === 'dead', '[8] 玩家应该已死亡，实际 ' + game.state);

key('keydown', 'KeyR');
key('keyup', 'KeyR');
pump(3);
assert(game.state === 'opening', '[8] 重开应回到开局选卡，实际 ' + game.state);
assert(game.weapons.length === 0, '[8] 重开后武器应清空');
assert(game.level === 1, '[8] 重开后等级应重置为 1');
assert(game.kills === 0, '[8] 重开后击杀数应清零');

pumpWithChoices(3);
assert(game.state === 'playing' && game.weapons.length === 1, '[8] 重开后选卡应回到战斗');
console.log('[8] 死亡 / 重开 OK');

console.log('✅ 冒烟测试全部通过（Step 2 卡牌系统 + Step 3 武器升级）');