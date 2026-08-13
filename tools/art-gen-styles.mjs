// art-gen-styles.mjs — 生成《暗夜幸存者》美术风格选型图（ComfyUI krea2 t2i）
import fs from 'node:fs';
import path from 'node:path';

const BASE = 'http://127.0.0.1:8188';
const OUT_DIR = 'C:/WorkSpace/AIGame/Experimental/art-style-preview';
const SEED = 20260812;
const W = 1216, H = 832;

const COMPOSITION = `Top-down perspective action roguelike game battle scene. A lone Taoist cultivator warrior in flowing dark robes stands at the center of an ancient stone battlefield at night, unleashing radiant cyan sword-qi energy blasts in all directions. Swarms of shadowy demons, ghosts and monstrous creatures close in from every side. Golden glowing paper talismans float in the air, scattered glowing blue spirit gems (experience pickups) litter the ground, magical bullet-hell projectiles and particle effects fill the scene. Background: dark misty Chinese mountains and ruined temple silhouettes under a moonless night sky. Dramatic contrast between magical glow effects and deep darkness.`;

const STYLES = [
  { key: 'A_pixel', name: '复古像素 Pixel Art', lora: null,
    prompt: `16-bit retro pixel art game screenshot, chunky pixels, limited vintage color palette, crisp dithering, classic arcade action game aesthetic, nostalgic retro gaming. ${COMPOSITION}` },
  { key: 'B_ink', name: '水墨国风暗夜 Ink Wash', lora: { name: 'krea2_darkbrush.safetensors', strength: 0.85 },
    prompt: `monochrome ink wash style, traditional Chinese ink painting on textured xuan paper, expressive black brush strokes, misty negative space, sparse glowing crimson red accents. ${COMPOSITION}` },
  { key: 'C_gothic_oil', name: '哥特厚涂油画 Gothic Oil', lora: null,
    prompt: `dark gothic fantasy oil painting, heavy impasto textured brushwork, baroque chiaroscuro lighting, deep shadows, warm firelight against cold darkness, grim dark fantasy atmosphere, highly detailed painterly rendering. ${COMPOSITION}` },
  { key: 'D_guochao', name: '国潮扁平矢量 Guochao Flat', lora: null,
    prompt: `modern Chinese guochao style flat vector illustration, bold high-saturation colors, clean geometric shapes, thick outlines, stylized flat shading with high contrast, trendy poster design. ${COMPOSITION}` },
  { key: 'E_anime', name: '暗黑赛璐璐动漫 Dark Cel Anime', lora: null,
    prompt: `dark anime style, cel-shaded rendering, clean sharp lineart, dramatic rim lighting, high contrast night color palette, anime game key visual quality. ${COMPOSITION}` },
];

async function postJSON(url, body) {
  const r = await fetch(BASE + url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`POST ${url} -> ${r.status}: ${JSON.stringify(data).slice(0, 800)}`);
  return data;
}

function buildGraph(style) {
  const g = {};
  g['10'] = { class_type: 'UNETLoader', inputs: { unet_name: 'krea2_turbo_fp8_scaled.safetensors', weight_dtype: 'default' } };
  g['11'] = { class_type: 'CLIPLoader', inputs: { clip_name: 'qwen3vl_4b_fp8_scaled.safetensors', type: 'krea2', device: 'default' } };
  g['12'] = { class_type: 'VAELoader', inputs: { vae_name: 'qwen_image_vae.safetensors' } };
  g['6']  = { class_type: 'CLIPTextEncode', inputs: { clip: ['11', 0], text: style.prompt } };
  g['13'] = { class_type: 'ConditioningZeroOut', inputs: { conditioning: ['6', 0] } };
  g['5']  = { class_type: 'EmptyLatentImage', inputs: { width: W, height: H, batch_size: 1 } };
  let modelOut = ['10', 0];
  if (style.lora) {
    g['15'] = { class_type: 'LoraLoaderModelOnly', inputs: { model: modelOut, lora_name: style.lora.name, strength_model: style.lora.strength } };
    modelOut = ['15', 0];
  }
  g['3']  = { class_type: 'KSampler', inputs: { model: modelOut, positive: ['6', 0], negative: ['13', 0], latent_image: ['5', 0], seed: SEED, steps: 8, cfg: 1.0, sampler_name: 'euler', scheduler: 'simple', denoise: 1.0 } };
  g['8']  = { class_type: 'VAEDecode', inputs: { samples: ['3', 0], vae: ['12', 0] } };
  g['29'] = { class_type: 'SaveImage', inputs: { images: ['8', 0], filename_prefix: `artstyle/${style.key}` } };
  return g;
}

async function waitFor(promptId, timeoutMs = 300000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const r = await fetch(`${BASE}/history/${promptId}`);
    const data = await r.json();
    const h = data[promptId];
    if (h) {
      const st = h.status || {};
      if (st.status_str === 'error') throw new Error('generation error: ' + JSON.stringify(st).slice(0, 500));
      if (st.completed && h.outputs) return h.outputs;
    }
    await new Promise(res => setTimeout(res, 2000));
  }
  throw new Error(`timeout waiting for ${promptId}`);
}

async function download(outputs, style) {
  const imgs = Object.values(outputs || {}).flatMap(o => o.images || []);
  const saved = [];
  for (const img of imgs) {
    const q = new URLSearchParams({ filename: img.filename, subfolder: img.subfolder || '', type: img.type || 'output' });
    const r = await fetch(`${BASE}/view?${q}`);
    if (!r.ok) throw new Error(`view failed: ${r.status}`);
    const buf = Buffer.from(await r.arrayBuffer());
    const ext = path.extname(img.filename) || '.png';
    const file = path.join(OUT_DIR, `${style.key}${ext}`);
    fs.writeFileSync(file, buf);
    saved.push(file);
  }
  return saved;
}

fs.mkdirSync(OUT_DIR, { recursive: true });
console.log(`Generating ${STYLES.length} styles at ${W}x${H}, seed=${SEED} ...`);
for (const style of STYLES) {
  const t0 = Date.now();
  process.stdout.write(`[${style.key}] ${style.name} ... submit ... `);
  const res = await postJSON('/prompt', { prompt: buildGraph(style) });
  process.stdout.write(`queued(${res.prompt_id}) ... `);
  const outputs = await waitFor(res.prompt_id);
  const saved = await download(outputs, style);
  console.log(`done in ${((Date.now() - t0) / 1000).toFixed(1)}s -> ${saved.join(', ')}`);
}
console.log('ALL DONE');

