// 八方向走路精灵图批量编排（pose -> 首尾帧视频 -> alpha flipbook -> 归位正式目录）
// 用法: node tools/batch_walk_sprites.mjs <poses|videos|flipbooks|move>
// 方向与提示词规范遵循 .agents/skills/comfyui-workflow/SKILL.md
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const POSES_DIR = path.join(REPO_ROOT, 'Experimental', 'character-poses');
const ANIM_DIR = path.join(REPO_ROOT, 'ArtAsset', 'CharacterAnimation');
const VIDEO_DIR = path.join(REPO_ROOT, 'ArtAsset', 'Video', 'Character');
const FLIPBOOK_PS1 = 'C:\\WorkSpace\\AIGame\\.agents\\skills\\video-to-alpha-flipbook\\scripts\\run_video_to_flipbook.ps1';
const COMFYUI_URL = 'http://localhost:8188';
const STYLE = '保持画面风格,统一线条与配色,保持同一角色形象';
const POSE_SEED = 20260813;
const VIDEO_SEED = 777001;

const DIRS = [
  { id: 'up', cn: '向上', cap: 'Up' },
  { id: 'down', cn: '向下', cap: 'Down' },
  { id: 'leftdown', cn: '向左下', cap: 'LeftDown' },
  { id: 'rightdown', cn: '向右下', cap: 'RightDown' },
  { id: 'rightup', cn: '向右上', cap: 'RightUp' },
  { id: 'leftup', cn: '向左上', cap: 'LeftUp' },
];

function run(cmd, args, timeoutMs) {
  const r = spawnSync(cmd, args, { timeout: timeoutMs || 3000000, encoding: 'utf8', shell: false });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  return r.status === 0;
}

async function uploadToComfy(localPath, name) {
  const buf = fs.readFileSync(localPath);
  const form = new FormData();
  form.append('image', new Blob([buf]), name);
  form.append('overwrite', 'true');
  const r = await fetch(COMFYUI_URL + '/upload/image', { method: 'POST', body: form });
  if (!r.ok) throw new Error('upload failed ' + r.status);
}

function isRgbaPng(file) {
  const b = fs.readFileSync(file);
  return b.length > 25 && b[0] === 0x89 && b[1] === 0x50 && b.readUInt8(25) === 6;
}

function countPngs(dir) {
  return fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.png')).length : -1;
}

const stage = process.argv[2];

if (stage === 'poses') {
  for (const d of DIRS) {
    console.log(`\n===== POSE ${d.id} =====`);
    const ok = run('node', [
      path.join(REPO_ROOT, 'tools', 'ImageWorkflows', 'qwen_pose_edit.mjs'),
      '--turbo', 'false', '--seed', String(POSE_SEED), '--out', 'walk_' + d.id,
      '--prompt', `图中角色${d.cn}移动,走路的pose,${STYLE}`,
    ]);
    console.log(`POSE ${d.id}: ${ok ? 'OK' : 'FAILED'}`);
  }
} else if (stage === 'videos') {
  for (const d of DIRS) {
    console.log(`\n===== VIDEO ${d.id} =====`);
    const posePath = path.join(POSES_DIR, 'walk_' + d.id + '.png');
    if (!fs.existsSync(posePath)) { console.log(`VIDEO ${d.id}: SKIPPED (missing pose)`); continue; }
    await uploadToComfy(posePath, 'walk_' + d.id + '.png');
    const ok = run('node', [
      path.join(REPO_ROOT, 'tools', 'VideoWorkflows', 'minimax_walk_video.mjs'),
      '--image', 'walk_' + d.id + '.png', '--seed', String(VIDEO_SEED), '--out', 'walk_' + d.id + '_loop',
      '--prompt', `图中角色${d.cn}原地行走,轻快的走路循环步态,衣摆与围巾随步伐自然摆动,固定机位,无缝循环,伴随轻柔脚步声。`,
    ]);
    console.log(`VIDEO ${d.id}: ${ok ? 'OK' : 'FAILED'}`);
  }
} else if (stage === 'flipbooks') {
  for (const d of DIRS) {
    console.log(`\n===== FLIPBOOK ${d.id} =====`);
    const video = path.join(POSES_DIR, 'walk_' + d.id + '_loop.mp4');
    if (!fs.existsSync(video)) { console.log(`FLIPBOOK ${d.id}: SKIPPED (missing video)`); continue; }
    const outDir = path.join(POSES_DIR, d.id + '_flipbook');
    const ok = run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', FLIPBOOK_PS1,
      '-InputVideo', video, '-OutputDir', outDir, '-Grid', '6', '-AtlasSize', '4096', '-Force']);
    let check = 'SKIPPED';
    if (ok) {
      const raw = countPngs(path.join(outDir, 'frames_raw'));
      const alp = countPngs(path.join(outDir, 'frames_alpha'));
      const atlas = path.join(outDir, 'sprite_sheet_6x6_36f_4096.png');
      const json = path.join(outDir, 'sprite_sheet_6x6_36f_4096.json');
      const good = raw === alp && raw > 0 && fs.existsSync(atlas) && isRgbaPng(atlas) && fs.existsSync(json);
      check = good ? `CHECK OK (raw=${raw}, alpha=${alp}, atlas RGBA)` : `CHECK FAIL (raw=${raw}, alpha=${alp}, atlasRGBA=${fs.existsSync(atlas) && isRgbaPng(atlas)})`;
    }
    console.log(`FLIPBOOK ${d.id}: ${ok ? 'OK' : 'FAILED'} | ${check}`);
  }
} else if (stage === 'move') {
  fs.mkdirSync(ANIM_DIR, { recursive: true });
  fs.mkdirSync(VIDEO_DIR, { recursive: true });
  for (const d of DIRS) {
    const outDir = path.join(POSES_DIR, d.id + '_flipbook');
    const sheet = path.join(outDir, 'sprite_sheet_6x6_36f_4096.png');
    const json = path.join(outDir, 'sprite_sheet_6x6_36f_4096.json');
    const video = path.join(POSES_DIR, 'walk_' + d.id + '_loop.mp4');
    for (const [src, dst] of [
      [sheet, path.join(ANIM_DIR, 'Walk' + d.cap + '.png')],
      [json, path.join(ANIM_DIR, 'Walk' + d.cap + '.json')],
      [video, path.join(VIDEO_DIR, 'Walk' + d.cap + '.mp4')],
    ]) {
      if (fs.existsSync(src)) { fs.copyFileSync(src, dst); console.log('moved:', dst); }
      else console.log('MISSING:', src);
    }
  }
} else {
  console.log('unknown stage:', stage);
  process.exit(1);
}
console.log('\nstage done:', stage);
