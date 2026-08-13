import fs from 'fs';
import path from 'path';

const COMFYUI_URL = 'http://localhost:8188';
const RESULTS_DIR = path.join(process.cwd(), 'tools', 'ImageWorkflows', 'results');

const styles = [
  {
    id: '13_chibi_impasto',
    name: '厚涂Q版风 (Chibi Impasto)',
    prompt: 'chibi cute style Chinese xianxia dark cultivator character, solid pure black background, character only, no environment, slightly bigger head than body, adorable cartoon proportions, thick impasto oil painting technique, heavy visible palette knife brushstrokes, rich deep oil paint texture, dark teal and crimson and gold color palette, dramatic painterly quality, textured paint surface, full body chibi character with oil painting texture',
    enableLora: false, loraName: '', loraStrength: 0, loraTrigger: '',
  },
  {
    id: '14_classical_oil_chibi',
    name: '古典油画Q版风 (Classical Oil Chibi)',
    prompt: 'chibi cute Chinese xianxia warrior character, solid pure black background, character only, no environment, slightly bigger head, cartoonish proportions, classical oil painting technique like Rembrandt and Rubens, warm golden underpainting with dark glazing layers, soft blended brushwork with subtle texture, rich dark brown and gold and deep red palette, old master painting quality, full body chibi character in classical oil style',
    enableLora: false, loraName: '', loraStrength: 0, loraTrigger: '',
  },
  {
    id: '15_baroque_impasto',
    name: '巴洛克厚涂风 (Baroque Impasto)',
    prompt: 'chibi cute Chinese xianxia character, solid pure black background, character only, no environment, slightly bigger head with cartoon proportions, ornate baroque oil painting style, dramatic theatrical lighting, heavy impasto paint applied with palette knife, rich jewel tones of deep purple gold and crimson, elaborate decorative gold filigree details on robes, ornate dramatic composition, full body baroque chibi character',
    enableLora: false, loraName: '', loraStrength: 0, loraTrigger: '',
  },
  {
    id: '16_impressionist_chibi',
    name: '印象派Q版风 (Impressionist Chibi)',
    prompt: 'chibi cute Chinese xianxia dark cultivator, solid pure black background, character only, no environment, slightly bigger head, cartoonish body proportions, impressionist oil painting style with loose visible brushstrokes, dappled light effects in paint, vibrant broken color technique, deep indigo and magenta and gold palette, dreamy atmospheric quality, Monet and Renoir inspired brushwork, full body chibi impressionist character',
    enableLora: false, loraName: '', loraStrength: 0, loraTrigger: '',
  },
  {
    id: '17_rembrandt_chibi',
    name: '伦勃朗光影Q版风 (Rembrandt Chiaroscuro Chibi)',
    prompt: 'chibi cute Chinese xianxia warrior character, solid pure black background, character only, no environment, slightly bigger head with cartoon proportions, Rembrandt-style chiaroscuro oil painting, dramatic single light source from above casting deep shadows, warm amber and brown tones with selective highlights on face and weapon, thick textured brushstrokes, moody atmospheric dark fantasy, old master technique, full body chibi character in dramatic lighting',
    enableLora: false, loraName: '', loraStrength: 0, loraTrigger: '',
  },
  {
    id: '18_abstract_chibi',
    name: '抽象表现主义Q版风 (Abstract Expressionist Chibi)',
    prompt: 'chibi cute Chinese xianxia character, solid pure black background, character only, no environment, slightly bigger head, cartoonish proportions, abstract expressionist oil painting style, bold gestural sweeping brushstrokes, thick impasto paint drips and splatters, expressive raw energy, deep teal crimson and gold with spontaneous color mixing, Pollock and de Kooning inspired technique, dynamic energetic composition, full body chibi character in abstract expressionist style',
    enableLora: false, loraName: '', loraStrength: 0, loraTrigger: '',
  }
];

// Simplified workflow: skip LLM text generation, use prompt directly
function buildApiWorkflow(style) {
  const finalPrompt = style.enableLora
    ? style.prompt + ', ' + style.loraTrigger
    : style.prompt;

  const wf = {
    "10": { class_type: "UNETLoader", inputs: { unet_name: "krea2_turbo_fp8_scaled.safetensors", weight_dtype: "default" } },
    "11": { class_type: "CLIPLoader", inputs: { clip_name: "qwen3vl_4b_fp8_scaled.safetensors", type: "krea2", weight_dtype: "default" } },
    "12": { class_type: "VAELoader", inputs: { vae_name: "qwen_image_vae.safetensors" } },
    "19": { class_type: "PrimitiveStringMultiline", inputs: { value: finalPrompt } },
    "5": { class_type: "EmptyLatentImage", inputs: { width: 1024, height: 1024, batch_size: 1 } },
    "6": { class_type: "CLIPTextEncode", inputs: { clip: ["11", 0], text: ["19", 0] } },
    "13": { class_type: "ConditioningZeroOut", inputs: { conditioning: ["6", 0] } },
    "8": { class_type: "VAEDecode", inputs: { samples: ["3", 0], vae: ["12", 0] } },
    "29": { class_type: "SaveImage", inputs: { images: ["8", 0], filename_prefix: "style_" + style.id } }
  };

  // LoRA path
  if (style.enableLora) {
    wf["15"] = { class_type: "LoraLoaderModelOnly", inputs: { model: ["10", 0], lora_name: style.loraName, strength_model: style.loraStrength } };
    wf["3"] = { class_type: "KSampler", inputs: { model: ["15", 0], positive: ["6", 0], negative: ["13", 0], latent_image: ["5", 0], seed: Math.floor(Math.random() * 999999999), steps: 8, cfg: 1, sampler_name: "euler", scheduler: "simple", denoise: 1 } };
  } else {
    wf["3"] = { class_type: "KSampler", inputs: { model: ["10", 0], positive: ["6", 0], negative: ["13", 0], latent_image: ["5", 0], seed: Math.floor(Math.random() * 999999999), steps: 8, cfg: 1, sampler_name: "euler", scheduler: "simple", denoise: 1 } };
  }

  return wf;
}

async function queuePrompt(apiWorkflow) {
  const resp = await fetch(COMFYUI_URL + '/prompt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt: apiWorkflow })
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error('Queue failed (' + resp.status + '): ' + text);
  }
  const data = await resp.json();
  return data.prompt_id;
}

async function waitForCompletion(promptId, timeoutMs) {
  timeoutMs = timeoutMs || 300000;
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const resp = await fetch(COMFYUI_URL + '/history/' + promptId);
    const data = await resp.json();
    if (data[promptId]) {
      const status = data[promptId].status;
      if (status.status_str === 'success') return data[promptId];
      if (status.status_str === 'error') throw new Error('Generation failed: ' + JSON.stringify(status));
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  throw new Error('Timeout waiting for prompt ' + promptId);
}

async function downloadImage(filename, subfolder, outputPath) {
  let url = COMFYUI_URL + '/view?filename=' + encodeURIComponent(filename) + '&type=output';
  if (subfolder) url += '&subfolder=' + encodeURIComponent(subfolder);
  const resp = await fetch(url);
  if (!resp.ok) throw new Error('Download failed: ' + resp.status);
  const buffer = Buffer.from(await resp.arrayBuffer());
  fs.writeFileSync(outputPath, buffer);
  console.log('  Saved: ' + outputPath);
}

async function main() {
  if (!fs.existsSync(RESULTS_DIR)) fs.mkdirSync(RESULTS_DIR, { recursive: true });
  console.log('Generating ' + styles.length + ' art style examples...\n');
  for (const style of styles) {
    console.log('[' + style.id + '] ' + style.name);
    console.log('  LoRA: ' + (style.enableLora ? style.loraName + ' @' + style.loraStrength : 'disabled'));
    try {
      const apiWorkflow = buildApiWorkflow(style);
      const promptId = await queuePrompt(apiWorkflow);
      console.log('  Queued: ' + promptId);
      const result = await waitForCompletion(promptId);
      const outputs = result.outputs;
      const saveNode = outputs['29'];
      if (saveNode && saveNode.images) {
        for (const img of saveNode.images) {
          const outputPath = path.join(RESULTS_DIR, 'style_' + style.id + '.png');
          await downloadImage(img.filename, img.subfolder, outputPath);
        }
      } else {
        console.log('  WARNING: No images in output, keys:', Object.keys(outputs));
      }
    } catch (err) {
      console.error('  ERROR: ' + err.message);
    }
    console.log('');
  }
  console.log('All styles generated!');
}

main().catch(console.error);
