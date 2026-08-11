import { Input } from './input.js';
import { Game } from './game.js';

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
const input = new Input(typeof window !== 'undefined' ? window : globalThis, canvas);

let viewW = 0, viewH = 0, dpr = 1;
function resize() {
  dpr = (typeof window !== 'undefined' && window.devicePixelRatio) || 1;
  viewW = window.innerWidth;
  viewH = window.innerHeight;
  canvas.width = Math.round(viewW * dpr);
  canvas.height = Math.round(viewH * dpr);
  canvas.style.width = viewW + 'px';
  canvas.style.height = viewH + 'px';
}
window.addEventListener('resize', resize);
resize();

const game = new Game(input);
globalThis.__game = game; // 调试入口：浏览器控制台可用 __game 查看/修改状态

// 固定时间步长：逻辑按 60Hz 推进，渲染每帧执行
const STEP = 1 / 60;
let acc = 0;
let last = null;

function frame(tms) {
  requestAnimationFrame(frame);
  if (last === null) { last = tms; return; }
  let dt = (tms - last) / 1000;
  last = tms;
  if (dt > 0.25) dt = 0.25; // 切后台回来不堆积
  acc += dt;
  while (acc >= STEP) {
    game.update(STEP, viewW, viewH);
    input.endFrame();
    acc -= STEP;
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  game.render(ctx, viewW, viewH);
}
requestAnimationFrame(frame);
