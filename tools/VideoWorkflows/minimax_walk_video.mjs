// MiniMax H3 首尾帧生视频 runner（API 格式，等价于 .agents/skills/comfyui-workflow/workflows/minimax_h3_i2v.json）
// 用法: node tools/VideoWorkflows/minimax_walk_video.mjs [--image <comfy input 名>] [--prompt <运动+音频描述>]
//      [--width 768] [--height 768] [--duration 1] [--seed <int>] [--out <输出名(不含扩展名)>]
// 帧数按工作流公式对齐 17k+5 网格（向上）: length = max(5, round(duration*24)) 后向上取 17k+5
// 首尾帧接同一张图 => 无缝循环（skill 推荐技巧）
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const COMFYUI_URL = 'http://localhost:8188';
const OUT_DIR = path.join(REPO_ROOT, 'Experimental', 'character-poses');

function parseArgs() {
  const argv = process.argv.slice(2);
  const opts = {
    image: 'walk_right_v2b.png',
    prompt: '图中角色向右原地行走,轻快的走路循环步态,衣摆与围巾随步伐自然摆动,固定机位,无缝循环,伴随轻柔脚步声。',
    width: 768,
    height: 768,
    duration: 1,
    seed: 777001,
    out: 'walk_right_loop',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const val = argv[i + 1];
      if (key === 'width' || key === 'height' || key === 'seed') opts[key] = parseInt(val, 10);
      else if (key === 'duration') opts[key] = parseFloat(val);
      else opts[key] = val;
      i++;
    }
  }
  return opts;
}

function framesForDuration(sec) {
  const raw = Math.max(5, Math.round(sec * 24));
  return raw + ((5 - (raw % 17)) + 17) % 17; // 向上对齐 17k+5 网格
}

function buildApiWorkflow(o) {
  const length = framesForDuration(o.duration);
  console.log('frames:', length, '(' + (length / 24).toFixed(2) + 's @24fps)');
  return {
    '114': { class_type: 'LoadImage', inputs: { image: o.image } },
    '6': { class_type: 'UNETLoader', inputs: { unet_name: 'minimax_h3_fl2va_pruned_int8_convrot.safetensors', weight_dtype: 'default' } },
    '13': { class_type: 'CLIPLoader', inputs: { clip_name: 'qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors', type: 'minimax', device: 'default' } },
    '11': { class_type: 'VAELoader', inputs: { vae_name: 'minimax_h3_video_vae_fp16.safetensors' } },
    '24': { class_type: 'VAELoader', inputs: { vae_name: 'minimax_h3_audio_vae_fp32.safetensors' } },
    '104': { class_type: 'MiniMaxH3ImageToVideo', inputs: { clip: ['13', 0], vae: ['11', 0], first_frame: ['114', 0], last_frame: ['114', 0], prompt: o.prompt, width: o.width, height: o.height, length } },
    '16': { class_type: 'BasicGuider', inputs: { model: ['6', 0], conditioning: ['104', 0] } },
    '9': { class_type: 'BasicScheduler', inputs: { model: ['6', 0], scheduler: 'simple', steps: 20, denoise: 1 } },
    '17': { class_type: 'KSamplerSelect', inputs: { sampler_name: 'res_multistep' } },
    '15': { class_type: 'RandomNoise', inputs: { noise_seed: o.seed } },
    '14': { class_type: 'SamplerCustomAdvanced', inputs: { noise: ['15', 0], guider: ['16', 0], sampler: ['17', 0], sigmas: ['9', 0], latent_image: ['104', 1] } },
    '10': { class_type: 'VAEDecode', inputs: { samples: ['14', 0], vae: ['11', 0] } },
    '23': { class_type: 'VAEDecodeAudio', inputs: { samples: ['14', 0], vae: ['24', 0] } },
    '91': { class_type: 'CreateVideo', inputs: { images: ['10', 0], audio: ['23', 0], fps: 24 } },
    '92': { class_type: 'SaveVideo', inputs: { video: ['91', 0], filename_prefix: 'video/MiniMax_H3_' + o.out, format: 'auto', codec: 'auto' } },
  };
}

async function queuePrompt(apiWorkflow) {
  const resp = await fetch(COMFYUI_URL + '/prompt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt: apiWorkflow }),
  });
  if (!resp.ok) throw new Error('Queue failed (' + resp.status + '): ' + (await resp.text()));
  return (await resp.json()).prompt_id;
}

async function waitForCompletion(promptId, timeoutMs = 3000000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const resp = await fetch(COMFYUI_URL + '/history/' + promptId);
    const data = await resp.json();
    if (data[promptId]) {
      const status = data[promptId].status;
      if (status.status_str === 'success') return data[promptId];
      if (status.status_str === 'error') throw new Error('Generation failed: ' + JSON.stringify(status));
    }
    await new Promise((r) => setTimeout(r, 5000));
  }
  throw new Error('Timeout waiting for prompt ' + promptId);
}

async function downloadFile(filename, subfolder, outputPath) {
  let url = COMFYUI_URL + '/view?filename=' + encodeURIComponent(filename) + '&type=output';
  if (subfolder) url += '&subfolder=' + encodeURIComponent(subfolder);
  const resp = await fetch(url);
  if (!resp.ok) throw new Error('Download failed: ' + resp.status);
  fs.writeFileSync(outputPath, Buffer.from(await resp.arrayBuffer()));
  return outputPath;
}

const opts = parseArgs();
console.log('image :', opts.image);
console.log('prompt:', opts.prompt);
console.log('size  :', opts.width + 'x' + opts.height, '| seed:', opts.seed);
const promptId = await queuePrompt(buildApiWorkflow(opts));
console.log('queued prompt_id:', promptId);
const result = await waitForCompletion(promptId);
const saveNode = result.outputs['92'];
const vids = saveNode && (saveNode.videos || saveNode.gifs || saveNode.images); // SaveVideo 把 mp4 放在 images 键下(animated:true)
if (!vids || !vids.length) throw new Error('No video in output: ' + JSON.stringify(result.outputs));
fs.mkdirSync(OUT_DIR, { recursive: true });
for (const v of vids) {
  const ext = path.extname(v.filename) || '.mp4';
  console.log('saved :', await downloadFile(v.filename, v.subfolder, path.join(OUT_DIR, opts.out + ext)));
}
