extends RefCounted
## 序列帧图集（flipbook）纯函数：帧序号 → 图集区域映射，可确定性单测。
## 支持两种图集规格：
##   - 2000×2000（cloakFireBurst / fireBall）：5×5 网格，cell 400，content 384，gutter 8
##   - 2048×2048（furnaceFlame）：5×5 网格，cell ≈409.6（不均匀），content 393，gutter 8
## 通过 atlas_size 参数区分，默认 2000 保持向后兼容。

## 行优先网格：frame → col=frame%cols、row=frame/cols；
## region = 单元左上角 + gutter 偏移，尺寸为 content。
## atlas_size > 0 时用 roundi(col * atlas_size / cols) 计算边界（处理不均匀 cell）。
static func frame_region(frame: int, cols: int = 5, atlas_size: int = 2000, content: int = 384, gutter: int = 8) -> Rect2:
	var col: int = frame % cols
	var row: int = floori(float(frame) / float(cols))
	var col_start: int = roundi(float(col) * float(atlas_size) / float(cols))
	var row_start: int = roundi(float(row) * float(atlas_size) / float(cols))
	return Rect2(col_start + gutter, row_start + gutter, content, content)


## 一次性播放：progress [0,1] → 帧序号 [0, frame_count-1]（越界 progress 截断，不会取到范围外帧）。
static func frame_for_progress(progress: float, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	var clamped: float = clampf(progress, 0.0, 1.0)
	return clampi(int(floor(clamped * frame_count)), 0, frame_count - 1)
