import { CONFIG } from '../config.js';
import { META_ITEM_LIST } from './items.js';
import { SHOP_ATTRS } from './shop.js';

// headless / 无 localStorage 环境的内存兜底存档（存序列化后的 JSON 字符串）
let memoryBackup = null;

export function defaultSave() {
  return {
    version: 1,
    darkCrystals: 0,
    storage: Object.fromEntries(META_ITEM_LIST.map((item) => [item.id, 0])),
    metaLevels: Object.fromEntries(SHOP_ATTRS.map((attr) => [attr, 0])),
    stats: { runs: 0, extractions: 0, bestWave: 0, totalBossKills: 0 },
  };
}

function hasLocalStorage() {
  return typeof localStorage !== 'undefined';
}

// 深层合并：只保留默认存档结构内的字段，缺失补默认值，未知字段忽略。
function mergeInto(base, data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return base;
  for (const key of Object.keys(base)) {
    if (!(key in data)) continue;
    const baseVal = base[key];
    const dataVal = data[key];
    if (baseVal && typeof baseVal === 'object' && !Array.isArray(baseVal)) {
      mergeInto(baseVal, dataVal);
    } else if (dataVal !== null && typeof dataVal === typeof baseVal) {
      base[key] = dataVal;
    }
  }
  return base;
}

export function loadSave() {
  let raw = null;
  if (hasLocalStorage()) {
    try {
      raw = localStorage.getItem(CONFIG.meta.saveKey);
    } catch {
      raw = null;
    }
  }
  // localStorage 缺失或读取失败时退回内存兜底
  if (!raw) raw = memoryBackup;
  if (!raw) return defaultSave();
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return defaultSave();
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed) || parsed.version !== 1) {
    return defaultSave();
  }
  return mergeInto(defaultSave(), parsed);
}

export function persistSave(save) {
  const raw = JSON.stringify(save);
  memoryBackup = raw;
  if (hasLocalStorage()) {
    try {
      localStorage.setItem(CONFIG.meta.saveKey, raw);
    } catch {
      // 配额超限 / 隐私模式限制等：静默降级，仅保留内存兜底
    }
  }
}

export function resetSave() {
  const save = defaultSave();
  persistSave(save);
  return save;
}
