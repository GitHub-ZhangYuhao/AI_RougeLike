// 全局配置：所有平衡性数值集中在这里，方便调参
export const CONFIG = {
  view: { background: '#0e0e16', gridSize: 64 },

  player: {
    radius: 14,
    speed: 230,
    maxHp: 100,
    hurtIFrames: 0.8,
    color: '#4fc3f7',
  },

  camera: { lerp: 8 },

  spawner: {
    startInterval: 1.0,
    minInterval: 0.14,
    intervalPerWave: 0.12,
    startMaxAlive: 20,
    maxAlivePerWave: 8,
    maxAliveCap: 140,
    spawnMargin: 80,
  },

  enemy: {
    radius: 13,
    speed: 85,
    baseSpeedMult: 1.5,
    speedVariance: 0.25,
    hp: 50,
    damage: 7,
    hpPerMin: 54,
    damagePerMin: 2.2,
    speedPerMin: 0.08,
    hpPerWave: 0.16,
    damagePerWave: 0.06,
    midWaveStart: 7,
    hpPerWaveMid: 0.30,
    damagePerWaveMid: 0.14,
    lateWaveStart: 12,
    hpPerWaveLate: 0.28,
    damagePerWaveLate: 0.18,
    hpWaveCap: 7,
    speedWaveCap: 2,
    speedCapStartWave: 20,
    separation: 60,
    color: '#ef5350',
  },

  enemyTypes: {
    chaser: {
      unlockAt: 0, weight: 62, maxAlive: Infinity,
    },
    enhancedChaser: {
      unlockAt: 0, weight: 0, maxAlive: Infinity,
      hpMult: 2.2, speedMult: 1.05, damageMult: 1.45,
      enrageHpRatio: 0.5, warningDuration: 0.45,
      enragedSpeedMult: 1.5, enragedDamageMult: 1.35,
    },
    charger: {
      unlockAt: 45, weight: 18, maxAlive: 8,
      hpMult: 1.7, speedMult: 1.05, damageMult: 1.1,
      chargeRange: 260, windup: 0.65, dashSpeed: 400,
      dashDuration: 0.55, recovery: 0.85, cooldown: 1.7,
    },
    ranged: {
      unlockAt: 90, weight: 11, maxAlive: 8,
      hpMult: 0.8, speedMult: 0.8, damageMult: 0.95,
      preferredDistance: 260, retreatDistance: 170,
      fireInterval: 1.7, projectileSpeed: 175,
      projectileRadius: 5, projectileLifetime: 4,
    },
    bomber: {
      unlockAt: 135, weight: 14, maxAlive: 6,
      hpMult: 0.85, speedMult: 1.25, damageMult: 1.6,
      triggerDistance: 58, windup: 0.9, blastRadius: 88,
    },
    shield: {
      unlockAt: 180, weight: 4, maxAlive: 1,
      hpMult: 2.6, speedMult: 0.8, damageMult: 1.15,
      shieldDuration: 3, openDuration: 1.5,
      shieldDamageMult: 0.35, openDamageMult: 1.25,
    },
    boss: {
      unlockAt: 0, weight: 0, maxAlive: 1,
      hpMult: 24, speedMult: 0.68, damageMult: 2.4,
      radius: 34, attackInterval: 2.9, windup: 0.85,
      projectileCount: 12, projectileSpeed: 180,
      projectileRadius: 7, projectileLifetime: 5,
      enragedHpRatio: 0.5, enragedProjectileCount: 18,
      enragedProjectileSpeed: 205,
    },
  },

  // Timed waves: each wave lasts 90 seconds; quota controls spawn density only.
  waves: {
    maxWave: 25,
    duration: 90,
    baseQuota: 16,
    quantityPerWave: 0.5,
    quantityWaveCap: 11.25,
    restDuration: 3.5,
    bossEvery: 5,
    eliteEvery: 3,
    bannerDuration: 2.4,
  },

  cards: {
    maxWeaponSlots: 3,
    choicesCount: 3,
    attrMaxStack: 5,
  },

  tasks: {
    waves: [3, 8, 13, 18, 23],
    triggerWindow: [35, 45],
    offerDuration: 12,
    acceptDuration: 1,
    beaconRadius: 60,
    beaconDistance: [300, 440],
    resultDuration: 3.5,
    guard: {
      durations: [18, 20, 22, 24, 26],
      radii: [130, 125, 120, 115, 110],
      leaveGrace: [1, 1, 0.9, 0.9, 0.8],
    },
    delivery: {
      distances: [[1500, 1750], [1600, 1850], [1700, 1950], [1800, 2050], [1900, 2200]],
      timeLimits: [22, 22, 21, 21, 20],
      interceptorCounts: [[1, 2], [2, 2], [2, 2], [2, 3], [3, 3]],
      interceptorIntervals: [6, 5.5, 5, 4.5, 4],
      destinationRadius: 72,
    },
    bounty: {
      spawnDistance: [450, 650],
      hpMultipliers: [2.5, 3, 3.5, 4, 4.5],
      damageMultipliers: [1.1, 1.15, 1.2, 1.25, 1.3],
      timeLimits: [40, 40, 38, 38, 36],
    },
    rewards: {
      choicesCount: 3,
      weights: { weapon: 0.4, stat: 0.35, blessing: 0.25 },
    },
  },

  gems: {
    magnetRadius: 180,
    magnetStartSpeed: 300,
    magnetAcceleration: 900,
    magnetMaxSpeed: 680,
    pickupRadius: 22,
    cap: 300,
    tiers: [
      { until: 90, value: 1, color: '#5ac8fa' },
      { until: 180, value: 2, color: '#66bb6a' },
      { until: Infinity, value: 3, color: '#ff8a65' },
    ],
  },

  xp: { base: 6, perLevel: 4 },

  killLog: { cap: 256 },
  corpses: { stainTtl: 3, cap: 80 },
  pickups: {
    hpValue: 15,
    pickupRadius: 22,
    rarePickupRadius: 30,
    maxAlive: 5,
  },
  hud: { font: '16px "Segoe UI", "Microsoft YaHei", sans-serif' },
  meta: {
    dropChance: { base: 0.08, perTier: 0.03, cap: 0.20 },
    tierWeights: { 1: [100, 0, 0], 2: [70, 30, 0], 3: [45, 45, 10], 4: [25, 45, 30], 5: [10, 40, 50] }, // 权重对应 [T1,T2,T3]；5 阶及以上 Boss 一律用第 5 档
    dropCount: { 1: [1, 1], 2: [1, 1], 3: [1, 2], 4: [1, 2], 5: [2, 2] }, // [min,max]；5 阶及以上用第 5 档
    guaranteedMinTier: { 3: 2, 5: 3 }, // Boss 阶位 → 保底最低材料阶（取 ≤bossTier 的最大键；1~2 阶无保底即 1）
    waveRewardMult: 1.5,
    shopMaxLevel: 10,
    shopPrice: { base: 20, growth: 1.6 },
    saveKey: 'ai-roguelike-meta-save-v1',
  },
};
