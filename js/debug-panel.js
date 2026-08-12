import { WEAPON_CARDS } from './cards.js';

const STORAGE_KEY = 'ai-roguelike.debug.v1';
const ENEMY_TYPES = [
  ['chaser', '追击怪'],
  ['enhancedChaser', '强化追击怪'],
  ['charger', '冲锋怪'],
  ['ranged', '远程怪'],
  ['bomber', '自爆怪'],
  ['shield', '护盾怪'],
  ['boss', 'Boss'],
];

const STATE_LABELS = {
  playing: '战斗中',
  choosing: '选择升级',
  dead: '已死亡',
};

const STOP_EVENTS = [
  'pointerdown', 'pointerup', 'mousedown', 'mouseup', 'click', 'dblclick',
  'wheel', 'touchstart', 'touchend', 'keydown', 'keyup', 'keypress',
  'input', 'change',
];

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function formatNumber(value, digits = 1) {
  if (!Number.isFinite(value)) return '-';
  if (Number.isInteger(value)) return String(value);
  return value.toFixed(digits).replace(/\.0+$/, '').replace(/(\.\d*?)0+$/, '$1');
}

function numberOptions(min, max, step, value = '') {
  return `type="number" min="${min}" max="${max}" step="${step}" value="${value}"`;
}

export class DebugPanel {
  constructor(game) {
    this.game = game;
    this.available = false;
    this.open = false;
    this.refs = {};
    this.messageTimer = null;

    const doc = globalThis.document;
    if (
      !doc
      || typeof doc.createElement !== 'function'
      || !doc.body
      || typeof doc.body.appendChild !== 'function'
    ) {
      return;
    }

    this.document = doc;
    this._injectStyles();
    this._createDom();
    this._bindEvents();
    this.available = true;
    this.refresh();
    this.refreshTimer = globalThis.setInterval(() => this.refresh(), 200);
  }

  toggle() {
    if (!this.available) return false;
    if (this.open) this.close();
    else this.show();
    return this.open;
  }

  show() {
    if (!this.available || this.open) return;
    this._callDebug('setPaused', true);
    this.open = true;
    this.root.classList.add('is-open');
    this.root.setAttribute('aria-hidden', 'false');
    this.refresh();
  }

  close() {
    if (!this.available || !this.open) return;
    this.open = false;
    this.root.classList.remove('is-open');
    this.root.setAttribute('aria-hidden', 'true');
    this.refresh();
  }

  refresh() {
    if (!this.available) return;

    const game = this.game;
    const debug = game?.debug;
    const settings = debug?.settings ?? {};
    const playerSettings = settings.player ?? {};
    const enemySettings = settings.enemy ?? {};
    const spawnSettings = settings.spawn ?? {};
    const player = game?.player;
    const director = game?.waveDirector;
    const alive = Array.isArray(game?.enemies)
      ? game.enemies.reduce((count, enemy) => count + (!enemy?.dead ? 1 : 0), 0)
      : 0;
    const xpToNext = typeof game?.xpToNext === 'function' ? game.xpToNext() : NaN;

    this._setText('state', STATE_LABELS[game?.state] ?? game?.state ?? '-');
    this._setText('level', formatNumber(game?.level));
    this._setText('xp', `${formatNumber(game?.xp)} / ${formatNumber(xpToNext)}`);
    this._setText('alive', formatNumber(alive));
    this._setText('wave', formatNumber(director?.wave));
    this._setText('spawned', `${formatNumber(director?.spawned)} / ${formatNumber(director?.quota)}`);
    this._setText('hp', `${formatNumber(player?.hp)} / ${formatNumber(player?.maxHp)}`);

    this._setControl('player-current-hp', player?.hp);
    this._setControl('pause', Boolean(settings.paused));
    this._setControl('invincible', Boolean(settings.invincible));
    this._setControl('player-max-hp', playerSettings.maxHpMult);
    this._setControl('player-damage', playerSettings.damageMult);
    this._setControl('player-xp', playerSettings.xpMult);
    this._setControl('player-move', playerSettings.moveSpeedMult);
    this._setControl('player-pickup', playerSettings.pickupRangeMult);
    this._setControl('player-armor', playerSettings.armorBonus);
    this._setControl('enemy-hp', enemySettings.hpMult);
    this._setControl('enemy-damage', enemySettings.damageMult);
    this._setControl('enemy-speed', enemySettings.speedMult);
    this._setControl('spawn-quota', spawnSettings.quotaMult);
    this._setControl('spawn-cap', spawnSettings.aliveCap, { nullable: true });
    this._setControl('spawn-interval', spawnSettings.intervalMult);
    this._setControl('spawn-paused', Boolean(spawnSettings.paused));
    this._setControl('wave-jump', director?.wave);

    for (const card of WEAPON_CARDS) {
      const weapon = Array.isArray(game?.weapons)
        ? game.weapons.find((entry) => entry?.card?.id === card.id)
        : null;
      this._setControl(`weapon-${card.id}`, weapon?.level ?? 0);
    }

    const paused = Boolean(settings.paused);
    this.badge.hidden = this.open || !paused;
  }

  _injectStyles() {
    if (this.document.getElementById?.('debug-panel-styles')) return;
    const style = this.document.createElement('style');
    style.id = 'debug-panel-styles';
    style.textContent = `
      #debug-panel {
        --dbg-bg: rgba(13, 17, 23, 0.97);
        --dbg-panel: #171d25;
        --dbg-line: #303946;
        --dbg-text: #e6edf3;
        --dbg-muted: #93a4b8;
        --dbg-accent: #56d4ff;
        position: fixed;
        z-index: 100000;
        top: 0;
        right: 0;
        width: min(390px, 94vw);
        height: 100vh;
        box-sizing: border-box;
        display: none;
        overflow-y: auto;
        overscroll-behavior: contain;
        padding: 12px;
        color: var(--dbg-text);
        background: var(--dbg-bg);
        border-left: 1px solid var(--dbg-line);
        box-shadow: -14px 0 40px rgba(0, 0, 0, 0.4);
        font: 12px/1.35 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        color-scheme: dark;
      }
      #debug-panel.is-open { display: block; }
      #debug-panel, #debug-panel * { box-sizing: border-box; }
      #debug-panel .dbg-head {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        margin-bottom: 8px;
      }
      #debug-panel h1 { margin: 0; font-size: 16px; color: var(--dbg-accent); }
      #debug-panel h2 {
        margin: 0 0 8px;
        color: #c9d7e6;
        font-size: 12px;
        letter-spacing: .08em;
        text-transform: uppercase;
      }
      #debug-panel .dbg-section {
        margin: 8px 0;
        padding: 10px;
        background: var(--dbg-panel);
        border: 1px solid var(--dbg-line);
        border-radius: 7px;
      }
      #debug-panel .dbg-stats {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 5px;
      }
      #debug-panel .dbg-stat {
        min-width: 0;
        padding: 5px 6px;
        background: #0f141b;
        border-radius: 4px;
      }
      #debug-panel .dbg-stat span { display: block; color: var(--dbg-muted); font-size: 10px; }
      #debug-panel .dbg-stat strong { display: block; overflow: hidden; text-overflow: ellipsis; }
      #debug-panel .dbg-row {
        display: grid;
        grid-template-columns: minmax(115px, 1fr) minmax(90px, 132px);
        align-items: center;
        gap: 8px;
        min-height: 28px;
      }
      #debug-panel .dbg-row + .dbg-row { margin-top: 5px; }
      #debug-panel .dbg-inline { display: flex; align-items: center; gap: 6px; }
      #debug-panel .dbg-inline > input,
      #debug-panel .dbg-inline > select { min-width: 0; flex: 1; }
      #debug-panel label { color: #c7d0da; }
      #debug-panel input[type="number"], #debug-panel select {
        width: 100%;
        min-height: 27px;
        padding: 3px 6px;
        color: var(--dbg-text);
        background: #0d1117;
        border: 1px solid #3b4654;
        border-radius: 4px;
        font: inherit;
      }
      #debug-panel input:focus, #debug-panel select:focus, #debug-panel button:focus-visible {
        outline: 2px solid var(--dbg-accent);
        outline-offset: 1px;
      }
      #debug-panel input[type="checkbox"] { accent-color: var(--dbg-accent); }
      #debug-panel button {
        min-height: 27px;
        padding: 4px 8px;
        color: var(--dbg-text);
        background: #273342;
        border: 1px solid #405168;
        border-radius: 4px;
        font: inherit;
        cursor: pointer;
      }
      #debug-panel button:hover { background: #33445a; }
      #debug-panel button.dbg-danger { color: #ffd4d4; border-color: #734848; background: #462b2b; }
      #debug-panel .dbg-buttons { display: flex; flex-wrap: wrap; gap: 6px; }
      #debug-panel .dbg-buttons button { flex: 1; }
      #debug-panel .dbg-message { min-height: 16px; margin-top: 6px; color: #9ee493; }
      #debug-panel .dbg-muted { color: var(--dbg-muted); }
      #debug-paused-badge {
        position: fixed;
        z-index: 99999;
        top: 12px;
        left: 50%;
        transform: translateX(-50%);
        padding: 7px 11px;
        color: #fff3c4;
        background: rgba(103, 64, 0, .94);
        border: 1px solid #d39b2f;
        border-radius: 5px;
        box-shadow: 0 4px 18px rgba(0, 0, 0, .35);
        font: 700 12px/1.2 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        letter-spacing: .03em;
        pointer-events: none;
      }
      #debug-paused-badge[hidden] { display: none; }
    `;
    (this.document.head || this.document.body).appendChild(style);
  }

  _createDom() {
    const weaponRows = WEAPON_CARDS.map((card) => `
      <div class="dbg-row">
        <label for="dbg-weapon-${escapeHtml(card.id)}">${escapeHtml(card.name)}</label>
        <select id="dbg-weapon-${escapeHtml(card.id)}" data-ref="weapon-${escapeHtml(card.id)}">
          ${Array.from({ length: 7 }, (_, level) => `<option value="${level}">${level}</option>`).join('')}
        </select>
      </div>
    `).join('');

    const enemyOptions = ENEMY_TYPES.map(([id, name]) => (
      `<option value="${escapeHtml(id)}">${escapeHtml(name)}</option>`
    )).join('');

    const root = this.document.createElement('aside');
    root.id = 'debug-panel';
    root.setAttribute('aria-label', '游戏调试面板');
    root.setAttribute('aria-hidden', 'true');
    root.innerHTML = `
      <div class="dbg-head">
        <h1>调试面板</h1>
        <button type="button" data-ref="close" title="关闭调试面板">关闭 · F2</button>
      </div>

      <div class="dbg-section dbg-stats" aria-label="实时游戏状态">
        <div class="dbg-stat"><span>状态</span><strong data-ref="state">-</strong></div>
        <div class="dbg-stat"><span>等级</span><strong data-ref="level">-</strong></div>
        <div class="dbg-stat"><span>经验</span><strong data-ref="xp">-</strong></div>
        <div class="dbg-stat"><span>存活怪物</span><strong data-ref="alive">-</strong></div>
        <div class="dbg-stat"><span>波次</span><strong data-ref="wave">-</strong></div>
        <div class="dbg-stat"><span>已生成</span><strong data-ref="spawned">-</strong></div>
      </div>

      <section class="dbg-section">
        <h2>全局</h2>
        <div class="dbg-row">
          <label for="dbg-pause">暂停游戏</label>
          <input id="dbg-pause" data-ref="pause" type="checkbox">
        </div>
        <div class="dbg-buttons">
          <button type="button" data-ref="reset">恢复默认值</button>
        </div>
        <div class="dbg-buttons" style="margin-top:6px">
          <button type="button" data-ref="save">保存配置</button>
          <button type="button" data-ref="load">加载配置</button>
          <button type="button" data-ref="clear-config" class="dbg-danger">清除配置</button>
        </div>
        <div class="dbg-message" data-ref="message" role="status" aria-live="polite"></div>
      </section>

      <section class="dbg-section">
        <h2>玩家</h2>
        <div class="dbg-row">
          <label for="dbg-player-current-hp">当前生命 <span class="dbg-muted" data-ref="hp">-</span></label>
          <div class="dbg-inline"><input id="dbg-player-current-hp" data-ref="player-current-hp" ${numberOptions(0, 1000000000, 1)}><button type="button" data-ref="full-health">回满</button></div>
        </div>
        <div class="dbg-row"><label for="dbg-invincible">无敌</label><input id="dbg-invincible" data-ref="invincible" type="checkbox"></div>
        <div class="dbg-row"><label for="dbg-player-max-hp">最大生命倍率</label><input id="dbg-player-max-hp" data-ref="player-max-hp" ${numberOptions(0.1, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-player-damage">伤害倍率</label><input id="dbg-player-damage" data-ref="player-damage" ${numberOptions(0, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-player-xp">经验倍率</label><input id="dbg-player-xp" data-ref="player-xp" ${numberOptions(0, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-player-move">移动速度倍率</label><input id="dbg-player-move" data-ref="player-move" ${numberOptions(0.1, 10, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-player-pickup">拾取范围倍率</label><input id="dbg-player-pickup" data-ref="player-pickup" ${numberOptions(0, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-player-armor">护甲加成</label><input id="dbg-player-armor" data-ref="player-armor" ${numberOptions(0, 1000, 1)}></div>
        <div class="dbg-row">
          <label for="dbg-grant-xp">增加经验</label>
          <div class="dbg-inline"><input id="dbg-grant-xp" data-ref="grant-xp" ${numberOptions(1, 1000000000, 100, 100)}><button type="button" data-ref="grant-xp-button">增加</button></div>
        </div>
        <div class="dbg-buttons"><button type="button" data-ref="level-up">提升 1 级</button></div>
      </section>

      <section class="dbg-section">
        <h2>武器等级</h2>
        <div class="dbg-muted" style="margin-bottom:6px">每把武器可独立设置为 0～6 级。</div>
        ${weaponRows}
      </section>

      <section class="dbg-section">
        <h2>怪物属性</h2>
        <div class="dbg-row"><label for="dbg-enemy-hp">生命倍率</label><input id="dbg-enemy-hp" data-ref="enemy-hp" ${numberOptions(0.1, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-enemy-damage">伤害倍率</label><input id="dbg-enemy-damage" data-ref="enemy-damage" ${numberOptions(0, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-enemy-speed">速度倍率</label><input id="dbg-enemy-speed" data-ref="enemy-speed" ${numberOptions(0.1, 10, 0.1)}></div>
      </section>

      <section class="dbg-section">
        <h2>波次与刷怪</h2>
        <div class="dbg-row">
          <label for="dbg-wave-jump">跳转波次</label>
          <div class="dbg-inline"><input id="dbg-wave-jump" data-ref="wave-jump" ${numberOptions(1, 9999, 1, 1)}><button type="button" data-ref="wave-jump-button">跳转</button></div>
        </div>
        <div class="dbg-buttons"><button type="button" data-ref="next-wave">下一波</button></div>
        <div class="dbg-row"><label for="dbg-spawn-quota">波次数量倍率</label><input id="dbg-spawn-quota" data-ref="spawn-quota" ${numberOptions(0, 20, 0.1)}></div>
        <div class="dbg-row"><label for="dbg-spawn-cap">同屏上限 <span class="dbg-muted">（留空使用默认值）</span></label><input id="dbg-spawn-cap" data-ref="spawn-cap" ${numberOptions(0, 10000, 1)} placeholder="默认"></div>
        <div class="dbg-row"><label for="dbg-spawn-interval">刷新间隔倍率</label><input id="dbg-spawn-interval" data-ref="spawn-interval" ${numberOptions(0.05, 20, 0.05)}></div>
        <div class="dbg-row"><label for="dbg-spawn-paused">暂停自动刷怪</label><input id="dbg-spawn-paused" data-ref="spawn-paused" type="checkbox"></div>
        <div class="dbg-row"><label for="dbg-enemy-type">怪物类型</label><select id="dbg-enemy-type" data-ref="enemy-type">${enemyOptions}</select></div>
        <div class="dbg-row">
          <label for="dbg-enemy-count">数量</label>
          <div class="dbg-inline"><input id="dbg-enemy-count" data-ref="enemy-count" ${numberOptions(1, 200, 1, 1)}><button type="button" data-ref="spawn-enemies">生成</button></div>
        </div>
        <div class="dbg-buttons"><button type="button" data-ref="clear-enemies" class="dbg-danger">清除怪物</button></div>
      </section>
    `;

    const badge = this.document.createElement('div');
    badge.id = 'debug-paused-badge';
    badge.textContent = '游戏已暂停 · 按 F2 打开调试面板';
    badge.hidden = true;

    this.document.body.appendChild(root);
    this.document.body.appendChild(badge);
    this.root = root;
    this.badge = badge;

    for (const element of root.querySelectorAll('[data-ref]')) {
      this.refs[element.dataset.ref] = element;
    }
  }

  _bindEvents() {
    for (const type of STOP_EVENTS) {
      this.root.addEventListener(type, (event) => event.stopPropagation());
    }

    this._on('close', 'click', () => this.close());
    this._on('pause', 'change', (event) => this._callDebug('setPaused', event.currentTarget.checked));
    this._on('invincible', 'change', (event) => this._callDebug('setInvincible', event.currentTarget.checked));
    this._on('spawn-paused', 'change', (event) => {
      this._callDebug('setSpawnSettings', { paused: event.currentTarget.checked });
    });

    this._bindNumber('player-current-hp', (value) => this._callDebug('setPlayerHp', value));
    this._bindNumber('player-max-hp', (value) => this._callDebug('setPlayerSettings', { maxHpMult: value }));
    this._bindNumber('player-damage', (value) => this._callDebug('setPlayerSettings', { damageMult: value }));
    this._bindNumber('player-xp', (value) => this._callDebug('setPlayerSettings', { xpMult: value }));
    this._bindNumber('player-move', (value) => this._callDebug('setPlayerSettings', { moveSpeedMult: value }));
    this._bindNumber('player-pickup', (value) => this._callDebug('setPlayerSettings', { pickupRangeMult: value }));
    this._bindNumber('player-armor', (value) => this._callDebug('setPlayerSettings', { armorBonus: value }));
    this._bindNumber('enemy-hp', (value) => this._callDebug('setEnemyMultipliers', { hpMult: value }));
    this._bindNumber('enemy-damage', (value) => this._callDebug('setEnemyMultipliers', { damageMult: value }));
    this._bindNumber('enemy-speed', (value) => this._callDebug('setEnemyMultipliers', { speedMult: value }));
    this._bindNumber('spawn-quota', (value) => this._callDebug('setSpawnSettings', { quotaMult: value }));
    this._bindNumber('spawn-interval', (value) => this._callDebug('setSpawnSettings', { intervalMult: value }));
    this._bindNumber('spawn-cap', (value) => this._callDebug('setSpawnSettings', { aliveCap: value }), {
      nullable: true,
      integer: true,
    });

    for (const card of WEAPON_CARDS) {
      this._on(`weapon-${card.id}`, 'change', (event) => {
        const level = Number(event.currentTarget.value);
        if (!Number.isFinite(level)) return;
        this._callDebug('setWeaponLevel', card.id, Math.max(0, Math.min(6, Math.floor(level))));
        this.refresh();
      });
    }

    this._on('full-health', 'click', () => {
      const player = this.game?.player;
      if (player && Number.isFinite(player.maxHp)) player.hp = player.maxHp;
      this.refresh();
    });
    this._on('grant-xp-button', 'click', () => {
      const amount = this._readNumber(this.refs['grant-xp']);
      if (amount === undefined) return;
      this._callDebug('grantXp', amount);
      this.refresh();
    });
    this._on('level-up', 'click', () => {
      const game = this.game;
      const target = typeof game?.xpToNext === 'function' ? game.xpToNext() : NaN;
      const current = Number(game?.xp);
      if (!Number.isFinite(target) || !Number.isFinite(current)) return;
      this._callDebug('grantXp', Math.max(1, target - current));
      this.refresh();
    });
    this._on('wave-jump-button', 'click', () => {
      const wave = this._readNumber(this.refs['wave-jump'], { integer: true });
      if (wave === undefined) return;
      this._callDebug('setWave', wave);
      this.refresh();
    });
    this._on('next-wave', 'click', () => {
      this._callDebug('nextWave');
      this.refresh();
    });
    this._on('spawn-enemies', 'click', () => {
      const type = this.refs['enemy-type']?.value;
      const count = this._readNumber(this.refs['enemy-count'], { integer: true });
      if (!type || count === undefined) return;
      this._callDebug('spawnEnemies', type, count);
      this.refresh();
    });
    this._on('clear-enemies', 'click', () => {
      this._callDebug('clearEnemies');
      this.refresh();
    });
    this._on('reset', 'click', () => {
      this._callDebug('resetDefaults');
      this._message('已恢复默认值。');
      this.refresh();
    });
    this._on('save', 'click', () => this._saveConfig());
    this._on('load', 'click', () => this._loadConfig());
    this._on('clear-config', 'click', () => this._clearConfig());
  }

  _bindNumber(refName, apply, options = {}) {
    this._on(refName, 'change', (event) => {
      const value = this._readNumber(event.currentTarget, options);
      if (value === undefined) return;
      apply(value);
      this.refresh();
    });
  }

  _readNumber(input, options = {}) {
    if (!input) return undefined;
    const text = String(input.value ?? '').trim();
    if (!text) return options.nullable ? null : undefined;
    let value = Number(text);
    if (!Number.isFinite(value)) return undefined;
    if (options.integer) value = Math.floor(value);
    const min = Number(input.min);
    const max = Number(input.max);
    if (Number.isFinite(min)) value = Math.max(min, value);
    if (Number.isFinite(max)) value = Math.min(max, value);
    return value;
  }

  _setText(refName, value) {
    const element = this.refs[refName];
    if (element) element.textContent = String(value);
  }

  _setControl(refName, value, options = {}) {
    const element = this.refs[refName];
    if (!element || this.document.activeElement === element) return;
    if (element.type === 'checkbox') {
      element.checked = Boolean(value);
      return;
    }
    if (options.nullable && value == null) {
      element.value = '';
      return;
    }
    if (value !== undefined && value !== null && Number.isFinite(Number(value))) {
      element.value = String(value);
    }
  }

  _on(refName, type, handler) {
    this.refs[refName]?.addEventListener(type, handler);
  }

  _callDebug(method, ...args) {
    const fn = this.game?.debug?.[method];
    if (typeof fn !== 'function') return undefined;
    try {
      return fn.apply(this.game.debug, args);
    } catch (error) {
      this._message(`调试操作失败：${error?.message || '未知错误'}`, true);
      return undefined;
    }
  }

  _getStorage() {
    try {
      const storage = globalThis.localStorage ?? globalThis.window?.localStorage;
      if (
        storage
        && typeof storage.getItem === 'function'
        && typeof storage.setItem === 'function'
        && typeof storage.removeItem === 'function'
      ) {
        return storage;
      }
    } catch {
      // Storage can be blocked by browser privacy/security settings.
    }
    return null;
  }

  _saveConfig() {
    const storage = this._getStorage();
    if (!storage) {
      this._message('本地存储不可用。', true);
      return;
    }
    const serialize = this.game?.debug?.serialize;
    if (typeof serialize !== 'function') {
      this._message('调试配置不可用。', true);
      return;
    }
    try {
      storage.setItem(STORAGE_KEY, JSON.stringify(serialize.call(this.game.debug)));
      this._message('配置已保存。');
    } catch {
      this._message('配置保存失败。', true);
    }
  }

  _loadConfig() {
    const storage = this._getStorage();
    if (!storage) {
      this._message('本地存储不可用。', true);
      return;
    }
    try {
      const raw = storage.getItem(STORAGE_KEY);
      if (!raw) {
        this._message('没有已保存的配置。', true);
        return;
      }
      const data = JSON.parse(raw);
      const settings = data?.settings;
      if (
        !data
        || typeof data !== 'object'
        || Array.isArray(data)
        || data.version !== 1
        || !settings
        || typeof settings !== 'object'
        || Array.isArray(settings)
      ) {
        this._message('保存的配置无效。', true);
        return;
      }
      const apply = this.game?.debug?.applySerialized;
      if (typeof apply !== 'function') {
        this._message('调试配置不可用。', true);
        return;
      }
      apply.call(this.game.debug, data);
      this._message('配置已加载。');
      this.refresh();
    } catch {
      this._message('保存的配置无效。', true);
    }
  }

  _clearConfig() {
    const storage = this._getStorage();
    if (!storage) {
      this._message('本地存储不可用。', true);
      return;
    }
    try {
      storage.removeItem(STORAGE_KEY);
      this._message('已清除保存的配置。');
    } catch {
      this._message('配置清除失败。', true);
    }
  }

  _message(text, isError = false) {
    const element = this.refs.message;
    if (!element) return;
    element.textContent = text;
    element.style.color = isError ? '#ff9b9b' : '#9ee493';
    if (this.messageTimer) globalThis.clearTimeout(this.messageTimer);
    this.messageTimer = globalThis.setTimeout(() => {
      element.textContent = '';
      this.messageTimer = null;
    }, 2600);
  }
}
