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
  'setLineDash',
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
const { EnemyBase } = await import('../js/enemies/base.js');
const { ChaserEnemy } = await import('../js/enemy.js');
const { ChargerEnemy } = await import('../js/enemies/charger.js');
const { RangedEnemy } = await import('../js/enemies/ranged.js');
const { BomberEnemy } = await import('../js/enemies/bomber.js');
const { ShieldEnemy } = await import('../js/enemies/shield.js');
const { BossEnemy } = await import('../js/enemies/boss.js');
const { EnhancedChaserEnemy } = await import('../js/enemies/enhanced-chaser.js');
const { chooseEnemyType, createEnemyByType } = await import('../js/enemies/index.js');
const { WaveDirector } = await import('../js/systems/waves.js');
const { createGem, updateGem } = await import('../js/gems.js');
const { drawEnemy } = await import('../js/enemy.js');
const { applyDot } = await import('../js/systems/status.js');
const { rollBossDrops, dropChanceFor, minTierFor } = await import('../js/meta/drops.js');
const { ITEM_BY_TIER, META_ITEMS } = await import('../js/meta/items.js');
const { priceForLevel, SHOP_MAX_LEVEL } = await import('../js/meta/shop.js');
const { loadSave, persistSave } = await import('../js/meta/save.js');

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
    } else if (game.state === 'extraction') {
      // 兼容：老测试长跑中若清完 Boss 波，默认「继续深入」保持对局推进
      key('keydown', 'KeyC');
      key('keyup', 'KeyC');
    } else if (game.state === 'summary') {
      key('keydown', 'Enter');
      key('keyup', 'Enter');
    }
    pump(1);
  }
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

// 预热 1 帧：main.js 的第一帧只记录时间戳，不推进逻辑
pump(1);

// ========== [0] Weapon card structure ==========
for (const card of WEAPON_CARDS) {
  assert(card.maxLevel === 6, '[0] ' + card.id + ' maxLevel must be 6');
  assert(card.levels.length === 6, '[0] ' + card.id + ' must have 6 levels');
  for (const level of card.levels) assert(level.damage > 0, '[0] ' + card.id + ' level damage missing');
}
console.log('[0] Weapon card structure OK');

// ========== [1] 主菜单 → 开局：全部武器卡任选一 ==========
assert(game.state === 'menu', '[1] 初始状态应为主菜单，实际 ' + game.state);
assert(game.currentOffers.length === WEAPON_CARDS.length, '[1] 开局应展示全部武器卡（' + WEAPON_CARDS.length + ' 张）');
const runsBefore = game.save.stats.runs;
key('keydown', 'Enter');
key('keyup', 'Enter');
pump(1);
assert(game.state === 'opening', '[1] Enter 开局后应进入开局选卡，实际 ' + game.state);
assert(game.save.stats.runs === runsBefore + 1, '[1] 开局数应 +1');
for (const o of game.currentOffers) {
  assert(o.card.kind === 'weapon' && o.type === 'new', '[1] 开局卡牌应全部是新武器卡');
}
pumpWithChoices(3, (o) => o.card.id !== 'trail'); // 站桩测试避开丹火（需要移动）
assert(game.state === 'playing', '[1] 选卡后应进入 playing，实际 ' + game.state);
assert(game.weapons.length === 1, '[1] 选卡后应持有 1 把武器');
console.log('[1] 主菜单开局选卡 OK：' + game.weapons[0].card.name);

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
  + ' 等级=' + game.level + ' 武器=' + game.weapons.length + ' 波次=' + game.waveDirector.wave);
assert(game.kills > 0, '[3] 没有产生击杀');
assert(game.level >= 2, '[3] 玩家应该至少升到 2 级');
assert(game.state === 'playing', '[3] 应处于战斗状态，实际 ' + game.state);
assert(game.weapons.length <= CONFIG.cards.maxWeaponSlots, '[3] 武器数量超过槽位上限');
assert(game.waveDirector.wave >= 2, '[3] 波次系统未推进');

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

// ========== [5] New base attributes ==========
{
  assert(ATTR_CARDS.length === 6, '[5] attribute pool must contain exactly 6 cards');
  assert(ATTR_CARDS.map((c) => c.id).join(',') === 'damage,armor,magnet,xp,maxHp,moveSpeed',
    '[5] attribute pool contains removed or missing cards');
  assert(CONFIG.gems.magnetRadius === 180, '[5] base magnet radius must be 180px');

  const m = computeMods({ damage: 2, armor: 5, magnet: 2, xp: 3, maxHp: 2, moveSpeed: 1 });
  const expectedReduction = 75 / 175;
  const expect = [
    ['damageMult', 1.3],
    ['armor', 75],
    ['damageReduction', expectedReduction],
    ['magnetRadiusBonus', 100],
    ['xpMult', 1.45],
    ['maxHpBonus', 40],
    ['moveSpeedMult', 1.06],
  ];
  for (const [key, value] of expect) {
    assert(Math.abs(m[key] - value) < 1e-6, '[5] bad ' + key + ': ' + m[key]);
  }
  const capped = computeMods({ armor: 1000 });
  assert(capped.damageReduction === 0.5, '[5] armor reduction must cap at 50%');

  const savedStacks = game.attrStacks;
  const savedMods = game.mods;
  const savedHp = game.player.hp;
  const savedMaxHp = game.player.maxHp;
  game.attrStacks = {};
  game.recomputeMods();
  game.player.hp = 50;
  game.player.maxHp = 100;
  game._applyOffer({ card: CARD_BY_ID.get('maxHp'), type: 'attr' });
  assert(game.player.maxHp === 120 && game.player.hp === 70, '[5] max HP card must add and heal 20');

  game.mods = computeMods({ armor: 5 });
  game.player.hp = 100;
  game.player.iFrames = 0;
  game.hurtPlayer(100);
  assert(Math.abs(game.player.hp - (100 - 100 * (1 - expectedReduction))) < 1e-6,
    '[5] player armor reduction was not applied');

  game.attrStacks = savedStacks;
  game.mods = savedMods;
  game.player.hp = savedHp;
  game.player.maxHp = savedMaxHp;
  game.player.iFrames = 0;
  console.log('[5] Base attributes, armor and max HP acquisition OK');
}

// ========== [6] Weapon mechanic changes ==========
{
  const baseWorld = () => ({
    player: { x: 0, y: 0, radius: 12, facing: 0, moving: false, lastHurtAt: -1 },
    enemies: [{ x: 120, y: 0, radius: 13, dead: false, hp: 1000 }],
    projectiles: [], trails: [], summons: [], effects: [], killLog: [],
    mods: computeMods({ projectile: 5, area: 5, attackSpeed: 5, cooldown: 5 }),
    elapsed: 0, kills: 0,
    damageEnemy: () => {}, healPlayer: () => {}, dropPickup: () => {},
    applyDot: () => {}, applySlow: () => {}, applyFreeze: () => {},
  });

  // Talisman always fires one projectile and tracks thunder per target.
  const talisman = CARD_BY_ID.get('talisman').create();
  const talismanWorld = baseWorld();
  talisman.update(1 / 60, talismanWorld);
  assert(talismanWorld.projectiles.length === 1, '[6] talisman must fire exactly one projectile');
  talisman.level = 2;
  let thunderHits = 0;
  const targetA = { x: 0, y: 0, radius: 10, dead: false };
  const targetB = { x: 10, y: 0, radius: 10, dead: false };
  talisman.world = { enemies: [targetA, targetB], damageEnemy: () => { thunderHits++; } };
  const hitProjectile = { damage: 10, attackSeq: 1 };
  talisman._onProjectileHit(targetA, hitProjectile);
  talisman._onProjectileHit(targetB, hitProjectile);
  assert(thunderHits === 0, '[6] thunder counters leaked between targets');
  talisman._onProjectileHit(targetA, hitProjectile);
  assert(thunderHits === 1, '[6] second hit on same target must trigger thunder');

  // Sword finite piercing, infinite piercing and every-third-attack draw slash.
  const sword = CARD_BY_ID.get('sword').create();
  sword.level = 2;
  const swordWorld = baseWorld();
  sword.update(1 / 60, swordWorld);
  assert(swordWorld.projectiles.length === 1 && swordWorld.projectiles[0].maxHits === 2,
    '[6] sword Lv2 must be one ranged sword with total 2 hits');
  sword.level = 5;
  sword.timer = 0;
  swordWorld.projectiles.length = 0;
  sword.update(1 / 60, swordWorld);
  assert(swordWorld.projectiles[0].maxHits === 4, '[6] sword Lv5 must pierce 3 enemies');
  sword.level = 6;
  sword.timer = 0;
  swordWorld.projectiles.length = 0;
  sword.update(1 / 60, swordWorld);
  assert(swordWorld.projectiles[0].maxHits === Infinity, '[6] sword Lv6 must pierce infinitely');

  const savedEnemies = game.enemies;
  const savedProjectiles = game.projectiles;
  const enemies = [0, 1, 2].map((i) => ({ x: 5000, y: i, radius: 10, hp: 100, dead: false, hitCooldown: 0 }));
  const finite = { x: 5000, y: 0, radius: 20, damage: 10, dead: false, pierce: true, maxHits: 2 };
  game.enemies = enemies;
  game.projectiles = [finite];
  game._handleCollisions();
  assert(finite.dead && enemies.filter((e) => e.hp === 90).length === 2, '[6] finite projectile hit limit failed');
  const infinite = { x: 5000, y: 0, radius: 20, damage: 10, dead: false, pierce: true, maxHits: Infinity };
  for (const e of enemies) { e.hp = 100; e.dead = false; }
  game.projectiles = [infinite];
  game._handleCollisions();
  assert(!infinite.dead && enemies.every((e) => e.hp === 90), '[6] infinite projectile piercing failed');
  game.enemies = savedEnemies;
  game.projectiles = savedProjectiles;

  const ringSword = CARD_BY_ID.get('sword').create();
  ringSword.level = 4;
  const ringWorld = baseWorld();
  ringWorld.enemies[0].x = 20;
  let bleedApplications = 0;
  ringWorld.applyDot = (enemy, type) => { if (type === 'bleed') bleedApplications++; };
  for (let i = 0; i < 3; i++) ringSword.update(2, ringWorld);
  assert(ringSword.rings.length === 1 && bleedApplications === 1, '[6] every third sword attack must add draw slash and bleed');

  // Cloak kill shock is extra and must not reset normal cooldown.
  const cloak = CARD_BY_ID.get('cloak').create();
  cloak.level = 6;
  const cloakWorld = baseWorld();
  cloak.update(0.1, cloakWorld);
  cloakWorld.kills = 100;
  cloak.update(0.1, cloakWorld);
  assert(cloak.shocks.some((shock) => shock.enhanced), '[6] cloak 100-kill enhanced shock missing');
  assert(cloak.shockTimer > 2.7, '[6] enhanced shock incorrectly reset normal cooldown');

  // Trail blaze is independent from cloak burn.
  const burnEnemy = { x: 0, y: 0, radius: 10, hp: 1, dead: false, dots: {} };
  applyDot(burnEnemy, 'burn', 1, 2);
  game.damageEnemy(burnEnemy, 2);
  assert(game.killLog.at(-1).burned && !game.killLog.at(-1).blazed, '[6] cloak burn incorrectly counts as trail blaze');
  const blazeEnemy = { x: 0, y: 0, radius: 10, hp: 1, dead: false, dots: {} };
  applyDot(blazeEnemy, 'blaze', 1, 2);
  game.damageEnemy(blazeEnemy, 2);
  assert(game.killLog.at(-1).blazed, '[6] trail blaze was not recorded');

  // Trail Lv4 creates a furnace from a valid loop; Lv6 opening creates a hot zone.
  const trailWeapon = CARD_BY_ID.get('trail').create();
  trailWeapon.level = 6;
  const trailWorld = baseWorld();
  trailWorld.player.x = 60;
  trailWorld.player.y = 60;
  trailWorld.enemies = [{ x: 60, y: 60, radius: 10, hp: 10000, dead: false, rank: 'normal' }];
  trailWorld.damageEnemy = (enemy, damage) => {
    enemy.hp -= damage;
    if (enemy.hp <= 0) enemy.dead = true;
  };
  let trailHeals = 0;
  let speedBonus = 1;
  trailWorld.healPlayer = (amount) => { trailHeals += amount; };
  trailWorld.setPlayerMoveSpeedBonus = (source, multiplier) => { speedBonus = multiplier; };
  const loopPoints = [
    [0, 0, 0], [120, 0, 0.35], [120, 120, 0.7], [0, 120, 1.05], [5, 5, 1.3],
  ];
  trailWeapon.pathPoints = loopPoints.map(([x, y, at]) => ({ x, y, at, trail: { dead: false } }));
  trailWorld.elapsed = 1.3;
  trailWeapon._tryCreateFurnace(trailWorld, trailWeapon.stats);
  assert(trailWeapon.furnaces.length === 1 && trailWeapon.loopCooldown > 0,
    '[6] trail valid loop did not create furnace');
  const furnace = trailWeapon.furnaces[0];
  furnace.fuel = 9;
  trailWeapon._tryOpen(furnace, trailWorld, trailWeapon.stats);
  assert(furnace.opens === 1 && trailWeapon.hotZones.length === 1,
    '[6] trail furnace opening or Ninefold hot zone missing');
  trailWeapon._updateHotZones(0.5, trailWorld, trailWeapon.stats);
  assert(trailHeals === 1 && Math.abs(speedBonus - 1.12) < 1e-6,
    '[6] trail hot-zone healing or movement bonus missing');

  // Staff: self-explosion kills cannot convert; pity and corpse cap are enforced.
  const staff = CARD_BY_ID.get('staff').create();
  staff.level = 6;
  const staffWorld = baseWorld();
  staffWorld.killLog = Array.from({ length: 10 }, (_, i) => ({ id: i + 1, x: 0, y: 0, noSummon: true }));
  const oldRandom = Math.random;
  Math.random = () => 1;
  staff.update(0, staffWorld);
  assert(staff.corpses.length === 0, '[6] noSummon kills created corpse minions');
  staffWorld.killLog.push(...Array.from({ length: 60 }, (_, i) => ({ id: i + 11, x: 0, y: 0, noSummon: false })));
  staff.update(0, staffWorld);
  Math.random = oldRandom;
  assert(staff.corpses.length === 5, '[6] corpse minion cap must be 5');
  let blastOptions = null;
  const blastWorld = baseWorld();
  blastWorld.enemies = [{ x: 0, y: 0, radius: 10, dead: false }];
  blastWorld.damageEnemy = (enemy, damage, options) => { blastOptions = options; };
  staff.detonate({ x: 0, y: 0, damage: 10 }, staff.stats, blastWorld);
  assert(blastOptions && blastOptions.noSummon, '[6] staff explosion damage must carry noSummon');

  console.log('[6] Weapon transformations and caps OK');
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

// ========== [8] 敌人基类与四种特殊机制 ==========
{
  const chaserEarly = new ChaserEnemy(0, 0, 0);
  const chaserLate = new ChaserEnemy(0, 0, 60);
  assert(chaserEarly instanceof EnemyBase, '[8] 普通怪未继承 EnemyBase');
  assert(chaserLate.maxHp > chaserEarly.maxHp, '[8] 普通怪生命值未随时间成长');

  const charger = new ChargerEnemy(0, 0, 0);
  assert(charger instanceof EnemyBase && charger.rank === 'enhanced', '[8] 冲锋怪档位错误');
  charger.update({ x: 100, y: 0 }, 0.01, {});
  assert(charger.state === 'windup', '[8] 冲锋怪未进入预警');
  charger.update({ x: 100, y: 0 }, CONFIG.enemyTypes.charger.windup + 0.01, {});
  assert(charger.state === 'dash', '[8] 冲锋怪未进入冲锋');
  const chargerX = charger.x;
  charger.update({ x: 100, y: 0 }, 0.1, {});
  assert(charger.x > chargerX, '[8] 冲锋怪未沿锁定方向移动');

  const hostileShots = [];
  const ranged = new RangedEnemy(0, 0, 0);
  ranged.update({ x: 250, y: 0 }, CONFIG.enemyTypes.ranged.fireInterval + 0.01, {
    spawnHostileProjectile: (options) => hostileShots.push(options),
  });
  assert(ranged instanceof EnemyBase && ranged.rank === 'enhanced-minion', '[8] 远程怪档位错误');
  assert(hostileShots.length === 1 && hostileShots[0].speed === CONFIG.enemyTypes.ranged.projectileSpeed,
    '[8] 远程怪未通过公共 API 发射弹道');
  assert(CONFIG.enemyTypes.ranged.weight < CONFIG.enemyTypes.charger.weight,
    '[8] 远程怪权重应明显低于冲锋怪');

  // Enemy projectile integration: shared spawn, collision and player damage path.
  const savedEnemies = game.enemies;
  const savedHostiles = game.hostileProjectiles;
  const savedHp = game.player.hp;
  const savedIFrames = game.player.iFrames;
  const savedLastHurtAt = game.player.lastHurtAt;
  const savedHitShake = game.hitShake;
  game.enemies = [];
  game.hostileProjectiles = [];
  game.player.hp = game.player.maxHp;
  game.player.iFrames = 0;
  game.spawnHostileProjectile({
    x: game.player.x, y: game.player.y, angle: 0,
    speed: 0, radius: 5, damage: 5, lifetime: 1,
  });
  game._handleCollisions();
  const expectedProjectileDamage = 5 * (1 - game.mods.damageReduction);
  assert(Math.abs(game.player.hp - (game.player.maxHp - expectedProjectileDamage)) < 1e-6 && game.hostileProjectiles[0].dead,
    '[8] 敌方弹道未通过统一碰撞入口伤害玩家');
  game.enemies = savedEnemies;
  game.hostileProjectiles = savedHostiles;
  game.player.hp = savedHp;
  game.player.iFrames = savedIFrames;
  game.player.lastHurtAt = savedLastHurtAt;
  game.hitShake = savedHitShake;

  let blastDamageCount = 0;
  let blastEffectCount = 0;
  const bomber = new BomberEnemy(0, 0, 0);
  const closePlayer = { x: 10, y: 0 };
  const bomberWorld = {
    hurtPlayer: () => { blastDamageCount++; },
    spawnEnemyBlast: () => { blastEffectCount++; },
  };
  bomber.update(closePlayer, 0.01, bomberWorld);
  bomber.update(closePlayer, CONFIG.enemyTypes.bomber.windup + 0.01, bomberWorld);
  bomber.update(closePlayer, 1, bomberWorld);
  assert(bomber.dead && blastDamageCount === 1 && blastEffectCount === 1,
    '[8] 自爆怪应只爆炸并伤害一次');

  const shield = new ShieldEnemy(0, 0, 0);
  assert(shield instanceof EnemyBase && shield.rank === 'elite', '[8] 护盾怪档位错误');
  assert(Math.abs(shield.modifyIncomingDamage(10) - 10 * CONFIG.enemyTypes.shield.shieldDamageMult) < 1e-6,
    '[8] 护盾期减伤错误');
  shield.update({ x: 100, y: 0 }, CONFIG.enemyTypes.shield.shieldDuration + 0.01, {});
  assert(shield.phase === 'open', '[8] 护盾怪未进入开放期');
  assert(Math.abs(shield.modifyIncomingDamage(10) - 10 * CONFIG.enemyTypes.shield.openDamageMult) < 1e-6,
    '[8] 开放期易伤错误');

  // Wave scaling and enhanced chaser enrage.
  const savedRandomForWave = Math.random;
  Math.random = () => 0.5;
  const waveOneEnemy = createEnemyByType('chaser', 0, 0, 60, 1);
  const waveElevenEnemy = createEnemyByType('chaser', 0, 0, 60, 11);
  Math.random = savedRandomForWave;
  assert(Math.abs(waveElevenEnemy.maxHp / waveOneEnemy.maxHp - 2.2) < 1e-6,
    '[8] enemy HP wave scaling incorrect');
  assert(Math.abs(waveElevenEnemy.damage / waveOneEnemy.damage - 1.7) < 1e-6,
    '[8] enemy damage wave scaling incorrect');
  assert(Math.abs(waveElevenEnemy.speed / waveOneEnemy.speed - 1.15) < 1e-6,
    '[8] enemy speed wave scaling incorrect');

  const enhanced = new EnhancedChaserEnemy(0, 0, 0);
  const enhancedBaseDamage = enhanced.damage;
  enhanced.hp = enhanced.maxHp * 0.5;
  enhanced.update({ x: 100, y: 0 }, 0.01, {});
  assert(enhanced.warningTimer > 0 && !enhanced.enraged,
    '[8] enhanced chaser did not enter warning state');
  enhanced.update({ x: 100, y: 0 }, CONFIG.enemyTypes.enhancedChaser.warningDuration + 0.01, {});
  assert(enhanced.enraged && enhanced.damage > enhancedBaseDamage,
    '[8] enhanced chaser did not enrage after warning');

  const oldRandomForTypes = Math.random;
  Math.random = () => 0.01;
  for (let i = 0; i < 30; i++) {
    const lateType = chooseEnemyType(120, [], { wave: 11, quota: 62, spawnedByType: {} });
    assert(lateType !== 'chaser', '[8] base chaser returned after wave 11');
  }
  for (let i = 0; i < 30; i++) {
    const cappedType = chooseEnemyType(120, [], { wave: 8, quota: 12, spawnedByType: { ranged: 1 } });
    assert(cappedType !== 'ranged', '[8] ranged per-wave cap was exceeded');
  }
  Math.random = oldRandomForTypes;

  console.log('[8] Enemy base, special mechanics and wave scaling OK');
}

// ========== [9] 波次 / Boss / 精英掉落 / 经验锁定吸附 ==========
{
  // 经验宝石一旦进入范围必须持续追踪，不能因玩家移动出初始范围而脱锁甩飞。
  const gem = createGem(180, 0, 0);
  gem.vx = 500;
  gem.vy = 0;
  const gemPlayer = { x: 0, y: 0 };
  updateGem(gem, gemPlayer, 1 / 60, CONFIG.gems.magnetRadius);
  assert(gem.magnetized && gem.vx < 0, '[9] 经验宝石未在范围内锁定玩家');
  gemPlayer.x = 700;
  updateGem(gem, gemPlayer, 1 / 60, CONFIG.gems.magnetRadius);
  assert(gem.magnetized && gem.vx > 0, '[9] 经验宝石离开初始范围后脱锁');

  // 波次 3 保证精英；投放完并清场后进入休整。
  const director = new WaveDirector();
  director.wave = 3;
  director.quota = 2;
  director.spawned = 0;
  const fakeGame = {
    elapsed: 60,
    enemies: [],
    spawner: {
      timer: 0,
      spawnType(type, elapsed, enemies) {
        const enemy = { type, rank: type === 'shield' ? 'elite' : 'normal', dead: false };
        enemies.push(enemy);
        return enemy;
      },
      update(dt, elapsed, enemies, camera, viewW, viewH, options) {
        const count = Math.min(1, options.spawnLimit);
        for (let i = 0; i < count; i++) enemies.push({ type: 'chaser', rank: 'normal', dead: false });
        return count;
      },
    },
  };
  director.update(1 / 60, fakeGame, { x: 0, y: 0 }, 1280, 720);
  assert(fakeGame.enemies.some((enemy) => enemy.rank === 'elite'), '[9] 精英波未保证生成精英怪');
  assert(director.spawned === 2 && director.remaining === 0, '[9] 波次投放数量错误');
  for (const enemy of fakeGame.enemies) enemy.dead = true;
  director.update(1 / 60, fakeGame, { x: 0, y: 0 }, 1280, 720);
  assert(director.phase === 'rest', '[9] 清空波次后未进入休整');

  assert(new WaveDirector()._quotaFor(1) === 12, '[9] wave 1 quota must be 12');
  assert(new WaveDirector()._quotaFor(9) === 52, '[9] normal-wave quota growth incorrect');
  assert(new WaveDirector()._quotaFor(15) === 7, '[9] wave 15 boss reinforcement quota incorrect');
  assert(new WaveDirector()._quotaFor(20) === 9, '[9] late boss reinforcement cap incorrect');

  const bossDirector = new WaveDirector();
  bossDirector.wave = CONFIG.waves.bossEvery;
  bossDirector.quota = 1;
  bossDirector.update(1 / 60, fakeGame, { x: 0, y: 0 }, 1280, 720);
  assert(fakeGame.enemies.at(-1).type === 'boss' && bossDirector.bossSpawned,
    '[9] Boss 波未通过波次系统生成 Boss');

  // Boss 蓄力后应发射环形弹幕，并拥有独立 Boss 档位。
  const bossShots = [];
  const boss = new BossEnemy(0, 0, 120);
  boss.attackCooldown = 0;
  boss.update({ x: 200, y: 0 }, 0.01, {});
  assert(boss.rank === 'boss' && boss.state === 'windup', '[9] Boss 未进入蓄力攻击');
  boss.update({ x: 200, y: 0 }, CONFIG.enemyTypes.boss.windup + 0.01, {
    spawnHostileProjectile: (options) => bossShots.push(options),
    spawnEnemyBlast: () => {},
  });
  assert(bossShots.length === CONFIG.enemyTypes.boss.projectileCount, '[9] Boss 环形弹幕数量错误');

  // 精英标记绘制不应依赖具体精英类，并且精英死亡必掉一个稀有物品。
  const elite = new ShieldEnemy(game.player.x, game.player.y, game.elapsed);
  drawEnemy(ctxStub, elite);
  const pickupCount = game.pickups.length;
  game.damageEnemy(elite, elite.maxHp * 10);
  assert(game.pickups.length === pickupCount + 1 && game.pickups.at(-1).kind === 'rare',
    '[9] 精英怪死亡未掉落稀有物品');
  const bossDropCount = game.pickups.length;
  const defeatedBoss = new BossEnemy(game.player.x + 100, game.player.y, game.elapsed);
  game.damageEnemy(defeatedBoss, defeatedBoss.maxHp * 2);
  assert(game.pickups.length === bossDropCount + 2 && game.bossesDefeated > 0,
    '[9] Boss 死亡未掉落两件稀有物品');

  const rarePickup = game.pickups.find((pickup) => pickup.kind === 'rare');
  rarePickup.x = game.player.x;
  rarePickup.y = game.player.y;
  game._updatePickups(1 / 60);
  assert(rarePickup.dead && Object.keys(game.rareInventory).length > 0 && game.rareMessage,
    '[9] 稀有物品未被拾取或未生效');

  console.log('[9] 波次 / Boss / 精英掉落 / 经验吸附 OK');
}

// ========== [Debug] Debug Runtime ==========
{
  const debug = game.debug;
  const closeTo = (actual, expected, message, epsilon = 1e-6) => {
    assert(Math.abs(actual - expected) <= epsilon, `${message}: ${actual} !== ${expected}`);
  };
  const weaponSnapshot = () => Object.fromEntries(
    game.weapons.map((weapon) => [weapon.card.id, weapon.level]),
  );

  // Defaults must be neutral for normal gameplay.
  assert(debug && typeof debug.setPlayerSettings === 'function', '[Debug] game.debug missing');
  assert(
    debug.settings.player.damageMult === 1
      && debug.settings.player.xpMult === 1
      && debug.settings.player.moveSpeedMult === 1
      && debug.settings.player.maxHpMult === 1
      && debug.settings.player.pickupRangeMult === 1
      && debug.settings.player.armorBonus === 0
      && debug.settings.enemy.hpMult === 1
      && debug.settings.enemy.damageMult === 1
      && debug.settings.enemy.speedMult === 1,
    '[Debug] default multipliers are not neutral',
  );
  const defaultMods = { ...game.mods };
  const defaultPickupRange = game.gemMagnetRadius();
  const defaultEnemy = createEnemyByType('chaser', 0, 0, game.elapsed, game.waveDirector.wave);
  const defaultEnemyStats = [defaultEnemy.maxHp, defaultEnemy.hp, defaultEnemy.damage, defaultEnemy.speed];
  debug.applyEnemyMultipliers(defaultEnemy);
  closeTo(game.mods.damageMult, defaultMods.damageMult, '[Debug] default damage changed');
  closeTo(game.mods.xpMult, defaultMods.xpMult, '[Debug] default xp changed');
  closeTo(game.mods.moveSpeedMult, defaultMods.moveSpeedMult, '[Debug] default move changed');
  closeTo(game.gemMagnetRadius(), defaultPickupRange, '[Debug] default pickup changed');
  [defaultEnemy.maxHp, defaultEnemy.hp, defaultEnemy.damage, defaultEnemy.speed].forEach((value, index) => {
    closeTo(value, defaultEnemyStats[index], '[Debug] default enemy stats changed');
  });

  // Player settings, HP ratio/clamping and invincibility.
  const naturalMaxHp = CONFIG.player.maxHp + (game.mods.maxHpBonus ?? 0);
  game.player.maxHp = naturalMaxHp;
  game.player.hp = naturalMaxHp * 0.4;
  debug.setPlayerSettings({
    damageMult: 2, xpMult: 3, moveSpeedMult: 1.5,
    armorBonus: 50, pickupRangeMult: 2.5, maxHpMult: 2,
  });
  closeTo(game.mods.damageMult, defaultMods.damageMult * 2, '[Debug] damage multiplier');
  closeTo(game.mods.xpMult, defaultMods.xpMult * 3, '[Debug] xp multiplier');
  closeTo(game.mods.moveSpeedMult, defaultMods.moveSpeedMult * 1.5, '[Debug] move multiplier');
  closeTo(game.mods.armor, defaultMods.armor + 50, '[Debug] armor bonus');
  closeTo(game.gemMagnetRadius(), defaultPickupRange * 2.5, '[Debug] pickup multiplier');
  closeTo(game.player.maxHp, naturalMaxHp * 2, '[Debug] max HP multiplier');
  closeTo(game.player.hp / game.player.maxHp, 0.4, '[Debug] max HP ratio preservation');
  debug.setPlayerHp(game.player.maxHp * 10);
  closeTo(game.player.hp, game.player.maxHp, '[Debug] HP upper clamp');
  debug.setPlayerHp(-100);
  closeTo(game.player.hp, 0, '[Debug] HP lower clamp');
  debug.setPlayerHp(game.player.maxHp * 0.5);
  game.player.iFrames = 0;
  debug.setInvincible(true);
  const hpBeforeInvincibleHit = game.player.hp;
  assert(game.hurtPlayer(25) === false, '[Debug] invincible hurtPlayer return');
  closeTo(game.player.hp, hpBeforeInvincibleHit, '[Debug] invincible hurtPlayer block');
  debug.setInvincible(false);

  // Debug weapon levels bypass slots; resetDefaults restores natural weapons.
  const normalWeaponLevels = weaponSnapshot();
  WEAPON_CARDS.forEach((card, index) => debug.setWeaponLevel(card.id, index + 1));
  assert(game.weapons.length === WEAPON_CARDS.length, '[Debug] weapon slot bypass');
  WEAPON_CARDS.forEach((card, index) => {
    assert(game.weapons.find((weapon) => weapon.card.id === card.id)?.level === index + 1,
      `[Debug] weapon level ${card.id}`);
  });
  debug.setWeaponLevel(WEAPON_CARDS[0].id, 0);
  assert(!game.weapons.some((weapon) => weapon.card.id === WEAPON_CARDS[0].id), '[Debug] weapon level 0 removal');
  debug.setWeaponLevel(WEAPON_CARDS[0].id, 6);
  debug.resetDefaults();
  const restoredNaturalWeapons = weaponSnapshot();
  assert(Object.keys(restoredNaturalWeapons).length === Object.keys(normalWeaponLevels).length
    && Object.entries(normalWeaponLevels).every(([id, level]) => restoredNaturalWeapons[id] === level),
  '[Debug] natural weapon baseline restoration');
  for (const card of WEAPON_CARDS) debug.setWeaponLevel(card.id, 4);
  game.reset();
  assert(game.weapons.length === WEAPON_CARDS.length && game.weapons.every((weapon) => weapon.level === 4),
    '[Debug] weapon overrides did not survive game.reset');

  // Existing/new enemy scaling, idempotence and dynamic 1.35x preservation.
  debug.clearEnemies();
  const existingEnemy = createEnemyByType('chaser', 0, 0, game.elapsed, game.waveDirector.wave);
  const baseEnemyStats = { maxHp: existingEnemy.maxHp, damage: existingEnemy.damage, speed: existingEnemy.speed };
  existingEnemy.hp = existingEnemy.maxHp * 0.4;
  game.enemies.push(existingEnemy);
  debug.setEnemyMultipliers({ hpMult: 2, damageMult: 3, speedMult: 4 });
  closeTo(existingEnemy.maxHp, baseEnemyStats.maxHp * 2, '[Debug] existing enemy HP');
  closeTo(existingEnemy.hp / existingEnemy.maxHp, 0.4, '[Debug] existing enemy HP ratio');
  closeTo(existingEnemy.damage, baseEnemyStats.damage * 3, '[Debug] existing enemy damage');
  closeTo(existingEnemy.speed, baseEnemyStats.speed * 4, '[Debug] existing enemy speed');
  const originalRandom = Math.random;
  Math.random = () => 0.5;
  const manualControl = createEnemyByType('chaser', 0, 0, game.elapsed, game.waveDirector.wave);
  const manualEnemies = debug.spawnEnemies('chaser', 1);
  Math.random = originalRandom;
  assert(manualEnemies.length === 1, '[Debug] manual spawn count');
  closeTo(manualEnemies[0].maxHp, manualControl.maxHp * 2, '[Debug] new enemy HP');
  closeTo(manualEnemies[0].damage, manualControl.damage * 3, '[Debug] new enemy damage');
  closeTo(manualEnemies[0].speed, manualControl.speed * 4, '[Debug] new enemy speed');
  const unchangedStats = [existingEnemy.maxHp, existingEnemy.hp, existingEnemy.damage, existingEnemy.speed];
  debug.setEnemyMultipliers({ hpMult: 2, damageMult: 3, speedMult: 4 });
  [existingEnemy.maxHp, existingEnemy.hp, existingEnemy.damage, existingEnemy.speed].forEach((value, index) => {
    closeTo(value, unchangedStats[index], '[Debug] repeated enemy multiplier stacking');
  });
  existingEnemy.damage *= 1.35;
  existingEnemy.speed *= 1.35;
  debug.setEnemyMultipliers({ hpMult: 3, damageMult: 5, speedMult: 6 });
  closeTo(existingEnemy.maxHp, baseEnemyStats.maxHp * 3, '[Debug] changed enemy HP');
  closeTo(existingEnemy.hp / existingEnemy.maxHp, 0.4, '[Debug] changed enemy HP ratio');
  closeTo(existingEnemy.damage, baseEnemyStats.damage * 1.35 * 5, '[Debug] dynamic enemy damage preservation');
  closeTo(existingEnemy.speed, baseEnemyStats.speed * 1.35 * 6, '[Debug] dynamic enemy speed preservation');

  // Spawn quota/cap/interval/pause, wave jump, manual spawn and clear.
  debug.setWave(4);
  const baseQuota = game.waveDirector.baseQuota;
  debug.setSpawnSettings({ quotaMult: 1.5, aliveCap: 2, intervalMult: 0.5, paused: true });
  assert(game.waveDirector.quota === Math.round(baseQuota * 1.5), '[Debug] quota multiplier');
  assert(debug.settings.spawn.aliveCap === 2 && debug.settings.spawn.intervalMult === 0.5
    && debug.settings.spawn.paused === true, '[Debug] spawn settings update');
  game.spawner.timer = 0;
  assert(game.spawner.update(1, game.elapsed, game.enemies, game.camera, 1280, 720, {
    spawnLimit: 1, wave: game.waveDirector.wave, spawnSettings: debug.settings.spawn, debug,
  }) === 0, '[Debug] spawn pause');
  debug.setSpawnSettings({ paused: false });
  game.enemies = [
    createEnemyByType('chaser', 0, 0, game.elapsed, game.waveDirector.wave),
    createEnemyByType('chaser', 0, 0, game.elapsed, game.waveDirector.wave),
  ];
  game.spawner.timer = 0;
  assert(game.spawner.update(1, game.elapsed, game.enemies, game.camera, 1280, 720, {
    spawnLimit: 1, wave: game.waveDirector.wave, spawnSettings: debug.settings.spawn, debug,
  }) === 0, '[Debug] alive cap');
  game.enemies.length = 0;
  debug.setSpawnSettings({ aliveCap: 10, intervalMult: 0.5 });
  game.spawner.timer = 0;
  const expectedInterval = Math.max(CONFIG.spawner.minInterval,
    CONFIG.spawner.startInterval - (game.waveDirector.wave - 1) * CONFIG.spawner.intervalPerWave) * 0.5;
  assert(game.spawner.update(0, game.elapsed, game.enemies, game.camera, 1280, 720, {
    spawnLimit: 1, wave: game.waveDirector.wave, spawnSettings: debug.settings.spawn, debug,
  }) === 1, '[Debug] interval test spawn');
  closeTo(game.spawner.timer, expectedInterval, '[Debug] interval multiplier');
  game.hostileProjectiles.push({ dead: false });
  debug.setWave(7);
  assert(game.waveDirector.wave === 7 && game.waveDirector.phase === 'wave'
    && game.waveDirector.spawned === 0 && game.enemies.length === 0 && game.hostileProjectiles.length === 0,
  '[Debug] setWave clear/jump');
  const directorSpawnedBeforeManual = game.waveDirector.spawned;
  const spawned = debug.spawnEnemies('chaser', 3);
  assert(spawned.length === 3 && game.enemies.length === 3, '[Debug] spawnEnemies count');
  assert(game.waveDirector.spawned === directorSpawnedBeforeManual, '[Debug] spawnEnemies changed director.spawned');
  game.hostileProjectiles.push({ dead: false });
  debug.clearEnemies();
  assert(game.enemies.length === 0 && game.hostileProjectiles.length === 0, '[Debug] clearEnemies');

  // Basic serialization round trip.
  debug.setInvincible(true);
  debug.setPlayerSettings({ damageMult: 2.25, xpMult: 1.75 });
  debug.setEnemyMultipliers({ hpMult: 2.5, damageMult: 1.5, speedMult: 1.25 });
  debug.setSpawnSettings({ quotaMult: 2, aliveCap: 9, intervalMult: 0.75, paused: true });
  debug.setWave(8);
  const serialized = debug.serialize();
  debug.setInvincible(false);
  debug.setPlayerSettings({ damageMult: 1, xpMult: 1 });
  debug.setEnemyMultipliers({ hpMult: 1, damageMult: 1, speedMult: 1 });
  debug.setSpawnSettings({ quotaMult: 1, aliveCap: null, intervalMult: 1, paused: false });
  debug.setWeaponLevel(WEAPON_CARDS[0].id, 0);
  debug.setWave(2);
  const restored = debug.applySerialized(JSON.stringify(serialized));
  assert(restored && restored.wave === serialized.wave, '[Debug] serialized wave round trip');
  assert(restored.settings.invincible === serialized.settings.invincible
    && restored.settings.player.damageMult === serialized.settings.player.damageMult
    && restored.settings.player.xpMult === serialized.settings.player.xpMult
    && restored.settings.enemy.hpMult === serialized.settings.enemy.hpMult
    && restored.settings.spawn.aliveCap === serialized.settings.spawn.aliveCap,
  '[Debug] serialized settings round trip');
  assert(JSON.stringify(restored.weaponLevels) === JSON.stringify(serialized.weaponLevels),
    '[Debug] serialized weapon round trip');

  // Debug settings survive reset by design, so restore them before [10].
  debug.resetDefaults();
  debug.clearEnemies();
  game.reset();
  game.state = 'playing';
  assert(debug.settings.invincible === false && debug.settings.player.damageMult === 1
    && debug.settings.enemy.hpMult === 1 && debug.settings.spawn.paused === false
    && game.weapons.length === 0, '[Debug] cleanup failed');
  console.log('[Debug] Debug Runtime OK');
}

// ========== [10] 死亡与 R 返回主菜单 ==========
game.player.hp = 1;
game.player.iFrames = 0;
game.hurtPlayer(999);
game._handleCollisions();
assert(game.state === 'dead', '[10] 玩家应该已死亡，实际 ' + game.state);

key('keydown', 'KeyR');
key('keyup', 'KeyR');
pump(3);
assert(game.state === 'menu', '[10] 死亡后按 R 应返回主菜单，实际 ' + game.state);
assert(game.weapons.length === 0, '[10] 返回后武器应清空');
assert(game.level === 1, '[10] 返回后等级应重置为 1');
assert(game.kills === 0, '[10] 返回后击杀数应清零');
assert(game.waveDirector.wave === 1, '[10] 返回后波次应重置为 1');
assert(Object.keys(game.rareInventory).length === 0, '[10] 返回后稀有物品应清空');

key('keydown', 'Enter');
key('keyup', 'Enter');
pump(1);
assert(game.state === 'opening', '[10] 开局后应进入开局选卡，实际 ' + game.state);
pumpWithChoices(3);
assert(game.state === 'playing' && game.weapons.length === 1, '[10] 开局选卡后应回到战斗');
console.log('[10] 死亡 / 返回主菜单 OK');

// ========== [11] Boss 掉落概率边界与保底品阶 ==========
{
  const closeTo = (actual, expected, message, epsilon = 1e-9) => {
    assert(Math.abs(actual - expected) <= epsilon, message + '（实际 ' + actual + '，期望 ' + expected + '）');
  };
  // 概率公式：基础 8% + 每阶 3%，上限 20%
  closeTo(dropChanceFor(1), 0.08, '[11] 阶位 1 掉落率应为 8%');
  closeTo(dropChanceFor(2), 0.11, '[11] 阶位 2 掉落率应为 11%');
  closeTo(dropChanceFor(5), 0.20, '[11] 阶位 5 掉落率应达上限 20%');
  closeTo(dropChanceFor(9), 0.20, '[11] 阶位 9 掉落率应保持上限 20%');
  assert(dropChanceFor(100) <= 0.20, '[11] 总掉落概率不得超过 20%');
  // 保底品阶：1~2 阶无保底，3~4 阶 ≥T2，5 阶+ ≥T3
  assert(minTierFor(1) === 1 && minTierFor(2) === 1, '[11] 阶位 1~2 不应有保底');
  assert(minTierFor(3) === 2 && minTierFor(4) === 2, '[11] 阶位 3~4 保底应为 T2');
  assert(minTierFor(5) === 3 && minTierFor(9) === 3, '[11] 阶位 5+ 保底应为 T3');
  // rng=0.99 → 必不触发掉落
  for (let tier = 1; tier <= 9; tier++) {
    assert(rollBossDrops(tier, () => 0.99).length === 0, '[11] 阶位 ' + tier + ' 未命中概率时不应掉落');
  }
  // rng=0 → 必掉；数量取下限；品阶被保底抬升
  assert(JSON.stringify(rollBossDrops(1, () => 0)) === JSON.stringify(['shard']), '[11] 阶位 1 保底掉落应为 1 个碎片');
  assert(JSON.stringify(rollBossDrops(3, () => 0)) === JSON.stringify(['essence']), '[11] 阶位 3 保底掉落应抬升为辉光精华');
  assert(JSON.stringify(rollBossDrops(5, () => 0)) === JSON.stringify(['soulCrystal', 'soulCrystal']), '[11] 阶位 5 保底掉落应为 2 个灵魂结晶');
  console.log('[11] Boss 掉落概率 / 保底品阶 OK');
}

// ========== [12] 撤离流程：Boss 波清空 → 撤离 → 结算 → 存档 ==========
{
  game.pendingChoices = 0;
  game.enemies.length = 0;
  game.hostileProjectiles.length = 0;
  const bossWave = CONFIG.waves.bossEvery;
  game.waveDirector.startWave(game, bossWave);
  assert(game.waveDirector.isBossWave, '[12] 第 ' + bossWave + ' 波应为 Boss 波');
  const bossTierBefore = game.bossesDefeated;
  const boss = new BossEnemy(game.player.x + 60, game.player.y, game.elapsed);
  game.enemies.push(boss);
  game.waveDirector.bossSpawned = true;
  game.waveDirector.spawned = game.waveDirector.quota;

  // 掉落随机桩为 0.99 → 本次不掉材料，专注验证撤离主流程
  const origRandom = Math.random;
  Math.random = () => 0.99;
  game.damageEnemy(boss, boss.maxHp * 2);
  game.gems.length = 0;
  game.pickups.length = 0;
  pump(1);
  Math.random = origRandom;

  assert(boss.dead, '[12] Boss 应被击杀');
  assert(game.bossesDefeated === bossTierBefore + 1, '[12] Boss 击杀数应 +1');
  assert(game.state === 'extraction', '[12] Boss 波清空应进入撤离抉择，实际 ' + game.state);
  assert(Object.values(game.tempBackpack).every((n) => n === 0), '[12] 未掉落时临时背包应为空');

  const dcBefore = game.save.darkCrystals;
  const extractionsBefore = game.save.stats.extractions;
  key('keydown', 'KeyE');
  key('keyup', 'KeyE');
  pump(1);
  assert(game.state === 'summary', '[12] 撤离后应进入结算界面，实际 ' + game.state);
  assert(game.save.darkCrystals === dcBefore + bossWave * CONFIG.meta.waveRewardMult,
    '[12] 撤离暗晶奖励应为 波数×' + CONFIG.meta.waveRewardMult);
  assert(game.save.stats.extractions === extractionsBefore + 1, '[12] 成功撤离次数应 +1');
  assert(game.save.stats.bestWave >= bossWave, '[12] 最佳波数应更新');
  assert(game.lastRunSummary && game.lastRunSummary.wave === bossWave
    && game.lastRunSummary.darkCrystalsGained === bossWave * CONFIG.meta.waveRewardMult,
    '[12] 结算数据错误');
  const reloaded = loadSave();
  assert(reloaded.darkCrystals === game.save.darkCrystals
    && reloaded.stats.extractions === game.save.stats.extractions, '[12] 撤离结果应写入存档');

  key('keydown', 'Enter');
  key('keyup', 'Enter');
  pump(1);
  assert(game.state === 'menu', '[12] 确认结算应返回主菜单，实际 ' + game.state);
  console.log('[12] 撤离流程 OK');
}

// ========== [13] 继续深入：背包保留，下个 Boss 波再次抉择 ==========
{
  game.pendingChoices = 0;
  key('keydown', 'Enter');
  key('keyup', 'Enter');
  pump(1);
  assert(game.state === 'opening', '[13] 应进入开局选卡，实际 ' + game.state);
  pumpWithChoices(3);
  assert(game.state === 'playing', '[13] 选卡后应进入战斗，实际 ' + game.state);
  game.pendingChoices = 0;
  game.enemies.length = 0;
  game.hostileProjectiles.length = 0;

  const bossWave = CONFIG.waves.bossEvery;
  game.waveDirector.startWave(game, bossWave);
  const boss = new BossEnemy(game.player.x + 60, game.player.y, game.elapsed);
  game.enemies.push(boss);
  game.waveDirector.bossSpawned = true;
  game.waveDirector.spawned = game.waveDirector.quota;

  // rng=0 → 必掉：数量取下限、品阶被保底抬升
  const origRandom = Math.random;
  Math.random = () => 0;
  game.damageEnemy(boss, boss.maxHp * 2);
  game.gems.length = 0;
  game.pickups.length = 0;
  pump(1);
  Math.random = origRandom;

  assert(game.state === 'extraction', '[13] Boss 波清空应进入撤离抉择，实际 ' + game.state);
  const bossTier = game.bossesDefeated;
  const tierKey = Math.min(Math.max(1, bossTier), 5);
  const expectedCount = CONFIG.meta.dropCount[tierKey][0];
  const expectedItem = ITEM_BY_TIER[minTierFor(bossTier)];
  const packTotal = Object.values(game.tempBackpack).reduce((sum, n) => sum + n, 0);
  assert(packTotal === expectedCount && game.tempBackpack[expectedItem.id] === expectedCount,
    '[13] 掉落应进入临时背包（' + expectedItem.name + '×' + expectedCount + '）');

  key('keydown', 'KeyC');
  key('keyup', 'KeyC');
  pump(1);
  assert(game.state === 'playing', '[13] 继续深入后应回到战斗，实际 ' + game.state);
  assert(game.waveDirector.phase === 'rest', '[13] 继续深入后应进入休整阶段');
  assert(game.tempBackpack[expectedItem.id] === expectedCount, '[13] 继续深入后背包应保留');

  // 下一个 Boss 波再次出现抉择（直接跳到第 10 波 Boss）
  game.pendingChoices = 0;
  game.enemies.length = 0;
  game.hostileProjectiles.length = 0;
  const nextBossWave = CONFIG.waves.bossEvery * 2;
  game.waveDirector.startWave(game, nextBossWave);
  const boss2 = new BossEnemy(game.player.x + 60, game.player.y, game.elapsed);
  game.enemies.push(boss2);
  game.waveDirector.bossSpawned = true;
  game.waveDirector.spawned = game.waveDirector.quota;
  Math.random = () => 0.99; // 本次不掉新材料
  game.damageEnemy(boss2, boss2.maxHp * 2);
  game.gems.length = 0;
  game.pickups.length = 0;
  pump(1);
  Math.random = origRandom;
  assert(game.state === 'extraction', '[13] 下个 Boss 波应再次出现抉择，实际 ' + game.state);
  assert(game.tempBackpack[expectedItem.id] === expectedCount, '[13] 之前的背包应仍保留');

  // 撤离收尾：第 10 波奖励 = 10×2，背包入库
  const dcBefore = game.save.darkCrystals;
  const storageBefore = game.save.storage[expectedItem.id];
  key('keydown', 'KeyE');
  key('keyup', 'KeyE');
  pump(1);
  assert(game.state === 'summary', '[13] 撤离后应进入结算，实际 ' + game.state);
  assert(game.save.darkCrystals === dcBefore + nextBossWave * CONFIG.meta.waveRewardMult, '[13] 第 10 波撤离奖励错误');
  assert(game.save.storage[expectedItem.id] === storageBefore + expectedCount, '[13] 背包材料应入库');
  assert(Object.values(game.tempBackpack).every((n) => n === 0), '[13] 撤离后临时背包应清空');
  key('keydown', 'Enter');
  key('keyup', 'Enter');
  pump(1);
  assert(game.state === 'menu', '[13] 确认结算应返回主菜单');
  console.log('[13] 继续深入 OK');
}

// ========== [14] 死亡损失：临时背包全损、仓库不受影响 ==========
{
  game.pendingChoices = 0;
  key('keydown', 'Enter');
  key('keyup', 'Enter');
  pump(1);
  pumpWithChoices(3);
  assert(game.state === 'playing', '[14] 选卡后应进入战斗，实际 ' + game.state);
  game.pendingChoices = 0;
  game.enemies.length = 0;

  game.tempBackpack = { shard: 2, essence: 1, soulCrystal: 1 };
  const storageBefore = { ...game.save.storage };
  const dcBefore = game.save.darkCrystals;

  game.player.hp = 1;
  game.player.iFrames = 0;
  game.hurtPlayer(999);
  game._handleCollisions();
  assert(game.state === 'dead', '[14] 空血应进入死亡，实际 ' + game.state);
  pump(1); // 渲染一帧死亡界面，验证 drawGameOver 损失展示
  assert(game.lastDeathLoss.shard === 2 && game.lastDeathLoss.essence === 1
    && game.lastDeathLoss.soulCrystal === 1, '[14] 死亡损失记录应为临时背包');
  assert(Object.values(game.tempBackpack).every((n) => n === 0), '[14] 死亡后临时背包应全损');
  assert(game.save.storage.shard === storageBefore.shard
    && game.save.storage.essence === storageBefore.essence
    && game.save.storage.soulCrystal === storageBefore.soulCrystal, '[14] 仓库不应受死亡影响');
  assert(game.save.darkCrystals === dcBefore, '[14] 暗晶不应受死亡影响');

  key('keydown', 'KeyR');
  key('keyup', 'KeyR');
  pump(1);
  assert(game.state === 'menu', '[14] 死亡后按 R 应返回主菜单，实际 ' + game.state);
  console.log('[14] 死亡损失 OK');
}

// ========== [15] 商城：价格曲线 / 购买 / 余额不足 / 满级 ==========
{
  assert(game.state === 'menu', '[15] 应从主菜单开始');
  const curve = [20, 32, 51, 82, 131, 210, 336, 537, 859, 1374];
  for (let k = 1; k <= SHOP_MAX_LEVEL; k++) {
    assert(priceForLevel(k) === curve[k - 1],
      '[15] 第 ' + k + ' 级价格应为 ' + curve[k - 1] + '，实际 ' + priceForLevel(k));
  }
  assert(priceForLevel(0) === 0, '[15] 低于 1 级的价格应为 0');

  game.openShop();
  assert(game.state === 'shop', '[15] 应进入商城，实际 ' + game.state);
  pump(1); // 渲染一帧商城界面，验证 drawShop 与 ctx 桩兼容

  game.save.darkCrystals = 500;
  assert(game.buyShopItem('damage') === true, '[15] 购买伤害 Lv1 应成功');
  assert(game.save.metaLevels.damage === 1 && game.save.darkCrystals === 480, '[15] Lv1 购买应扣 20 暗晶');
  assert(game.buyShopItem('damage') === true, '[15] 购买伤害 Lv2 应成功');
  assert(game.save.metaLevels.damage === 2 && game.save.darkCrystals === 448, '[15] Lv2 购买应扣 32 暗晶');
  assert(loadSave().metaLevels.damage === 2, '[15] 购买结果应写入存档');

  game.save.darkCrystals = 10;
  assert(game.buyShopItem('damage') === false, '[15] 余额不足应拒绝购买');
  assert(game.save.metaLevels.damage === 2 && game.save.darkCrystals === 10, '[15] 余额不足不应扣款或升级');

  game.save.metaLevels.armor = SHOP_MAX_LEVEL;
  game.save.darkCrystals = 99999;
  assert(game.buyShopItem('armor') === false, '[15] 满级应拒绝购买');
  assert(game.save.darkCrystals === 99999, '[15] 满级不应扣款');

  assert(game.buyShopItem('notExist') === false, '[15] 未知属性应拒绝购买');

  key('keydown', 'Escape');
  key('keyup', 'Escape');
  pump(1);
  assert(game.state === 'menu', '[15] Esc 应返回主菜单，实际 ' + game.state);
  const dcAtMenu = game.save.darkCrystals;
  assert(game.buyShopItem('xp') === false, '[15] 非商城状态应拒绝购买');
  assert(game.save.darkCrystals === dcAtMenu, '[15] 非商城状态不应扣款');
  console.log('[15] 商城 OK');
}

// ========== [16] 仓库卖出与局外属性生效 ==========
{
  game.save.storage = { shard: 4, essence: 2, soulCrystal: 1 };
  persistSave(game.save);
  game.openStorage();
  assert(game.state === 'storage', '[16] 应进入仓库，实际 ' + game.state);
  pump(1); // 渲染一帧仓库界面，验证 drawStorage 与 ctx 桩兼容

  // 单卖 = 卖出该材料全部存量
  const dcBefore = game.save.darkCrystals;
  assert(game.sellStorageItem('shard') === 4 * META_ITEMS.shard.sellPrice, '[16] 碎片单卖金额错误');
  assert(game.save.storage.shard === 0
    && game.save.darkCrystals === dcBefore + 4 * META_ITEMS.shard.sellPrice, '[16] 单卖结算错误');
  const expectedAll = 2 * META_ITEMS.essence.sellPrice + 1 * META_ITEMS.soulCrystal.sellPrice;
  assert(game.sellAllStorage() === expectedAll, '[16] 全卖金额错误');
  assert(game.save.storage.essence === 0 && game.save.storage.soulCrystal === 0, '[16] 全卖后仓库应清空');
  assert(game.save.darkCrystals === dcBefore + 4 * META_ITEMS.shard.sellPrice + expectedAll, '[16] 全卖结算错误');
  assert(game.sellStorageItem('shard') === 0 && game.sellAllStorage() === 0, '[16] 空仓库卖出应返回 0');
  assert(loadSave().darkCrystals === game.save.darkCrystals, '[16] 卖出收益应写入存档');

  key('keydown', 'Escape');
  key('keyup', 'Escape');
  pump(1);
  assert(game.state === 'menu', '[16] Esc 应返回主菜单');

  // 局外属性生效：每级等效 1 层局内属性卡
  game.save.metaLevels.damage = 3;
  game.save.metaLevels.maxHp = 2;
  game.save.metaLevels.magnet = 1;
  persistSave(game.save);
  key('keydown', 'Enter');
  key('keyup', 'Enter');
  pump(1);
  assert(game.state === 'opening', '[16] 应进入开局选卡，实际 ' + game.state);
  assert(game.metaStacks.damage === 3 && game.metaStacks.maxHp === 2 && game.metaStacks.magnet === 1,
    '[16] metaStacks 应继承存档局外等级');
  const closeTo = (actual, expected, message, epsilon = 1e-9) => {
    assert(Math.abs(actual - expected) <= epsilon, message + '（实际 ' + actual + '，期望 ' + expected + '）');
  };
  closeTo(game.mods.damageMult, 1 + 0.15 * 3, '[16] 伤害 Lv3 应提供 1.45 倍伤害');
  closeTo(game.mods.magnetRadiusBonus, 50, '[16] 拾取范围 Lv1 应提供 +50px 吸附');
  assert(game.player.maxHp === CONFIG.player.maxHp + 20 * 2, '[16] 生命 Lv2 应提供 +40 最大生命');
  assert(game.player.hp === game.player.maxHp, '[16] 生命加成应在开局全额回复');

  pumpWithChoices(3);
  assert(game.state === 'playing', '[16] 选卡后应进入战斗');
  assert(game.metaStacks.damage === 3, '[16] 局外等级应在战斗中保留');
  console.log('[16] 仓库卖出 / 局外属性生效 OK');
}

console.log('✅ 冒烟测试全部通过（卡牌、武器、波次、精英与 Boss、撤离抉择与局外商城）');
