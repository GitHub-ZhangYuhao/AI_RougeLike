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
    startInterval: 1.35,
    minInterval: 0.28,
    intervalPerWave: 0.09,
    startMaxAlive: 12,
    maxAlivePerWave: 4,
    maxAliveCap: 60,
    spawnMargin: 80,
  },

  enemy: {
    radius: 13,
    speed: 72,
    speedVariance: 0.3,
    hp: 18,
    damage: 8,
    hpPerMin: 14,
    damagePerMin: 2.5,
    speedPerMin: 0.05,
    hpPerWave: 0.12,
    damagePerWave: 0.07,
    speedPerWave: 0.015,
    speedWaveCap: 0.25,
    separation: 60,
    color: '#ef5350',
  },

  enemyTypes: {
    chaser: {
      unlockAt: 0, weight: 62, maxAlive: Infinity,
    },
    enhancedChaser: {
      unlockAt: 0, weight: 0, maxAlive: Infinity,
      hpMult: 1.8, speedMult: 0.95, damageMult: 1.3,
      enrageHpRatio: 0.5, warningDuration: 0.45,
      enragedSpeedMult: 1.35, enragedDamageMult: 1.35,
    },
    charger: {
      unlockAt: 15, weight: 18, maxAlive: 8,
      hpMult: 1.15, speedMult: 0.95, damageMult: 1.1,
      chargeRange: 260, windup: 0.65, dashSpeed: 320,
      dashDuration: 0.55, recovery: 0.85, cooldown: 2.4,
    },
    ranged: {
      unlockAt: 25, weight: 7, maxAlive: 4,
      hpMult: 0.8, speedMult: 0.8, damageMult: 0.75,
      preferredDistance: 260, retreatDistance: 170,
      fireInterval: 2.2, projectileSpeed: 155,
      projectileRadius: 5, projectileLifetime: 4,
    },
    bomber: {
      unlockAt: 35, weight: 10, maxAlive: 6,
      hpMult: 0.75, speedMult: 1.15, damageMult: 1.45,
      triggerDistance: 58, windup: 0.9, blastRadius: 78,
    },
    shield: {
      unlockAt: 50, weight: 3, maxAlive: 1,
      hpMult: 2, speedMult: 0.72, damageMult: 1.15,
      shieldDuration: 3, openDuration: 1.5,
      shieldDamageMult: 0.4, openDamageMult: 1.25,
    },
    boss: {
      unlockAt: 0, weight: 0, maxAlive: 1,
      hpMult: 18, speedMult: 0.58, damageMult: 2.1,
      radius: 34, attackInterval: 3.2, windup: 0.85,
      projectileCount: 10, projectileSpeed: 165,
      projectileRadius: 7, projectileLifetime: 5,
      enragedHpRatio: 0.5, enragedProjectileCount: 14,
      enragedProjectileSpeed: 205,
    },
  },

  // 离散波次：每波数量有限，清场后休整，不再无限持续刷怪。
  waves: {
    baseQuota: 12,
    quotaPerWave: 5,
    quotaCap: 80,
    restDuration: 6,
    bossEvery: 5,
    eliteEvery: 3,
    bannerDuration: 2.4,
  },

  cards: {
    maxWeaponSlots: 3,
    choicesCount: 3,
    attrMaxStack: 5,
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
};
