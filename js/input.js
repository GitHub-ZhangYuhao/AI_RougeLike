// 键盘 + 鼠标输入：维护按住状态、本帧新按下的边沿事件、鼠标位置与点击
export class Input {
  constructor(target = globalThis, canvas = null) {
    this.down = new Set();
    this.pressed = new Set(); // 本帧刚按下（边沿），每帧末清空
    this.mouse = { x: 0, y: 0 };
    this._clicked = false;

    this._onDown = (e) => {
      if (e.code.startsWith('Arrow') || e.code === 'Space') e.preventDefault?.();
      if (!this.down.has(e.code)) this.pressed.add(e.code);
      this.down.add(e.code);
    };
    this._onUp = (e) => this.down.delete(e.code);
    target.addEventListener('keydown', this._onDown);
    target.addEventListener('keyup', this._onUp);

    if (canvas && canvas.addEventListener) {
      canvas.addEventListener('mousemove', (e) => {
        const rect = canvas.getBoundingClientRect ? canvas.getBoundingClientRect() : { left: 0, top: 0 };
        this.mouse.x = (e.clientX ?? 0) - rect.left;
        this.mouse.y = (e.clientY ?? 0) - rect.top;
      });
      canvas.addEventListener('mousedown', () => { this._clicked = true; });
    }
  }

  // 返回归一化的移动轴 {x, y}
  axis() {
    let x = 0, y = 0;
    if (this.down.has('KeyA') || this.down.has('ArrowLeft')) x -= 1;
    if (this.down.has('KeyD') || this.down.has('ArrowRight')) x += 1;
    if (this.down.has('KeyW') || this.down.has('ArrowUp')) y -= 1;
    if (this.down.has('KeyS') || this.down.has('ArrowDown')) y += 1;
    if (x !== 0 && y !== 0) {
      const inv = 1 / Math.SQRT2; // 斜走不加速
      x *= inv; y *= inv;
    }
    return { x, y };
  }

  wasPressed(code) { return this.pressed.has(code); }
  mouseClicked() { return this._clicked; }
  endFrame() { this.pressed.clear(); this._clicked = false; }
}
