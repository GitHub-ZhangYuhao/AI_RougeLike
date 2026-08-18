# -*- coding: utf-8 -*-
"""ComfyUI API driver for fire-VFX flipbook pipeline (agent beta, 2026-08-18).

Stage A: Krea-2 Turbo t2i keyframes (768x768, 8 steps, euler/simple, CFG 1.0)
Stage B: MiniMax H3 fl2va first/last-frame video (768x768, 124 frames @24fps, 20 steps res_multistep)

Usage:
  python driver_comfy.py keyframes
  python driver_comfy.py videos
"""
import json
import sys
import time
import urllib.request
import urllib.parse
import uuid
import os

SERVER = "http://127.0.0.1:8188"
BASE = os.path.dirname(os.path.abspath(__file__))
KEYFRAME_DIR = os.path.join(BASE, "keyframes")
VIDEO_DIR = os.path.join(BASE, "videos")
CLIENT_ID = str(uuid.uuid4())

STYLE_SUFFIX = (
    "for a 2D video game VFX sprite, chibi Q-version cartoon style, vibrant saturated colors, "
    "anime-style game asset, solid black background, clean isolated game asset, high quality game VFX art"
)

KEYFRAMES = {
    "kf_furnace_loop": {
        "seed": 2026081801,
        "prefix": "vfxanim/kf_furnace_loop",
        "prompt": (
            "A horizontal burning flame path strip seen from a slightly top-down angle, spanning the full width of the frame "
            "as one continuous band across the middle, bright orange-red fire with yellow-white hot core, small ember sparks "
            "and tiny flame tongues rising upward from the ground fire band, " + STYLE_SUFFIX
        ),
    },
    "kf_cloak_charge": {
        "seed": 2026081802,
        "prefix": "vfxanim/kf_cloak_charge",
        "prompt": (
            "A compact circular ring of small swirling fire flames charging energy around an empty center point, "
            "orange-red fire ring with glowing yellow-hot inner edge, embers spiraling inward, flames contained in a "
            "neat circle centered in the frame, " + STYLE_SUFFIX
        ),
    },
    "kf_cloak_fade": {
        "seed": 2026081803,
        "prefix": "vfxanim/kf_cloak_fade",
        "prompt": (
            "The aftermath of a circular fire explosion dissipating outward, a wide sparse ring of faint orange embers, "
            "thin smoke wisps and a few dying dark-red flame sparks drifting outward, nearly extinguished, "
            "large circle centered in the frame reaching toward the frame edges, " + STYLE_SUFFIX
        ),
    },
}

VIDEOS = {
    "furnace_flame_loop": {
        "noise_seed": 2026081811,
        "prefix": "video/MiniMax_H3_furnace_flame_loop",
        "first": "kf_furnace_loop",
        "last": "kf_furnace_loop",  # same image both ends -> seamless loop
        "prompt": (
            "Fixed camera, slightly top-down view of a horizontal band of fire burning on the ground, spanning the full "
            "width of the frame. The flames flicker and dance continuously in place: flame tongues rise and fall, the "
            "yellow-white hot core pulses, small ember sparks pop and drift upward, subtle heat shimmer. The fire stays "
            "within the same horizontal band the whole time. Motion is smooth, seamless and loops perfectly. "
            "No camera movement, no zoom, no pan. Audio: steady crackling fire sound."
        ),
    },
    "cloak_fire_burst": {
        "noise_seed": 2026081812,
        "prefix": "video/MiniMax_H3_cloak_fire_burst",
        "first": "kf_cloak_charge",
        "last": "kf_cloak_fade",
        "prompt": (
            "Fixed camera, centered composition on black background. A compact ring of fire charges up, swirling faster "
            "and growing brighter, then violently bursts outward into a large circular explosion of flames and sparks "
            "expanding toward the frame edges, and finally the fire dissipates into drifting faint embers and thin smoke "
            "that fade away. One continuous charge-burst-dissipate sequence. No camera movement, no zoom. "
            "Audio: rising fire whoosh, a deep burst explosion, then crackling fading out."
        ),
    },
}


def api_post(path, payload):
    req = urllib.request.Request(
        SERVER + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def api_get(path):
    with urllib.request.urlopen(SERVER + path, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def queue_and_wait(graph, tag, timeout_s=3600):
    resp = api_post("/prompt", {"prompt": graph, "client_id": CLIENT_ID})
    if "prompt_id" not in resp:
        raise RuntimeError(f"[{tag}] queue rejected: {json.dumps(resp)[:2000]}")
    pid = resp["prompt_id"]
    print(f"[{tag}] queued prompt_id={pid}", flush=True)
    start = time.time()
    while True:
        if time.time() - start > timeout_s:
            raise TimeoutError(f"[{tag}] timed out after {timeout_s}s")
        time.sleep(3)
        try:
            q = api_get("/queue")
        except Exception as e:
            print(f"[{tag}] queue poll error: {e}", flush=True)
            continue
        running = [item[1] for item in q.get("queue_running", [])]
        pending = [item[1] for item in q.get("queue_pending", [])]
        state = "running" if pid in running else ("pending" if pid in pending else "done?")
        hist = api_get(f"/history/{pid}")
        if pid in hist:
            out = hist[pid].get("outputs", {})
            status = hist[pid].get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(f"[{tag}] FAILED: {json.dumps(status)[:3000]}")
            print(f"[{tag}] finished in {time.time()-start:.1f}s", flush=True)
            return out
        print(f"[{tag}] {state} elapsed={time.time()-start:.0f}s", flush=True)


def download_outputs(outputs, dest_dir, tag):
    os.makedirs(dest_dir, exist_ok=True)
    saved = []
    for node_out in outputs.values():
        for kind in ("images", "videos", "gifs"):
            for item in node_out.get(kind, []) or []:
                fn, sub, typ = item["filename"], item.get("subfolder", ""), item.get("type", "output")
                qs = urllib.parse.urlencode({"filename": fn, "subfolder": sub, "type": typ})
                with urllib.request.urlopen(f"{SERVER}/view?{qs}", timeout=120) as r:
                    data = r.read()
                dst = os.path.join(dest_dir, fn)
                with open(dst, "wb") as f:
                    f.write(data)
                saved.append(dst)
                print(f"[{tag}] saved {dst} ({len(data)} bytes)", flush=True)
    return saved


def upload_image(path, name):
    boundary = "----comfybeta" + uuid.uuid4().hex
    body = b""
    body += f"--{boundary}\r\n".encode()
    body += f'Content-Disposition: form-data; name="image"; filename="{name}"\r\n'.encode()
    body += b"Content-Type: image/png\r\n\r\n"
    with open(path, "rb") as f:
        body += f.read()
    body += b"\r\n"
    body += f"--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n'
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        SERVER + "/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def krea2_graph(prompt, seed, prefix, size=768):
    return {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_fp8_scaled.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["11", 0]}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": size, "height": size, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {
            "model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
            "seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": prefix}},
    }


def minimax_graph(tag, cfg):
    return {
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_h3_fl2va_pruned_int8_convrot.safetensors", "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors", "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_video_vae_fp16.safetensors"}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_audio_vae_fp32.safetensors"}},
        "114": {"class_type": "LoadImage", "inputs": {"image": KEYFRAMES[cfg["first"]]["prefix"].split("/")[-1] + "_final.png"}},
        "115": {"class_type": "LoadImage", "inputs": {"image": KEYFRAMES[cfg["last"]]["prefix"].split("/")[-1] + "_final.png"}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "prompt": cfg["prompt"],
            "width": 768, "height": 768, "length": 124,
            "first_frame": ["114", 0], "last_frame": ["115", 0]}},
        "15": {"class_type": "RandomNoise", "inputs": {"noise_seed": cfg["noise_seed"]}},
        "17": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "9": {"class_type": "BasicScheduler", "inputs": {"model": ["6", 0], "scheduler": "simple", "steps": 20, "denoise": 1.0}},
        "16": {"class_type": "BasicGuider", "inputs": {"model": ["6", 0], "conditioning": ["104", 0]}},
        "14": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["15", 0], "guider": ["16", 0], "sampler": ["17", 0], "sigmas": ["9", 0], "latent_image": ["104", 1]}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["11", 0]}},
        "23": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["14", 0], "vae": ["24", 0]}},
        "91": {"class_type": "CreateVideo", "inputs": {"images": ["10", 0], "audio": ["23", 0], "fps": 24, "bit_depth": 8}},
        "92": {"class_type": "SaveVideo", "inputs": {"video": ["91", 0], "filename_prefix": cfg["prefix"], "format": "mp4", "codec": "auto"}},
    }


def stage_keyframes():
    os.makedirs(KEYFRAME_DIR, exist_ok=True)
    for tag, cfg in KEYFRAMES.items():
        print(f"===== keyframe {tag} =====", flush=True)
        graph = krea2_graph(cfg["prompt"], cfg["seed"], cfg["prefix"])
        out = queue_and_wait(graph, tag, timeout_s=1800)
        files = download_outputs(out, KEYFRAME_DIR, tag)
        # normalize to <tag>_final.png
        for f in files:
            dst = os.path.join(KEYFRAME_DIR, tag + "_final.png")
            if os.path.abspath(f) != os.path.abspath(dst):
                os.replace(f, dst)
        print(f"[{tag}] final: {os.path.join(KEYFRAME_DIR, tag + '_final.png')}", flush=True)


def stage_videos():
    os.makedirs(VIDEO_DIR, exist_ok=True)
    for tag, cfg in VIDEOS.items():
        print(f"===== video {tag} =====", flush=True)
        first = os.path.join(KEYFRAME_DIR, cfg["first"] + "_final.png")
        last = os.path.join(KEYFRAME_DIR, cfg["last"] + "_final.png")
        r1 = upload_image(first, cfg["first"] + "_final.png")
        r2 = upload_image(last, cfg["last"] + "_final.png") if cfg["last"] != cfg["first"] else r1
        print(f"[{tag}] uploaded: {r1} / {r2}", flush=True)
        graph = minimax_graph(tag, cfg)
        out = queue_and_wait(graph, tag, timeout_s=5400)
        download_outputs(out, VIDEO_DIR, tag)


def main():
    stage = sys.argv[1] if len(sys.argv) > 1 else "keyframes"
    if stage == "keyframes":
        stage_keyframes()
    elif stage == "videos":
        stage_videos()
    else:
        raise SystemExit(f"unknown stage {stage}")


if __name__ == "__main__":
    main()
