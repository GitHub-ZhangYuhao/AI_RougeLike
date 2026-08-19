extends RefCounted
## 序列帧图集（flipbook）纯函数：帧序号 ↔ 图集区域映射，可确定性单测。
## 图集规格：2000×2000、5×5 网格、cell 400×400、内容 384×384 居中、8px 透明 gutter、行优先。
## 见 ArtAsset/Image/VFX/gen_20260818_anim/PRODUCTION_REPORT.md。


## 行优先网格：frame → col=frame%cols、row=frame/cols；region = 单元左上角 + gutter 偏移，尺寸为 content。
static func frame_region(frame: int, cols: int = 5, cell: int = 400, content: int = 384, gutter: int = 8) -> Rect2:
	var col: int = frame % cols
	var row: int = floori(float(frame) / float(cols))
	return Rect2(col * cell + gutter, row * cell + gutter, content, content)


## 一次性播放：progress [0,1] → 帧序号 [0, frame_count-1]（越界 progress 截断，不会取到范围外帧）。
static func frame_for_progress(progress: float, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	var clamped: float = clampf(progress, 0.0, 1.0)
	return clampi(int(floor(clamped * frame_count)), 0, frame_count - 1)
