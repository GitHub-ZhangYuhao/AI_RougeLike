// tools/minigame_exclude_check.mjs — verify exclude_filter never excludes a referenced asset.
//
// Usage:  node tools/minigame_exclude_check.mjs <preset-index>
//         node tools/minigame_exclude_check.mjs 2
//
// Scans .gd/.tscn/.tres corpus for res:// references (preload/load strings,
// ext_resource paths, dynamic-load dirs) and reports every reference that the
// given preset's exclude_filter would strip from the package. Exits 1 on hits.
// Wildcard semantics mirror Godot's matchn: '*' crosses '/', '?' is one char.
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const presetIdx = process.argv[2] ?? '2';

// ---- read exclude_filter from export_presets.cfg --------------------------
const cfg = fs.readFileSync(path.join(root, 'export_presets.cfg'), 'utf8');
const hdr = `[preset.${presetIdx}]`;
const i = cfg.indexOf(hdr);
if (i < 0) { console.error(`preset.${presetIdx} not found`); process.exit(2); }
const j = cfg.indexOf('\n[preset.', i + 1);
const sec = cfg.slice(i, j < 0 ? cfg.length : j);
const m = sec.match(/^exclude_filter="([^"]*)"/m);
const patterns = (m?.[1] ?? '').split(',').map(s => s.trim()).filter(Boolean);
console.log(`preset.${presetIdx}: ${patterns.length} exclude patterns`);

// matchn-style: '*' -> .* , '?' -> .  (case-sensitive)
const matchers = patterns.map(p => ({
  p,
  re: new RegExp('^' + p.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.') + '$'),
}));
const excluded = rel => matchers.filter(x => x.re.test(rel)).map(x => x.p);

// ---- collect corpus --------------------------------------------------------
const SKIP = [/^\.(godot|git)/, /^build[/\\]/, /^addons[/\\]/];
const files = [];
(function walk(dir, rel) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const r = rel ? rel + '/' + e.name : e.name;
    if (e.isDirectory()) { if (!SKIP.some(re => re.test(r))) walk(path.join(dir, e.name), r); continue; }
    if (/\.(gd|tscn|tres)$/.test(e.name)) files.push({ abs: path.join(dir, e.name), rel: r });
  }
})(root, '');

// dynamic load() directories whose children are all considered referenced
const DYNAMIC_DIRS = ['assets/sprites/player'];

const refs = new Map(); // rel -> first referrer
for (const f of files) {
  const text = fs.readFileSync(f.abs, 'utf8');
  const push = (res) => {
    if (!res.startsWith('res://')) return;
    const rel = res.slice(6);
    if (!refs.has(rel)) refs.set(rel, f.rel);
  };
  const reAll = /(?:preload|load)\s*\(\s*["']([^"']+)["']/g;
  let mm;
  while ((mm = reAll.exec(text))) push(mm[1]);
  const rePath = /path\s*=\s*["'](res:\/\/[^"']+)["']/g;
  while ((mm = rePath.exec(text))) push(mm[1]);
}
for (const d of DYNAMIC_DIRS) {
  const abs = path.join(root, ...d.split('/'));
  if (!fs.existsSync(abs)) continue;
  for (const e of fs.readdirSync(abs)) refs.set(d + '/' + e, '<dynamic load dir>');
}

// ---- cross-check -----------------------------------------------------------
let hits = 0;
for (const [rel, by] of [...refs.entries()].sort()) {
  const via = excluded(rel);
  if (via.length) {
    hits++;
    console.log(`EXCLUDED BUT REFERENCED: ${rel}\n    referenced by: ${by}\n    matched pattern: ${via.join(' , ')}`);
  }
}
if (hits === 0) console.log('OK: no referenced asset is excluded.');
else console.log(`\n${hits} conflict(s) found.`);
process.exit(hits ? 1 : 0);