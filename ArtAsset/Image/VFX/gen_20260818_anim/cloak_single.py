# -*- coding: utf-8 -*-
"""Cloak fire burst video: single keyframe -> MiniMax H3 i2v (compliant pipeline, 2026-08-18)."""
import json, time, os, sys, uuid, urllib.request, urllib.parse

SERVER = "http://127.0.0.1:8188"
BASE = os.path.dirname(os.path.abspath(__file__))
KEYFRAME = os.path.join(BASE, "keyframes", "kf_cloak_charge_final.png")
VIDEO_DIR = os.path.join(BASE, "videos")
CLIENT_ID = str(uuid.uuid4())
TAG = "cloak_fire_burst_single"

PROMPT = (
    "Fixed camera, centered composition on black background. A compact ring of fire charges up, swirling faster "
    "and growing brighter, then violently bursts outward into a large circular explosion of flames and sparks "
    "expanding toward the frame edges, and finally the fire dissipates into drifting faint embers and thin smoke "
    "that fade away. One continuous charge-burst-dissipate sequence. No camera movement, no zoom. "
    "Audio: rising fire whoosh, a deep burst explosion, then crackling fading out."
)

def api_post(path, payload):
    req = urllib.request.Request(SERVER + path, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))

def api_get(path):
    with urllib.request.urlopen(SERVER + path, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))

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
    req = urllib.request.Request(SERVER + "/upload/image", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, method="POST")
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))

def main():
    os.makedirs(VIDEO_DIR, exist_ok=True)
    r = upload_image(KEYFRAME, "kf_cloak_charge_final.png")
    print(f"[{TAG}] uploaded: {r}", flush=True)
    graph = {
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_h3_fl2va_pruned_int8_convrot.safetensors", "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors", "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_video_vae_fp16.safetensors"}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_audio_vae_fp32.safetensors"}},
        "114": {"class_type": "LoadImage", "inputs": {"image": "kf_cloak_charge_final.png"}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "prompt": PROMPT,
            "width": 768, "height": 768, "length": 124,
            "first_frame": ["114", 0]}},
        "15": {"class_type": "RandomNoise", "inputs": {"noise_seed": 2026081812}},
        "17": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "9": {"class_type": "BasicScheduler", "inputs": {"model": ["6", 0], "scheduler": "simple", "steps": 20, "denoise": 1.0}},
        "16": {"class_type": "BasicGuider", "inputs": {"model": ["6", 0], "conditioning": ["104", 0]}},
        "14": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["15", 0], "guider": ["16", 0], "sampler": ["17", 0], "sigmas": ["9", 0], "latent_image": ["104", 1]}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["11", 0]}},
        "23": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["14", 0], "vae": ["24", 0]}},
        "91": {"class_type": "CreateVideo", "inputs": {"images": ["10", 0], "audio": ["23", 0], "fps": 24, "bit_depth": 8}},
        "92": {"class_type": "SaveVideo", "inputs": {"video": ["91", 0], "filename_prefix": "video/MiniMax_H3_cloak_fire_burst", "format": "mp4", "codec": "auto"}},
    }
    resp = api_post("/prompt", {"prompt": graph, "client_id": CLIENT_ID})
    if "prompt_id" not in resp:
        raise RuntimeError(f"[{TAG}] queue rejected: {json.dumps(resp)[:2000]}")
    pid = resp["prompt_id"]
    print(f"[{TAG}] queued prompt_id={pid}", flush=True)
    start = time.time()
    while True:
        if time.time() - start > 5400:
            raise TimeoutError(f"[{TAG}] timed out")
        time.sleep(3)
        try:
            q = api_get("/queue")
        except Exception as e:
            print(f"[{TAG}] queue poll error: {e}", flush=True)
            continue
        running = [i[1] for i in q.get("queue_running", [])]
        pending = [i[1] for i in q.get("queue_pending", [])]
        state = "running" if pid in running else ("pending" if pid in pending else "done?")
        hist = api_get(f"/history/{pid}")
        if pid in hist:
            status = hist[pid].get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(f"[{TAG}] FAILED: {json.dumps(status)[:3000]}")
            print(f"[{TAG}] finished in {time.time()-start:.1f}s", flush=True)
            for node_out in hist[pid].get("outputs", {}).values():
                for kind in ("images", "videos", "gifs"):
                    for item in node_out.get(kind, []) or []:
                        fn, sub, typ = item["filename"], item.get("subfolder", ""), item.get("type", "output")
                        qs = urllib.parse.urlencode({"filename": fn, "subfolder": sub, "type": typ})
                        with urllib.request.urlopen(f"{SERVER}/view?{qs}", timeout=300) as rr:
                            data = rr.read()
                        dst = os.path.join(VIDEO_DIR, fn)
                        with open(dst, "wb") as f:
                            f.write(data)
                        print(f"[{TAG}] saved {dst} ({len(data)} bytes)", flush=True)
            return
        print(f"[{TAG}] {state} elapsed={time.time()-start:.0f}s", flush=True)

if __name__ == "__main__":
    main()
