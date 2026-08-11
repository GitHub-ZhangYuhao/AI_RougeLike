// 全局配置：所有平衡性数值集中在这里，方便调参
export const CONFIG = {
  view: { background: '#0e0e16', gridSize: 64 },

  player: {
    radius: 14,
    speed: 230,
    maxHp: 100,
    hurtIFrames: 0.8,   // 受击后的无敌时间（秒）
    color: '#4fc3f7',
  },

  camera: { lerp: 8 },  // 相机跟随平滑度，越大越紧跟

  spawner: {
    startInterval: 1.5,   // 开局刷怪间隔（秒）
    minInterval: 0.35,    // 后期最短刷怪间隔
    intervalRamp: 240,    // 间隔缩短到最短所需秒数
    startMaxAlive: 10,    // 开局同屏敌人上限
    maxAliveCap: 70,      // 后期同屏敌人上限
    maxAliveRamp: 300,
    spawnMargin: 80,      // 在屏幕外多远生成
  },

  enemy: {
    radius: 13,
    speed: 72,
    speedVariance: 0.3,   // 速度随机浮动 ±30%
    hp: 18,
    damage: 8,
    hpPerMin: 14,         // 每过 1 分钟，新刷出的敌人增加的血量
    damagePerMin: 2.5,
    speedPerMin: 0.05,    // 每过 1 分钟，新刷出的敌人速度 +5%
    separation: 60,       // 敌人互相推挤的力度
    color: '#ef5350',
  },

  // ---------- 卡牌系统 ----------
  cards: {
    maxWeaponSlots: 3,   // 玩家可同时持有的武器数（后续可扩展到 5，不写死）
    choicesCount: 3,     // 每次选择展示的卡牌数
    attrMaxStack: 5,     // 每张属性卡的最大叠加层数
  },

  // ---------- 经验宝石 ----------
  gems: {
    magnetRadius: 90,    // 吸附半径：进入后被吸向玩家
    pickupRadius: 20,    // 拾取接触半径
    cap: 300,            // 地上宝石上限（超出自动收取）
    tiers: [             // 宝石价值随时间提升
      { until: 90, value: 1, color: '#5ac8fa' },
      { until: 180, value: 2, color: '#66bb6a' },
      { until: Infinity, value: 3, color: '#ff8a65' },
    ],
  },

  // ---------- 经验曲线 ----------
  // 升到下一级所需经验 = base + (level - 1) * perLevel
  xp: { base: 6, perLevel: 4 },

  // ---------- 击杀日志 / 尸体 / 掉落 ----------
  killLog: { cap: 256 },          // 击杀日志环形缓冲长度（武器按 id 增量消费）
  corpses: { stainTtl: 3, cap: 80 }, // 视觉血迹：存活秒数 / 同屏上限
  pickups: {
    hpValue: 15,     // 血包回复量
    pickupRadius: 22, // 拾取接触半径（不吸附，走过去才捡）
    maxAlive: 5,     // 同屏血包上限
  },
  hud: { font: '16px "Segoe UI", "Microsoft YaHei", sans-serif' },
};
