import fs from 'node:fs';
import path from 'node:path';
const BASE = 'http://127.0.0.1:8188';
const OUT_DIR = 'C:/WorkSpace/AIGame/Experimental/art-style-preview';
const IDS = {
  A_pixel: '34c25be3-a99f-427e-bd32-bf26044fecdc',
  B_ink: 'fbdddf02-526e-4a14-8e8f-5eb02e8127b7',
  C_gothic_oil: 'cac17f62-6093-4a2d-8d18-1136b85e7017',
  D_guochao: 'a953250d-fcd2-4fd4-9737-b1e686e74f4f',
  E_anime: '78884f7f-6113-40b8-8afa-063bdb452ff4',
};
fs.mkdirSync(OUT_DIR, { recursive: true });
for (const [key, pid] of Object.entries(IDS)) {
  const data = await (await fetch(`${BASE}/history/${pid}`)).json();
  const outs = data[pid].outputs || {};
  for (const nodeOut of Object.values(outs)) {
    for (const img of (nodeOut.images || [])) {
      const q = new URLSearchParams({ filename: img.filename, subfolder: img.subfolder || '', type: img.type || 'output' });
      const r = await fetch(`${BASE}/view?${q}`);
      if (!r.ok) throw new Error(`view ${img.filename}: ${r.status}`);
      const file = path.join(OUT_DIR, `${key}${path.extname(img.filename) || '.png'}`);
      fs.writeFileSync(file, Buffer.from(await r.arrayBuffer()));
      console.log('saved', file);
    }
  }
}
console.log('DOWNLOAD DONE');
