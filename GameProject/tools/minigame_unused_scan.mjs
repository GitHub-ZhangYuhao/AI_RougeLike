#!/usr/bin/env node
// minigame_unused_scan.mjs — 扫描 GameProject/assets 下无运行时引用的资产，并按 .import 指向的
// 实际导入产物（etc2 ctex / oggstr / fontdata）计算真实体积。
// 用法: node GameProject/tools/minigame_unused_scan.mjs [--json]
// 引用语料 = scenes/logic/autoload 的 .gd/.tscn/.tres + assets/**/*.json + project.godot + 根 *.tres
// 传递规则: assets/**/*.tres 只有在自身被引用时才计入语料（孤立材质链不计入）。
// 动态加载白名单: assets/sprites/player/*（player_sprite_frames.gd 通过 JSON metadata + load() 动态加载）
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const textExts = new Set(['.gd', '.tscn', '.tres', '.json', '.cfg', '.godot']);
const assetExts = new Set(['.png', '.webp', '.jpg', '.jpeg', '.svg', '.ogg', '.wav', '.mp3', '.ttf', '.otf']);
const skipDirs = new Set(['.godot', 'addons', 'tools', 'tests', 'build', '.git']);
const ext = f => { const i = f.lastIndexOf('.'); return i < 0 ? '' : f.slice(i).toLowerCase(); };

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!skipDirs.has(entry.name)) walk(join(dir, entry.name), out);
    } else out.push(join(dir, entry.name));
  }
  return out;
}

// ---- 1. 一级语料：随包出货的代码/场景/资源 + JSON 元数据 ----
const corpusPaths = [];
for (const sub of ['scenes', 'logic', 'autoload']) {
  corpusPaths.push(...walk(join(ROOT, sub)).filter(f => textExts.has(ext(f))));
}
corpusPaths.push(...walk(join(ROOT, 'assets')).filter(f => f.endsWith('.json')));
corpusPaths.push(join(ROOT, 'project.godot'));
corpusPaths.push(...walk(ROOT).filter(f => relative(ROOT, f).split(sep).length === 1 && f.endsWith('.tres')));

let corpus = '';
for (const f of corpusPaths) {
  try { corpus += readFileSync(f, 'utf8') + '\n'; } catch {}
}

// ---- 2. 传递闭包：被引用的 assets/**/*.tres 内容并入语料，迭代到不动点 ----
const assetTres = walk(join(ROOT, 'assets')).filter(f => f.endsWith('.tres'));
const tresText = new Map(assetTres.map(f => [f, readFileSync(f, 'utf8')]));
const accepted = new Set();
let changed = true;
while (changed) {
  changed = false;
  for (const [f, text] of tresText) {
    if (accepted.has(f)) continue;
    const base = f.slice(f.lastIndexOf(sep) + 1).replace(/\.tres$/, '');
    if (corpus.includes(base) || corpus.includes('res://' + relative(ROOT, f).split(sep).join('/'))) {
      accepted.add(f);
      corpus += text + '\n';
      changed = true;
    }
  }
}

// ---- 3. 候选资产 + 引用判定 ----
const assets = walk(join(ROOT, 'assets')).filter(f => assetExts.has(ext(f)));
function isReferenced(file) {
  const rel = relative(ROOT, file).split(sep).join('/');
  if (rel.startsWith('assets/sprites/player/')) return true; // 动态 load()
  const base = file.slice(file.lastIndexOf(sep) + 1).replace(/\.[^.]+$/, '');
  return corpus.includes(base) || corpus.includes('res://' + rel);
}

// ---- 4. 实际产物体积 ----
function importedSize(file) {
  const importFile = file + '.import';
  if (!existsSync(importFile)) return { size: statSync(file).size, variant: 'raw' };
  const text = readFileSync(importFile, 'utf8');
  for (const key of ['path.etc2', 'path.s3tc', 'path']) {
    const m = text.match(new RegExp('^' + key.replace('.', '\\.') + '="([^"]+)"', 'm'));
    if (m) {
      const p = join(ROOT, m[1].replace(/^res:\/\//, '').split('/').join(sep));
      if (existsSync(p)) return { size: statSync(p).size, variant: key };
    }
  }
  return { size: statSync(file).size, variant: 'raw-fallback' };
}

const unreferenced = [];
let totalRef = 0, totalUnref = 0;
for (const f of assets) {
  const { size, variant } = importedSize(f);
  const rel = relative(ROOT, f).split(sep).join('/');
  if (isReferenced(f)) { totalRef += size; continue; }
  totalUnref += size;
  unreferenced.push({ file: rel, size, variant });
}
unreferenced.sort((a, b) => b.size - a.size);

const mb = n => (n / 1048576).toFixed(2) + ' MB';
console.log(`语料文件数: ${corpusPaths.length} (+${accepted.size} 个被引用的 assets/.tres)  候选资产: ${assets.length}`);
console.log(`被引用资产体积: ${mb(totalRef)} | 未引用资产体积: ${mb(totalUnref)} (${unreferenced.length} 个)\n`);
for (const u of unreferenced) console.log(`${(u.size / 1048576).toFixed(3).padStart(9)} MB  [${u.variant.padEnd(8)}] ${u.file}`);
if (process.argv.includes('--json')) {
  console.log(JSON.stringify({ totalUnrefMB: +(totalUnref / 1048576).toFixed(2), files: unreferenced.map(u => u.file) }, null, 2));
}