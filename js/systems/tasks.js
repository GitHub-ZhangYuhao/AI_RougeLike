import { CONFIG } from '../config.js';
import { WEAPON_CARDS } from '../cards.js';
import { createEnemyByType } from '../enemies/index.js';

const TASK_TYPES = ['guard', 'delivery', 'bounty'];
const TASK_NAMES = {
  guard: '\u533a\u57df\u5b88\u62a4',
  delivery: '\u7d27\u6025\u8fd0\u9001',
  bounty: '\u60ac\u8d4f\u8ba8\u4f10',
};

function clampRandom(rng) {
  return Math.max(0, Math.min(0.999999, Number(rng()) || 0));
}

function randomRange(rng, min, max) {
  return min + (max - min) * clampRandom(rng);
}

function randomInt(rng, min, max) {
  return Math.floor(randomRange(rng, min, max + 1));
}

function pointAround(origin, distance, rng) {
  const angle = randomRange(rng, 0, Math.PI * 2);
  return {
    x: origin.x + Math.cos(angle) * distance,
    y: origin.y + Math.sin(angle) * distance,
  };
}

function tierValue(values, tier) {
  return values[Math.max(0, Math.min(values.length - 1, tier - 1))];
}

function removeAtRandom(pool, rng) {
  if (pool.length === 0) return null;
  return pool.splice(Math.floor(clampRandom(rng) * pool.length), 1)[0];
}

function weightedCategory(pools, rng) {
  const weights = CONFIG.tasks.rewards.weights;
  const available = Object.keys(pools).filter((key) => pools[key].length > 0);
  const total = available.reduce((sum, key) => sum + weights[key], 0);
  if (total <= 0) return available[0] ?? null;
  let roll = clampRandom(rng) * total;
  for (const key of available) {
    roll -= weights[key];
    if (roll < 0) return key;
  }
  return available.at(-1) ?? null;
}

function makeRewardCard(id, name, icon, desc) {
  return { id, kind: 'taskReward', name, icon, desc };
}

function weaponRewardPool(game) {
  const pool = [];
  for (const weapon of game.weapons) {
    if (weapon.level >= weapon.card.maxLevel) continue;
    pool.push({
      type: 'taskWeapon',
      card: makeRewardCard(
        `task-weapon-${weapon.card.id}`,
        `\u5f3a\u5316\u00b7${weapon.card.name}`,
        weapon.card.icon,
        `\u7acb\u5373\u5c06 ${weapon.card.name} \u4ece Lv${weapon.level} \u63d0\u5347\u81f3 Lv${weapon.level + 1}`,
      ),
      levelInfo: `Lv ${weapon.level} \u2192 Lv ${weapon.level + 1}`,
      apply(targetGame) {
        const owned = targetGame.weapons.find((entry) => entry.card.id === weapon.card.id);
        if (owned && owned.level < owned.card.maxLevel) owned.level++;
        targetGame.synergies.refresh(targetGame.weapons, targetGame.elapsed);
      },
    });
  }

  if (game.weapons.length < CONFIG.cards.maxWeaponSlots) {
    for (const card of WEAPON_CARDS) {
      if (game.weapons.some((weapon) => weapon.card.id === card.id)) continue;
      pool.push({
        type: 'taskWeapon',
        card: makeRewardCard(
          `task-weapon-new-${card.id}`,
          `\u6b66\u88c5\u00b7${card.name}`,
          card.icon,
          `\u7acb\u5373\u83b7\u5f97 ${card.name} Lv1\uff0c\u4e0d\u5360\u7528\u666e\u901a\u5347\u7ea7\u6b21\u6570`,
        ),
        levelInfo: '\u83b7\u5f97 Lv 1',
        apply(targetGame) {
          if (targetGame.weapons.length >= CONFIG.cards.maxWeaponSlots) return;
          if (targetGame.weapons.some((weapon) => weapon.card.id === card.id)) return;
          targetGame.weapons.push(card.create());
          targetGame.synergies.refresh(targetGame.weapons, targetGame.elapsed);
        },
      });
    }
  }
  return pool;
}

function statRewardPool() {
  return [
    {
      type: 'taskStat',
      card: makeRewardCard('task-stat-damage', '\u5f3a\u653b', '\u2694\ufe0f', '\u672c\u5c40\u6b66\u5668\u4f24\u5bb3\u989d\u5916 +30%'),
      levelInfo: '\u4f24\u5bb3 +30%',
      apply(game) { game.taskBonuses.damageMult += 0.3; game.recomputeMods(); },
    },
    {
      type: 'taskStat',
      card: makeRewardCard('task-stat-armor', '\u94c1\u58c1', '\ud83d\udee1\ufe0f', '\u672c\u5c40\u62a4\u7532 +30'),
      levelInfo: '\u62a4\u7532 +30',
      apply(game) { game.taskBonuses.armor += 30; game.recomputeMods(); },
    },
    {
      type: 'taskStat',
      card: makeRewardCard('task-stat-magnet', '\u805a\u7075', '\ud83e\uddf2', '\u672c\u5c40\u7ecf\u9a8c\u62fe\u53d6\u8303\u56f4 +100px'),
      levelInfo: '\u62fe\u53d6\u8303\u56f4 +100px',
      apply(game) { game.taskBonuses.magnetRadiusBonus += 100; game.recomputeMods(); },
    },
    {
      type: 'taskStat',
      card: makeRewardCard('task-stat-xp', '\u609f\u9053', '\ud83d\udcd6', '\u672c\u5c40\u7ecf\u9a8c\u83b7\u53d6\u989d\u5916 +30%'),
      levelInfo: '\u7ecf\u9a8c +30%',
      apply(game) { game.taskBonuses.xpMult += 0.3; game.recomputeMods(); },
    },
    {
      type: 'taskStat',
      card: makeRewardCard('task-stat-hp', '\u8840\u5951', '\u2764\ufe0f', '\u6700\u5927\u751f\u547d +40\uff0c\u5e76\u7acb\u5373\u6062\u590d 40'),
      levelInfo: '\u6700\u5927\u751f\u547d +40',
      apply(game) { game.increaseMaxHp(40, 40); },
    },
    {
      type: 'taskStat',
      card: makeRewardCard('task-stat-speed', '\u75be\u98ce', '\ud83d\udc5f', '\u672c\u5c40\u79fb\u52a8\u901f\u5ea6\u989d\u5916 +12%'),
      levelInfo: '\u79fb\u901f +12%',
      apply(game) { game.taskBonuses.moveSpeedMult += 0.12; game.recomputeMods(); },
    },
  ];
}

function blessingRewardPool(game) {
  const definitions = [
    {
      id: 'hunter', name: '\u730e\u6740\u795d\u798f', icon: '\ud83c\udfaf', desc: '\u5bf9\u7cbe\u82f1\u4e0e Boss \u4f24\u5bb3 +25%',
      levelInfo: '\u7cbe\u82f1/Boss \u4f24\u5bb3 +25%',
      apply(targetGame) { targetGame.taskBonuses.eliteBossDamageMult += 0.25; },
    },
    {
      id: 'tenacity', name: '\u575a\u97e7\u795d\u798f', icon: '\u2728', desc: '\u6700\u5927\u751f\u547d +25\u3001\u62a4\u7532 +20\uff0c\u5e76\u6062\u590d 25',
      levelInfo: '\u751f\u547d +25 \u00b7 \u62a4\u7532 +20',
      apply(targetGame) {
        targetGame.taskBonuses.armor += 20;
        targetGame.increaseMaxHp(25, 25);
        targetGame.recomputeMods();
      },
    },
    {
      id: 'swift-hunt', name: '\u75be\u730e\u795d\u798f', icon: '\ud83d\udca8', desc: '\u79fb\u52a8\u901f\u5ea6 +10%\uff0c\u62fe\u53d6\u8303\u56f4 +80px',
      levelInfo: '\u79fb\u901f +10% \u00b7 \u62fe\u53d6 +80px',
      apply(targetGame) {
        targetGame.taskBonuses.moveSpeedMult += 0.1;
        targetGame.taskBonuses.magnetRadiusBonus += 80;
        targetGame.recomputeMods();
      },
    },
    {
      id: 'insight', name: '\u7075\u609f\u795d\u798f', icon: '\ud83c\udf1f', desc: '\u7ecf\u9a8c\u83b7\u53d6 +25%\uff0c\u6b66\u5668\u4f24\u5bb3 +10%',
      levelInfo: '\u7ecf\u9a8c +25% \u00b7 \u4f24\u5bb3 +10%',
      apply(targetGame) {
        targetGame.taskBonuses.xpMult += 0.25;
        targetGame.taskBonuses.damageMult += 0.1;
        targetGame.recomputeMods();
      },
    },
    {
      id: 'battle-spirit', name: '\u6218\u610f\u795d\u798f', icon: '\ud83d\udd25', desc: '\u6b66\u5668\u4f24\u5bb3 +20%\uff0c\u79fb\u52a8\u901f\u5ea6 +6%',
      levelInfo: '\u4f24\u5bb3 +20% \u00b7 \u79fb\u901f +6%',
      apply(targetGame) {
        targetGame.taskBonuses.damageMult += 0.2;
        targetGame.taskBonuses.moveSpeedMult += 0.06;
        targetGame.recomputeMods();
      },
    },
  ];

  return definitions
    .filter((definition) => !game.taskBlessings.has(definition.id))
    .map((definition) => ({
      type: 'taskBlessing',
      card: makeRewardCard(
        `task-blessing-${definition.id}`,
        definition.name,
        definition.icon,
        definition.desc,
      ),
      levelInfo: definition.levelInfo,
      apply(targetGame) {
        if (targetGame.taskBlessings.has(definition.id)) return;
        targetGame.taskBlessings.add(definition.id);
        definition.apply(targetGame);
      },
    }));
}

export function generateTaskRewardOffers(game, rng = Math.random) {
  const pools = {
    weapon: weaponRewardPool(game),
    stat: statRewardPool(),
    blessing: blessingRewardPool(game),
  };
  const offers = [];
  while (offers.length < CONFIG.tasks.rewards.choicesCount) {
    const category = weightedCategory(pools, rng);
    if (!category) break;
    const offer = removeAtRandom(pools[category], rng);
    if (offer) offers.push(offer);
  }
  return offers;
}

export class TaskDirector {
  constructor(options = {}) {
    this.rng = options.rng ?? Math.random;
    this.reset();
  }

  reset() {
    this.current = null;
    this.scheduledWave = null;
    this.triggerAt = null;
    this.lastTaskType = null;
    this.nextTaskId = 1;
    this.completedWaves = new Set();
  }

  setRng(rng) {
    this.rng = rng ?? Math.random;
  }

  update(dt, game) {
    const director = game.waveDirector;
    if (!director) return;
    this._syncWave(game, director.wave);

    if (this.current?.state === 'result') {
      this.current.resultRemaining -= dt;
      if (this.current.resultRemaining <= 0) this.current = null;
      return;
    }

    if (
      !this.current
      && this.scheduledWave === director.wave
      && !this.completedWaves.has(director.wave)
      && Number.isFinite(this.triggerAt)
      && director.phase === 'wave'
    ) {
      const waveElapsed = CONFIG.waves.duration - director.timeRemaining;
      if (waveElapsed >= this.triggerAt) this._createOffer(game, director.wave);
    }

    if (!this.current) return;
    if (this.current.wave !== director.wave || director.phase !== 'wave') {
      if (this.current.state === 'active') this._fail(game, '\u6ce2\u6b21\u7ed3\u675f\uff0c\u4efb\u52a1\u5931\u8d25');
      else this._finishResult(game, 'expired', '\u4efb\u52a1\u4fe1\u6807\u5df2\u6d88\u5931');
      return;
    }

    if (this.current.state === 'offered') this._updateOffer(dt, game);
    else if (this.current.state === 'active') this._updateActive(dt, game);
  }

  onEnemyKilled(enemy, game) {
    const task = this.current;
    if (!task || task.state !== 'active' || task.type !== 'bounty') return;
    if (enemy.taskId !== task.id || enemy.taskRole !== 'bountyTarget') return;
    this._succeed(game);
  }

  _syncWave(game, wave) {
    if (this.scheduledWave === wave || this.completedWaves.has(wave)) return;
    if (!CONFIG.tasks.waves.includes(wave)) {
      this.scheduledWave = wave;
      this.triggerAt = null;
      return;
    }
    this.scheduledWave = wave;
    const [min, max] = CONFIG.tasks.triggerWindow;
    this.triggerAt = randomRange(this.rng, min, max);
  }

  _createOffer(game, wave) {
    const tier = CONFIG.tasks.waves.indexOf(wave) + 1;
    const choices = TASK_TYPES.filter((type) => type !== this.lastTaskType);
    const type = choices[Math.floor(clampRandom(this.rng) * choices.length)] ?? TASK_TYPES[0];
    const [minDistance, maxDistance] = CONFIG.tasks.beaconDistance;
    const beacon = pointAround(game.player, randomRange(this.rng, minDistance, maxDistance), this.rng);
    this.lastTaskType = type;
    this.completedWaves.add(wave);
    this.triggerAt = null;
    this.current = {
      id: this.nextTaskId++,
      type,
      tier,
      wave,
      state: 'offered',
      beacon,
      offerRemaining: CONFIG.tasks.offerDuration,
      acceptProgress: 0,
      payload: {},
    };
  }

  _updateOffer(dt, game) {
    const task = this.current;
    const radius = CONFIG.tasks.beaconRadius;
    const dx = game.player.x - task.beacon.x;
    const dy = game.player.y - task.beacon.y;
    if (dx * dx + dy * dy <= radius * radius) task.acceptProgress += dt;
    else task.acceptProgress = 0;

    if (task.acceptProgress >= CONFIG.tasks.acceptDuration) {
      this._activate(game);
      return;
    }
    task.offerRemaining -= dt;
    if (task.offerRemaining <= 0) this._finishResult(game, 'expired', '\u672a\u5728\u65f6\u9650\u5185\u63a5\u53d6\u4efb\u52a1');
  }

  _activate(game) {
    const task = this.current;
    task.state = 'active';
    if (task.type === 'guard') {
      task.payload = {
        center: { ...task.beacon },
        duration: tierValue(CONFIG.tasks.guard.durations, task.tier),
        remaining: tierValue(CONFIG.tasks.guard.durations, task.tier),
        radius: tierValue(CONFIG.tasks.guard.radii, task.tier),
        leaveGrace: tierValue(CONFIG.tasks.guard.leaveGrace, task.tier),
        outsideFor: 0,
      };
    } else if (task.type === 'delivery') {
      const distanceRange = tierValue(CONFIG.tasks.delivery.distances, task.tier);
      task.payload = {
        destination: pointAround(
          task.beacon,
          randomRange(this.rng, distanceRange[0], distanceRange[1]),
          this.rng,
        ),
        timeRemaining: tierValue(CONFIG.tasks.delivery.timeLimits, task.tier),
        interceptorTimer: tierValue(CONFIG.tasks.delivery.interceptorIntervals, task.tier),
      };
    } else {
      const [minDistance, maxDistance] = CONFIG.tasks.bounty.spawnDistance;
      const position = pointAround(game.player, randomRange(this.rng, minDistance, maxDistance), this.rng);
      const type = this._bountyEnemyType(task.tier);
      const target = createEnemyByType(type, position.x, position.y, game.elapsed, task.wave);
      const hpMultiplier = tierValue(CONFIG.tasks.bounty.hpMultipliers, task.tier);
      target.maxHp *= hpMultiplier;
      target.hp = target.maxHp;
      target.damage *= tierValue(CONFIG.tasks.bounty.damageMultipliers, task.tier);
      target.taskId = task.id;
      target.taskRole = 'bountyTarget';
      target.suppressRareDrop = true;
      target.name = '\u60ac\u8d4f\u76ee\u6807';
      game.enemies.push(target);
      task.payload = {
        target,
        timeRemaining: tierValue(CONFIG.tasks.bounty.timeLimits, task.tier),
      };
    }
  }

  _updateActive(dt, game) {
    const task = this.current;
    if (task.type === 'guard') this._updateGuard(dt, game, task);
    else if (task.type === 'delivery') this._updateDelivery(dt, game, task);
    else this._updateBounty(dt, game, task);
  }

  _updateGuard(dt, game, task) {
    const payload = task.payload;
    const dx = game.player.x - payload.center.x;
    const dy = game.player.y - payload.center.y;
    if (dx * dx + dy * dy > payload.radius * payload.radius) payload.outsideFor += dt;
    else payload.outsideFor = 0;
    if (payload.outsideFor > payload.leaveGrace) {
      this._fail(game, '\u79bb\u5f00\u5b88\u62a4\u533a\u57df\uff0c\u4efb\u52a1\u5931\u8d25');
      return;
    }
    payload.remaining -= dt;
    if (payload.remaining <= 0) this._succeed(game);
  }

  _updateDelivery(dt, game, task) {
    const payload = task.payload;
    const dx = game.player.x - payload.destination.x;
    const dy = game.player.y - payload.destination.y;
    const radius = CONFIG.tasks.delivery.destinationRadius;
    if (dx * dx + dy * dy <= radius * radius) {
      this._succeed(game);
      return;
    }
    payload.timeRemaining -= dt;
    payload.interceptorTimer -= dt;
    if (payload.interceptorTimer <= 0) {
      this._spawnInterceptors(game, task.tier, task.id);
      payload.interceptorTimer += tierValue(CONFIG.tasks.delivery.interceptorIntervals, task.tier);
    }
    if (payload.timeRemaining <= 0) this._fail(game, '\u8fd0\u9001\u8d85\u65f6\uff0c\u4efb\u52a1\u5931\u8d25');
  }

  _updateBounty(dt, game, task) {
    const payload = task.payload;
    payload.timeRemaining -= dt;
    if (payload.timeRemaining <= 0) {
      if (payload.target && !payload.target.dead) payload.target.dead = true;
      this._fail(game, '\u672a\u80fd\u53ca\u65f6\u51fb\u8d25\u60ac\u8d4f\u76ee\u6807');
    }
  }

  _spawnInterceptors(game, tier, taskId) {
    const countRange = tierValue(CONFIG.tasks.delivery.interceptorCounts, tier);
    const count = randomInt(this.rng, countRange[0], countRange[1]);
    const type = tier <= 1 ? 'chaser' : tier <= 3 ? 'enhancedChaser' : 'charger';
    for (let i = 0; i < count; i++) {
      const position = pointAround(game.player, randomRange(this.rng, 240, 340), this.rng);
      const enemy = createEnemyByType(type, position.x, position.y, game.elapsed, game.waveDirector.wave);
      enemy.taskId = taskId;
      enemy.taskRole = 'interceptor';
      enemy.suppressRareDrop = true;
      game.enemies.push(enemy);
    }
  }

  _bountyEnemyType(tier) {
    if (tier === 1) return 'enhancedChaser';
    if (tier === 2) return clampRandom(this.rng) < 0.5 ? 'enhancedChaser' : 'charger';
    return clampRandom(this.rng) < 0.5 ? 'charger' : 'shield';
  }

  _succeed(game) {
    const offers = generateTaskRewardOffers(game, this.rng);
    if (offers.length > 0) game.queueTaskReward(offers);
    this._finishResult(game, 'succeeded', '\u4efb\u52a1\u5b8c\u6210\uff0c\u83b7\u5f97\u5f3a\u529b\u5956\u52b1');
  }

  _fail(game, message) {
    this._finishResult(game, 'failed', message);
  }

  _finishResult(game, outcome, message) {
    const previous = this.current;
    this.current = {
      ...previous,
      state: 'result',
      outcome,
      message,
      resultRemaining: CONFIG.tasks.resultDuration,
    };
  }

  drawWorld(ctx, game) {
    const task = this.current;
    if (!task || task.state === 'result') return;
    if (task.state === 'offered') {
      this._drawBeacon(ctx, task.beacon, '#ffd54f', task.acceptProgress / CONFIG.tasks.acceptDuration, game.elapsed);
      return;
    }
    if (task.type === 'guard') {
      const { center, radius } = task.payload;
      ctx.save();
      ctx.fillStyle = 'rgba(102, 187, 106, 0.10)';
      ctx.strokeStyle = '#81c784';
      ctx.lineWidth = 4;
      ctx.setLineDash([12, 8]);
      ctx.beginPath();
      ctx.arc(center.x, center.y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    } else if (task.type === 'delivery') {
      this._drawBeacon(ctx, task.payload.destination, '#4dd0e1', 0, game.elapsed);
    } else {
      const target = task.payload.target;
      if (!target || target.dead) return;
      ctx.save();
      ctx.strokeStyle = '#ff5252';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(target.x, target.y, target.radius + 15, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = '#ff8a80';
      ctx.font = 'bold 22px "Segoe UI Symbol", sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('\u25c6', target.x, target.y - target.radius - 22);
      ctx.restore();
    }
  }

  drawHUD(ctx, viewW, viewH, game) {
    const task = this.current;
    if (!task) return;
    ctx.save();
    if (task.state === 'result') {
      ctx.textAlign = 'center';
      ctx.font = 'bold 20px "Segoe UI", "Microsoft YaHei", sans-serif';
      ctx.fillStyle = task.outcome === 'succeeded' ? '#81c784' : '#ff8a80';
      ctx.fillText(task.message, viewW / 2, viewH * 0.36);
      ctx.restore();
      return;
    }

    const width = Math.min(330, viewW * 0.38);
    const x = viewW - width - 14;
    const y = 78;
    ctx.fillStyle = 'rgba(8, 12, 22, 0.82)';
    ctx.fillRect(x, y, width, 82);
    ctx.strokeStyle = task.state === 'offered' ? '#ffd54f' : '#4dd0e1';
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 0.5, y + 0.5, width - 1, 81);
    ctx.textAlign = 'left';
    ctx.font = 'bold 16px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = '#ffffff';
    ctx.fillText(`\u4efb\u52a1 \u00b7 ${TASK_NAMES[task.type]} \u00b7 T${task.tier}`, x + 12, y + 23);
    ctx.font = '14px "Segoe UI", "Microsoft YaHei", sans-serif';
    ctx.fillStyle = '#e0e0e0';
    const detail = this._hudDetail(task, game);
    ctx.fillText(detail, x + 12, y + 48);
    if (task.state === 'offered') {
      const progress = Math.min(1, task.acceptProgress / CONFIG.tasks.acceptDuration);
      ctx.fillStyle = 'rgba(255,255,255,0.14)';
      ctx.fillRect(x + 12, y + 60, width - 24, 8);
      ctx.fillStyle = '#ffd54f';
      ctx.fillRect(x + 12, y + 60, (width - 24) * progress, 8);
    }
    const target = this._navigationTarget(task);
    if (target) this._drawDirectionArrow(ctx, target, viewW, viewH, game.camera);
    ctx.restore();
  }

  _hudDetail(task, game) {
    if (task.state === 'offered') {
      return `\u8fdb\u5165\u4fe1\u6807\u505c\u7559 1 \u79d2\u63a5\u53d6 \u00b7 \u5269\u4f59 ${Math.max(0, task.offerRemaining).toFixed(1)}s`;
    }
    if (task.type === 'guard') {
      const payload = task.payload;
      if (payload.outsideFor > 0) return `\u8fd4\u56de\u533a\u57df\uff01\u5bbd\u9650 ${Math.max(0, payload.leaveGrace - payload.outsideFor).toFixed(1)}s`;
      return `\u5b88\u4f4f\u533a\u57df ${Math.max(0, payload.remaining).toFixed(1)}s`;
    }
    if (task.type === 'delivery') {
      const payload = task.payload;
      const distance = Math.hypot(game.player.x - payload.destination.x, game.player.y - payload.destination.y);
      return `\u62b5\u8fbe\u4ea4\u4ed8\u70b9 \u00b7 ${Math.ceil(distance)}px \u00b7 \u5269\u4f59 ${Math.max(0, payload.timeRemaining).toFixed(1)}s`;
    }
    const payload = task.payload;
    const target = payload.target;
    const hpRatio = target ? Math.max(0, target.hp / target.maxHp) : 0;
    return `\u51fb\u8d25\u76ee\u6807 \u00b7 HP ${Math.ceil(hpRatio * 100)}% \u00b7 \u5269\u4f59 ${Math.max(0, payload.timeRemaining).toFixed(1)}s`;
  }

  _navigationTarget(task) {
    if (task.state === 'offered') return task.beacon;
    if (task.type === 'delivery') return task.payload.destination;
    if (task.type === 'bounty') return task.payload.target;
    return null;
  }

  _drawBeacon(ctx, point, color, progress, elapsed) {
    const pulse = 1 + Math.sin(elapsed * 5) * 0.08;
    ctx.save();
    ctx.strokeStyle = color;
    ctx.fillStyle = `${color}22`;
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(point.x, point.y, CONFIG.tasks.beaconRadius * pulse, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(point.x, point.y - 25);
    ctx.lineTo(point.x, point.y + 25);
    ctx.moveTo(point.x - 25, point.y);
    ctx.lineTo(point.x + 25, point.y);
    ctx.stroke();
    if (progress > 0) {
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 7;
      ctx.beginPath();
      ctx.arc(point.x, point.y, CONFIG.tasks.beaconRadius + 9, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, progress));
      ctx.stroke();
    }
    ctx.restore();
  }

  _drawDirectionArrow(ctx, target, viewW, viewH, camera) {
    if (!target || !camera) return;
    const screenX = target.x - camera.x + viewW / 2;
    const screenY = target.y - camera.y + viewH / 2;
    const margin = 42;
    if (screenX >= margin && screenX <= viewW - margin && screenY >= margin && screenY <= viewH - margin) return;
    const dx = screenX - viewW / 2;
    const dy = screenY - viewH / 2;
    const angle = Math.atan2(dy, dx);
    const scale = Math.min(
      (viewW / 2 - margin) / Math.max(1, Math.abs(dx)),
      (viewH / 2 - margin) / Math.max(1, Math.abs(dy)),
    );
    const x = viewW / 2 + dx * scale;
    const y = viewH / 2 + dy * scale;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);
    ctx.fillStyle = '#ffd54f';
    ctx.beginPath();
    ctx.moveTo(16, 0);
    ctx.lineTo(-10, -9);
    ctx.lineTo(-5, 0);
    ctx.lineTo(-10, 9);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
}
