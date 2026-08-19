"""
ComfyUI 音频批量生成脚本 — ACE-Step 1.5

使用方法：
  1. 确保 ComfyUI Desktop 正在运行，AIO 模型在 models/checkpoints/
  2. 运行：python generate_audio.py
  3. 生成的音频在 ComfyUI output/audio/ 目录

依赖：requests（pip install requests）
"""

import json
import time
import random
import requests
from pathlib import Path

COMFYUI_URL = "http://127.0.0.1:8188"

# ============================================================
# ACE-Step 1.5 音效提示词预设
# ============================================================

AUDIO_PROMPTS = {
    # === 背景音乐 ===
    "bgm_menu": {
        "tags": "serene Chinese traditional night ambiance, soft erhu melody, gentle guzheng plucks, peaceful temple bells, game menu music loop, calm mysterious",
        "negative": "low quality, noisy, distorted, vocals, speech, fast tempo",
        "seconds": 15.0,
    },
    "bgm_battle": {
        "tags": "intense dark fantasy battle music, fast Chinese war drums, aggressive erhu, thundering taiko percussion, action game combat soundtrack",
        "negative": "low quality, noisy, calm, peaceful, slow tempo, vocals",
        "seconds": 15.0,
    },
    "bgm_boss": {
        "tags": "ominous boss theme, deep bass drone, menacing Chinese pipa tremolo, thunderous drums, supernatural horror, final boss encounter",
        "negative": "low quality, noisy, calm, happy, cheerful, vocals",
        "seconds": 15.0,
    },

    # === 武器音效 ===
    "sfx_sword_slash": {
        "tags": "sharp sword slash sound effect, metallic ring, swift air cut, single strike, clean crisp, game audio",
        "negative": "low quality, long reverb, music, multiple hits",
        "seconds": 1.0,
    },
    "sfx_sword_projectile": {
        "tags": "magical flying sword whoosh, ethereal blade sound, crystal energy trail, mystical hum, projectile, game audio",
        "negative": "low quality, music, explosion, voice",
        "seconds": 1.5,
    },
    "sfx_fire_burn": {
        "tags": "crackling fire ambient, continuous flame, warm burning embers, magical fire aura, sustained burning, game audio",
        "negative": "low quality, explosion, music, silence, voice",
        "seconds": 2.0,
    },
    "sfx_fire_blast": {
        "tags": "powerful fire shockwave blast, deep bass impact, explosive burst, concussive wave, single explosion, game audio",
        "negative": "low quality, sustained fire, music, voice",
        "seconds": 1.5,
    },
    "sfx_thunder_bolt": {
        "tags": "electric thunder bolt, crackling lightning zap, magical electric discharge, single strike, sharp crack, game audio",
        "negative": "low quality, sustained electricity, music, voice, rain",
        "seconds": 1.0,
    },
    "sfx_chain_lightning": {
        "tags": "chain lightning strike, multiple electric arcs, branching thunder crack, cascading energy, game audio",
        "negative": "low quality, single spark, music, voice, rain",
        "seconds": 2.0,
    },
    "sfx_furnace_explosion": {
        "tags": "powerful furnace explosion burst, massive fire eruption, alchemical cauldron blast, intense heat wave, game audio",
        "negative": "low quality, small fire, sustained flame, music, voice",
        "seconds": 2.0,
    },
    "sfx_jade_ring": {
        "tags": "jade ring spinning whoosh, crystalline ice chime, frozen wind chime, spinning blade ring, magical ice, game audio",
        "negative": "low quality, heavy impact, explosion, music, voice",
        "seconds": 2.0,
    },
    "sfx_summon": {
        "tags": "dark summoning ritual sound, ghostly whisper, skeleton rising, necromantic incantation, supernatural portal, game audio",
        "negative": "low quality, explosion, bright happy sound, music, voice",
        "seconds": 2.0,
    },

    # === 战斗反馈 ===
    "sfx_enemy_hit": {
        "tags": "soft flesh impact hit, muted thud, combat damage, single punch, short impact, game audio",
        "negative": "low quality, explosion, music, bone crack",
        "seconds": 0.5,
    },
    "sfx_enemy_death": {
        "tags": "enemy defeat poof, dissipating smoke, vanishing creature, monster destruction, short dissolution, game audio",
        "negative": "low quality, explosion, music, scream, voice",
        "seconds": 1.0,
    },
    "sfx_boss_appear": {
        "tags": "deep ominous horn blast, boss arrival alarm, dark announcement gong, powerful warning, epic intro, game audio",
        "negative": "low quality, cheerful, music loop, voice, dialogue",
        "seconds": 3.0,
    },
    "sfx_player_hurt": {
        "tags": "painful impact thud, damage taken, heavy hit reaction, short grunt, game audio",
        "negative": "low quality, explosion, music, voice dialogue",
        "seconds": 0.5,
    },

    # === 拾取/UI ===
    "sfx_gem_pickup": {
        "tags": "magical crystal pickup chime, sparkling gem collect, bright ding, short magical chime, game audio",
        "negative": "low quality, explosion, voice, music, long reverb",
        "seconds": 0.5,
    },
    "sfx_rare_pickup": {
        "tags": "legendary item pickup fanfare, treasure discovery, rare loot jingle, magical artifact chime, game audio",
        "negative": "low quality, explosion, voice, dark, scary",
        "seconds": 1.5,
    },
    "sfx_heal": {
        "tags": "healing potion drink, health restore magical chime, warm recovery glow, positive energy, game audio",
        "negative": "low quality, explosion, voice, dark, scary",
        "seconds": 1.0,
    },
    "sfx_levelup": {
        "tags": "level up achievement sound, power upgrade chime, ascending magical tone, rewarding fanfare, game audio",
        "negative": "low quality, voice, dialogue, dark, scary",
        "seconds": 2.0,
    },
    "sfx_ui_click": {
        "tags": "soft button click, gentle tap, interface interaction, subtle UI feedback, clean short click, game audio",
        "negative": "low quality, loud, explosion, music, voice",
        "seconds": 0.3,
    },
    "sfx_coin_spend": {
        "tags": "coin spend sound, purchase confirmation chime, magical transaction, gold coins jingling, game audio",
        "negative": "low quality, explosion, voice, dark",
        "seconds": 0.5,
    },
    "sfx_extraction": {
        "tags": "victory fanfare, mission complete chime, safe return celebration, triumphant short jingle, game audio",
        "negative": "low quality, dark, scary, voice, long",
        "seconds": 3.0,
    },
    "sfx_wave_banner": {
        "tags": "dramatic wave announcement, dark horn signal, battle begins alert, short dramatic sting, game audio",
        "negative": "low quality, music loop, voice, calm",
        "seconds": 2.0,
    },
    "sfx_synergy_activate": {
        "tags": "magical synergy activation, power link established, ethereal energy connection, ascending chime, game audio",
        "negative": "low quality, dark, scary, voice, explosion",
        "seconds": 2.0,
    },
}


def build_prompt(name: str, preset: dict) -> dict:
    """Build a ComfyUI API prompt for ACE-Step 1.5 (AIO checkpoint)."""
    seconds = preset.get("seconds", 2.0)
    seed = random.randint(0, 2**32 - 1)

    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {
                "ckpt_name": "ace_step_1.5_turbo_aio.safetensors",
            },
        },
        "2": {
            "class_type": "TextEncodeAceStepAudio",
            "inputs": {
                "clip": ["1", 1],
                "tags": preset["tags"],
                "lyrics": "",
                "lyrics_strength": 1.0,
            },
        },
        "3": {
            "class_type": "TextEncodeAceStepAudio",
            "inputs": {
                "clip": ["1", 1],
                "tags": preset.get("negative", "low quality, noisy, distorted"),
                "lyrics": "",
                "lyrics_strength": 1.0,
            },
        },
        "4": {
            "class_type": "EmptyAceStep1.5LatentAudio",
            "inputs": {
                "seconds": seconds,
                "batch_size": 1,
            },
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0],
                "seed": seed,
                "steps": 20,
                "cfg": 7.0,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1.0,
            },
        },
        "6": {
            "class_type": "VAEDecodeAudio",
            "inputs": {
                "samples": ["5", 0],
                "vae": ["1", 2],
            },
        },
        "7": {
            "class_type": "SaveAudioAdvanced",
            "inputs": {
                "audio": ["6", 0],
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

    parser = argparse.ArgumentParser(description="Batch generate audio with ACE-Step 1.5")
    parser.add_argument("--list", action="store_true", help="List available presets")
    parser.add_argument("--names", nargs="*", help="Generate specific presets")
    parser.add_argument("--dry-run", action="store_true", help="Print without submitting")
    args = parser.parse_args()

    if args.list:
        print("Available audio presets (ACE-Step 1.5):")
        for name, preset in sorted(AUDIO_PROMPTS.items()):
            seconds = preset.get("seconds", 2.0)
            print(f"  {name:25s} ({seconds:.1f}s) - {preset['tags'][:60]}...")
        return

    names = args.names if args.names else list(AUDIO_PROMPTS.keys())
    print(f"Generating {len(names)} audio files with ACE-Step 1.5...")
    print(f"ComfyUI: {COMFYUI_URL}")
    print()

    for i, name in enumerate(names):
        if name not in AUDIO_PROMPTS:
            print(f"  [{i+1}/{len(names)}] SKIP: '{name}' not found")
            continue

        preset = AUDIO_PROMPTS[name]
        seconds = preset.get("seconds", 2.0)
        print(f"  [{i+1}/{len(names)}] {name} ({seconds:.1f}s)")
        print(f"    + {preset['tags'][:80]}...")

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
