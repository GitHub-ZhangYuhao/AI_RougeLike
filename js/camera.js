// 相机：指数平滑跟随目标
export class Camera {
  constructor(x = 0, y = 0) { this.x = x; this.y = y; }
  snapTo(t) { this.x = t.x; this.y = t.y; }
  follow(target, dt, lerpRate) {
    const t = 1 - Math.exp(-lerpRate * dt);
    this.x += (target.x - this.x) * t;
    this.y += (target.y - this.y) * t;
  }
}
