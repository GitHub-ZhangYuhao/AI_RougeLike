// Qwen-Image-Edit 2511 pose 变体生成器（API 格式，等价于 .agents/skills/comfyui-workflow/workflows/image_edit.json）
// 用法: node tools/ImageWorkflows/qwen_pose_edit.mjs [--image <comfy input 文件名>] [--prompt <正向提示词>]
//      [--negative <负向>] [--seed <int>] [--out <输出文件名(不含扩展名)>] [--turbo true|false] [--steps <int>]
// 提示词规范（必须遵守）: 图中角色<动作描述>,<pose>的pose,保持画面风格
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
    image: 'mu_qing_04_ink_color.png',
    prompt: '图中角色向右移动,走路的pose,保持画面风格',
    negative: '',
    seed: 88123456,
    out: 'walk_right',
    turbo: true,
    steps: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const val = argv[i + 1];
      if (key === 'turbo') opts.turbo = val === 'true';
      else if (key === 'seed' || key === 'steps') opts[key] = parseInt(val, 10);
      else opts[key] = val;
      i++;
    }
  }
  return opts;
}

// 扁平化 image_edit.json 子图（去掉 Switch 节点，按 turbo 直接接线）
function buildApiWorkflow(o) {
  const steps = o.steps != null ? o.steps : (o.turbo ? 4 : 40);
  const cfg = o.turbo ? 1 : 4;
  const wf = {
    '195': { class_type: 'LoadImage', inputs: { image: o.image } },
    '161': { class_type: 'UNETLoader', inputs: { unet_name: 'qwen_image_edit_2511_bf16.safetensors', weight_dtype: 'default' } },
    '162': { class_type: 'CLIPLoader', inputs: { clip_name: 'qwen_2.5_vl_7b_fp8_scaled.safetensors', type: 'qwen_image', device: 'default' } },
    '146': { class_type: 'VAELoader', inputs: { vae_name: 'qwen_image_vae.safetensors' } },
    '160': { class_type: 'FluxKontextImageScale', inputs: { image: ['195', 0] } },
    '151': { class_type: 'TextEncodeQwenImageEditPlus', inputs: { clip: ['162', 0], vae: ['146', 0], image1: ['160', 0], prompt: o.prompt } },
    '149': { class_type: 'TextEncodeQwenImageEditPlus', inputs: { clip: ['162', 0], vae: ['146', 0], image1: ['160', 0], prompt: o.negative } },
    '148': { class_type: 'FluxKontextMultiReferenceLatentMethod', inputs: { conditioning: ['151', 0], reference_latents_method: 'index_timestep_zero' } },
    '147': { class_type: 'FluxKontextMultiReferenceLatentMethod', inputs: { conditioning: ['149', 0], reference_latents_method: 'index_timestep_zero' } },
    '145': { class_type: 'ModelSamplingAuraFlow', inputs: { model: ['161', 0], shift: 3.1 } },
    '152': { class_type: 'CFGNorm', inputs: { model: ['145', 0], strength: 1, pre_cfg: false } },
    '156': { class_type: 'VAEEncode', inputs: { pixels: ['160', 0], vae: ['146', 0] } },
    '169': { class_type: 'KSampler', inputs: { model: ['152', 0], seed: o.seed, steps, cfg, sampler_name: 'euler', scheduler: 'simple', positive: ['148', 0], negative: ['147', 0], latent_image: ['156', 0], denoise: 1 } },
    '158': { class_type: 'VAEDecode', inputs: { samples: ['169', 0], vae: ['146', 0] } },
    '9': { class_type: 'SaveImage', inputs: { images: ['158', 0], filename_prefix: 'Qwen_Edit_2511_' + o.out } },
  };
  if (o.turbo) {
    wf['153'] = { class_type: 'LoraLoaderModelOnly', inputs: { model: ['152', 0], lora_name: 'Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors', strength_model: 1 } };
    wf['169'].inputs.model = ['153', 0];
  }
  return wf;
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

async function waitForCompletion(promptId, timeoutMs = 1800000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const resp = await fetch(COMFYUI_URL + '/history/' + promptId);
    const data = await resp.json();
    if (data[promptId]) {
      const status = data[promptId].status;
      if (status.status_str === 'success') return data[promptId];
      if (status.status_str === 'error') throw new Error('Generation failed: ' + JSON.stringify(status));
    }
    await new Promise((r) => setTimeout(r, 3000));
  }
  throw new Error('Timeout waiting for prompt ' + promptId);
}

async function downloadImage(filename, subfolder, outputPath) {
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
console.log('turbo :', opts.turbo, '| seed:', opts.seed);
const promptId = await queuePrompt(buildApiWorkflow(opts));
console.log('queued prompt_id:', promptId);
const result = await waitForCompletion(promptId);
const saveNode = result.outputs['9'];
if (!saveNode || !saveNode.images || !saveNode.images.length) throw new Error('No images in output: ' + JSON.stringify(result.outputs));
fs.mkdirSync(OUT_DIR, { recursive: true });
for (const img of saveNode.images) {
  const outPath = path.join(OUT_DIR, opts.out + '.png');
  console.log('saved :', await downloadImage(img.filename, img.subfolder, outPath));
}
