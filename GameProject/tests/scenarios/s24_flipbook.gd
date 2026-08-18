extends RefCounted
## [24] 序列帧图集（flipbook）数学冒烟：
##   - frame_region 网格数学（四角 + 中间帧）
##   - frame_for_progress 边界（0、0.999、1.0）
##   - 火炉循环帧范围合法性（循环区间 0..23，frame24 为 frame0 接缝副本）
## 规格见 ArtAsset/Image/VFX/gen_20260818_anim/PRODUCTION_REPORT.md。

const FlipbookScript: GDScript = preload("res://logic/systems/flipbook.gd")


func title() -> String: return "[24] Flipbook atlas math"


func run(runner) -> void:
    _check_frame_region_grid(runner)
    _check_frame_for_progress(runner)
    _check_loop_range(runner)


# 网格数学：行优先 5×5、cell 400、content 384、gutter 8 → region = (col*400+8, row*400+8, 384, 384)
func _check_frame_region_grid(runner) -> void:
    runner.check(FlipbookScript.frame_region(0) == Rect2(8, 8, 384, 384),
            "[24] frame_region(0) is first cell")
    runner.check(FlipbookScript.frame_region(4) == Rect2(1608, 8, 384, 384),
            "[24] frame_region(4) is top-right corner")
    runner.check(FlipbookScript.frame_region(12) == Rect2(808, 808, 384, 384),
            "[24] frame_region(12) is center frame")
    runner.check(FlipbookScript.frame_region(20) == Rect2(8, 1608, 384, 384),
            "[24] frame_region(20) is bottom-left corner")
    runner.check(FlipbookScript.frame_region(24) == Rect2(1608, 1608, 384, 384),
            "[24] frame_region(24) is bottom-right corner")
    # 全部 25 帧：region 落在 2000×2000 图集内、按 cell + gutter 对齐、尺寸为 content
    var all_valid: bool = true
    for frame in 25:
        var region: Rect2 = FlipbookScript.frame_region(frame)
        var aligned: bool = int(region.position.x - 8) % 400 == 0 and int(region.position.y - 8) % 400 == 0
        var inside: bool = region.position.x >= 0 and region.position.y >= 0 and region.end.x <= 2000 and region.end.y <= 2000
        var sized: bool = region.size == Vector2(384, 384)
        if not (aligned and inside and sized):
            all_valid = false
    runner.check(all_valid, "[24] all 25 frame regions aligned inside atlas and sized 384")
    # 参数化防御：非默认列数同样成立
    runner.check(FlipbookScript.frame_region(3, 2) == Rect2(408, 408, 384, 384),
            "[24] frame_region respects custom cols")


# 一次性播放进度映射：0..count-1 截断、单调不减
func _check_frame_for_progress(runner) -> void:
    runner.check(FlipbookScript.frame_for_progress(0.0, 25) == 0, "[24] progress 0.0 -> frame 0")
    runner.check(FlipbookScript.frame_for_progress(0.5, 25) == 12, "[24] progress 0.5 -> frame 12")
    runner.check(FlipbookScript.frame_for_progress(0.999, 25) == 24, "[24] progress 0.999 -> frame 24")
    runner.check(FlipbookScript.frame_for_progress(1.0, 25) == 24, "[24] progress 1.0 clamps to last frame")
    runner.check(FlipbookScript.frame_for_progress(-0.5, 25) == 0, "[24] negative progress clamps to 0")
    runner.check(FlipbookScript.frame_for_progress(2.0, 25) == 24, "[24] progress > 1 clamps to last frame")
    var in_range: bool = true
    var monotonic: bool = true
    var last_frame: int = -1
    for i in 101:
        var frame: int = FlipbookScript.frame_for_progress(float(i) / 100.0, 25)
        if frame < 0 or frame > 24:
            in_range = false
        if frame < last_frame:
            monotonic = false
        last_frame = frame
    runner.check(in_range, "[24] 0..1 sweep stays inside [0, 24]")
    runner.check(monotonic, "[24] 0..1 sweep is monotonic")


# 循环合法性：渲染层帧号 = int(floor(t * 4.8387)) % 24（火炉循环区间 0..23），任意时刻必须落在 0..23
func _check_loop_range(runner) -> void:
    var fps: float = 4.8387
    var times: Array[float] = [0.0, 0.2, 0.41, 1.0, 2.48, 4.96, 10.0, 60.0, 599.9]
    var all_valid: bool = true
    for t in times:
        var frame: int = int(floor(t * fps)) % 24
        var region: Rect2 = FlipbookScript.frame_region(frame)
        if frame < 0 or frame > 23:
            all_valid = false
        if region.end.x > 2000.0 or region.end.y > 2000.0:
            all_valid = false
    runner.check(all_valid, "[24] furnace loop frame floor(t*4.8387)%24 always in 0..23")
    # frame24 是 frame0 的接缝副本，占据独立单元（不与 frame0 重合）
    runner.check(FlipbookScript.frame_region(24) != FlipbookScript.frame_region(0),
            "[24] seam frame 24 occupies its own cell distinct from frame 0")

