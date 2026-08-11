// 武器模块统一出口
export { WeaponBase, nearestEnemy, nearestN, hitEnemiesInRadius } from './base.js';
export { SwordWeapon, CARD as SWORD_CARD } from './sword.js';
export { CloakWeapon, CARD as CLOAK_CARD } from './cloak.js';
export { TalismanWeapon, CARD as TALISMAN_CARD } from './talisman.js';
export { TrailWeapon, updateTrail, drawTrail, CARD as TRAIL_CARD } from './trail.js';
export { RingWeapon, CARD as RING_CARD } from './ring.js';
export { StaffWeapon, drawSummon, CARD as STAFF_CARD } from './staff.js';