"""
ComfyUI 音频批量生成脚本 — Stable Audio 3 Small-SFX

使用方法：
  1. 确保 ComfyUI Desktop 正在运行
  2. 确保 stable_audio_3_small_sfx.safetensors 在 models/checkpoints/
  3. 确保 t5gemma_b_b_ul2.safetensors 在 models/text_encoders/
  4. 运行：python generate_sfx_stable_audio.py
  5. 生成的音频在 ComfyUI output/audio/ 目录

依赖：requests（pip install requests）
"""

import json
import time
import random
import requests
from pathlib import Path

COMFYUI_URL = "http://127.0.0.1:8188"

# ============================================================
# Stable Audio 3 Small-SFX 游戏音效提示词预设
# ============================================================

AUDIO_PROMPTS = {
    # === 武器音效 ===
    "sfx_sword_slash": {
        "positive": "sharp metallic sword slash, steel blade cutting through air, swift single strike, clean crisp metallic ring, game combat sound effect",
        "negative": "low quality, noisy, music, speech, multiple hits, long reverb",
        "seconds": 1.5,
    },
    "sfx_sword_projectile": {
        "positive": "magical flying sword whoosh, ethereal blade energy trail, crystalline hum, mystical projectile sound, fantasy game audio",
        "negative": "low quality, noise, music, voice, explosion",
        "seconds": 1.5,
    },
    "sfx_sword_ring_slash": {
        "positive": "spinning blade ring whoosh, circular slash air cut, sharp metallic rotation, ice crystal chime, magical weapon swing, game audio",
        "negative": "low quality, noise, music, voice",
        "seconds": 2.0,
    },
    "sfx_fire_burn": {
        "positive": "crackling fire ambient, continuous flame burning, warm embers, magical fire aura sustained, game sound effect",
        "negative": "low quality, explosion, music, silence, voice",
        "seconds": 2.0,
    },
    "sfx_fire_blast": {
        "positive": "powerful fire shockwave blast, deep bass impact explosion, concussive wave burst, single powerful eruption, game sound effect",
        "negative": "low quality, sustained fire, music, voice, small",
        "seconds": 1.5,
    },
    "sfx_thunder_bolt": {
        "positive": "electric thunder bolt strike, crackling lightning zap, magical electric discharge, sharp crack, single strike, game sound effect",
        "negative": "low quality, sustained electricity, music, voice, rain, ambient",
        "seconds": 1.0,
    },
    "sfx_chain_lightning": {
        "positive": "chain lightning strike, multiple electric arcs branching, cascading thunder crack, electrical energy chain reaction, game sound effect",
        "negative": "low quality, single spark, music, voice, rain",
        "seconds": 2.0,
    },
    "sfx_furnace_explosion": {
        "positive": "powerful alchemical furnace explosion, massive fire eruption burst, intense heat wave detonation, cauldron blast, game sound effect",
        "negative": "low quality, small fire, sustained flame, music, voice",
        "seconds": 2.0,
    },
    "sfx_jade_ring": {
        "positive": "jade ring spinning whoosh, crystalline ice blade chime, frozen wind chime rotation, magical ice weapon spin, game sound effect",
        "negative": "low quality, heavy impact, explosion, music, voice",
        "seconds": 2.0,
    },
    "sfx_summon": {
        "positive": "dark summoning ritual sound, ghostly whisper, supernatural portal opening, necromantic energy rising, skeleton creature awakening, game sound effect",
        "negative": "low quality, explosion, bright happy, music, voice dialogue",
        "seconds": 2.0,
    },

    # === 战斗反馈 ===
    "sfx_enemy_hit": {
        "positive": "soft flesh impact hit, muted thud, combat damage strike, short punchy impact, game hit sound effect",
        "negative": "low quality, explosion, music, bone crack, gore",
        "seconds": 0.5,
    },
    "sfx_enemy_death": {
        "positive": "enemy defeat poof sound, creature dissipating, vanishing smoke puff, monster destruction, short dissolution effect, game sound",
        "negative": "low quality, explosion, music, scream, voice, gore",
        "seconds": 1.0,
    },
    "sfx_boss_appear": {
        "positive": "deep ominous horn blast, boss arrival alarm, dark announcement gong strike, powerful warning signal, epic dramatic intro sting, game audio",
        "negative": "low quality, cheerful, music loop, voice, dialogue, calm",
        "seconds": 3.0,
    },
    "sfx_player_hurt": {
        "positive": "painful impact thud, damage taken hit, heavy reaction impact, short grunt effect, game damage sound",
        "negative": "low quality, explosion, music, voice dialogue, gore",
        "seconds": 0.5,
    },

    # === 拾取/UI ===
    "sfx_gem_pickup": {
        "positive": "magical crystal pickup chime, sparkling gem collect, bright short ding, magical collectible pickup, game reward sound",
        "negative": "low quality, explosion, voice, music, long reverb",
        "seconds": 0.5,
    },
    "sfx_rare_pickup": {
        "positive": "legendary item pickup fanfare, rare treasure discovery chime, magical artifact jingle, valuable loot collection, game achievement sound",
        "negative": "low quality, explosion, voice, dark, scary",
        "seconds": 1.5,
    },
    "sfx_heal": {
        "positive": "healing potion drink sound, health restore magical chime, warm recovery glow effect, positive energy restoration, game heal sound",
        "negative": "low quality, explosion, voice, dark, scary",
        "seconds": 1.0,
    },
    "sfx_levelup": {
        "positive": "level up achievement sound, power upgrade ascending chime, rewarding magical fanfare, character growth celebration, game level up sound",
        "negative": "low quality, voice, dialogue, dark, scary",
        "seconds": 2.0,
    },
    "sfx_ui_click": {
        "positive": "soft button click sound, gentle tap, clean interface interaction, subtle UI feedback click, minimal short press, game UI sound",
        "negative": "low quality, loud, explosion, music, voice",
        "seconds": 0.3,
    },

    # === 波次/事件 ===
    "sfx_wave_banner": {
        "positive": "dramatic wave announcement horn, battle begins alert signal, short dramatic sting, dark war horn signal, game wave start sound",
        "negative": "low quality, music loop, voice, calm, cheerful",
        "seconds": 2.0,
    },
    "sfx_extraction": {
        "positive": "victory fanfare, mission complete triumphant chime, safe return celebration, successful extraction jingle, game victory sound",
        "negative": "low quality, dark, scary, voice, long, failure",
        "seconds": 3.0,
    },
    "sfx_synergy_activate": {
        "positive": "magical synergy activation, power link established, ethereal energy connection, ascending magical chime, combination power-up, game sound effect",
        "negative": "low quality, dark, scary, voice, explosion",
        "seconds": 2.0,
    },

    # === 背景音乐 ===
    "bgm_menu": {
        "positive": "serene Chinese traditional night ambiance, soft erhu melody, gentle guzheng plucks, peaceful temple bells, calm mysterious atmosphere, game menu background music loop",
        "negative": "low quality, noisy, distorted, vocals, speech, fast tempo, aggressive",
        "seconds": 30.0,
    },
    "bgm_battle": {
        "positive": "intense dark fantasy battle music, fast Chinese war drums, aggressive erhu melody, thundering taiko percussion, action combat soundtrack, game battle background music",
        "negative": "low quality, noisy, calm, peaceful, slow tempo, vocals, speech",
        "seconds": 30.0,
    },
    "bgm_boss": {
        "positive": "ominous boss battle theme, deep bass drone, menacing Chinese pipa tremolo, thunderous war drums, supernatural horror atmosphere, final boss encounter music",
        "negative": "low quality, noisy, calm, happy, cheerful, vocals, speech",
        "seconds": 30.0,
    },
}


def build_prompt(name: str, preset: dict) -> dict:
    """Build a ComfyUI API prompt for Stable Audio 3 Small-SFX.

    Pipeline (from official ComfyUI template):
      CheckpointLoaderSimple → MODEL + VAE (CLIP output unused)
      CLIPLoader (t5gemma, type=stable_audio) → CLIP
      CLIPTextEncode (positive/negative) → CONDITIONING
      EmptyLatentAudio → LATENT
      KSampler (lcm, simple, steps=8, cfg=1.0)
      VAEDecodeAudio → AUDIO
      SaveAudioAdvanced → file
    """
    seconds = preset.get("seconds", 2.0)
    seed = random.randint(0, 2**32 - 1)

    # Append length hint for SFX prompts
    positive = preset["positive"]
    if "Length:" not in positive and "length" not in positive.lower():
        positive += f". Length: {int(seconds)} seconds"

    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {
                "ckpt_name": "stable_audio_3_small_sfx.safetensors",
            },
        },
        "2": {
            "class_type": "CLIPLoader",
            "inputs": {
                "clip_name": "t5gemma_b_b_ul2.safetensors",
                "type": "stable_audio",
            },
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": positive,
            },
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": preset.get("negative", "low quality, noisy, distorted"),
            },
        },
        "5": {
            "class_type": "EmptyLatentAudio",
            "inputs": {
                "seconds": seconds,
                "batch_size": 1,
            },
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": ["3", 0],
                "negative": ["4", 0],
                "latent_image": ["5", 0],
                "seed": seed,
                "steps": 8,
                "cfg": 1.0,
                "sampler_name": "lcm",
                "scheduler": "simple",
                "denoise": 1.0,
            },
        },
        "7": {
            "class_type": "VAEDecodeAudio",
            "inputs": {
                "samples": ["6", 0],
                "vae": ["1", 2],
            },
        },
        "8": {
            "class_type": "SaveAudioAdvanced",
            "inputs": {
                "audio": ["7", 0],
                "filename_prefix": f"audio/{name}",
                "format": "flac",
            },
        },
    }


def queue_prompt(prompt: dict) -> dict:
    resp = requests.post(f"{COMFYUI_URL}/prompt", json={"prompt": prompt}, timeout=30)
    resp.raise_for_status()
    return resp.json()


def check_status(prompt_id: str) -> dict:
    resp = requests.get(f"{COMFYUI_URL}/history/{prompt_id}", timeout=10)
    resp.raise_for_status()
    return resp.json()


def wait_for_completion(prompt_id: str, timeout: int = 600) -> dict:
    start = time.time()
    while time.time() - start < timeout:
        history = check_status(prompt_id)
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(2)
    raise TimeoutError(f"Prompt {prompt_id} did not complete within {timeout}s")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Batch generate audio with Stable Audio 3 Small-SFX")
    parser.add_argument("--list", action="store_true", help="List available presets")
    parser.add_argument("--names", nargs="*", help="Generate specific presets")
    parser.add_argument("--dry-run", action="store_true", help="Print without submitting")
    args = parser.parse_args()

    if args.list:
        print("Available audio presets (Stable Audio 3 Small-SFX):")
        for name, preset in sorted(AUDIO_PROMPTS.items()):
            seconds = preset.get("seconds", 2.0)
            print(f"  {name:25s} ({seconds:.1f}s) - {preset['positive'][:60]}...")
        return

    names = args.names if args.names else list(AUDIO_PROMPTS.keys())
    print(f"Generating {len(names)} audio files with Stable Audio 3 Small-SFX...")
    print(f"ComfyUI: {COMFYUI_URL}")
    print()

    for i, name in enumerate(names):
        if name not in AUDIO_PROMPTS:
            print(f"  [{i+1}/{len(names)}] SKIP: '{name}' not found")
            continue

        preset = AUDIO_PROMPTS[name]
        seconds = preset.get("seconds", 2.0)
        print(f"  [{i+1}/{len(names)}] {name} ({seconds:.1f}s)")
        print(f"    + {preset['positive'][:80]}...")

        if args.dry_run:
            continue

        try:
            prompt = build_prompt(name, preset)
            result = queue_prompt(prompt)
            prompt_id = result.get("prompt_id")
            print(f"    -> queued: {prompt_id}")

            output = wait_for_completion(prompt_id)
            status = output.get("status", {})
            if status.get("completed", False):
                print(f"    done")
            else:
                print(f"    failed: {status}")
        except Exception as e:
            print(f"    error: {e}")

        print()

    print("Done! Check ComfyUI output/audio/ for generated files.")


if __name__ == "__main__":
    main()
