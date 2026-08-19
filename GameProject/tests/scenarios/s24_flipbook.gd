extends RefCounted
## [24] 序列帧图集（flipbook）数学冒烟：
##   - frame_region 网格数学（四角 + 中间帧）
##   - frame_for_progress 边界：0、0.999、1.0
##   - 2048 图集规格验证（furnaceFlameAnim）
##   - 火炉循环帧范围合法性
## 规格：
##   - 2000×2000（cloakFireBurst / fireBall）：5×5，cell 400，content 384，gutter 8
##   - 2048×2048（furnaceFlame）：5×5，cell ≈409.6，content 393，gutter 8
const FlipbookScript: GDScript = preload("res://logic/systems/flipbook.gd")


func title() -> String: return "[24] Flipbook atlas math"


func run(runner) -> void:
    _check_frame_region_2000(runner)
    _check_frame_region_2048(runner)
    _check_frame_for_progress(runner)
    _check_loop_range(runner)


# 2000×2000 图集：默认参数，cell=400，content=384
func _check_frame_region_2000(runner) -> void:
    runner.check(FlipbookScript.frame_region(0) == Rect2(8, 8, 384, 384),
            "[24] 2000: frame_region(0) is first cell")
    runner.check(FlipbookScript.frame_region(4) == Rect2(1608, 8, 384, 384),
            "[24] 2000: frame_region(4) is top-right corner")
    runner.check(FlipbookScript.frame_region(12) == Rect2(808, 808, 384, 384),
            "[24] 2000: frame_region(12) is center frame")
    runner.check(FlipbookScript.frame_region(20) == Rect2(8, 1608, 384, 384),
            "[24] 2000: frame_region(20) is bottom-left corner")
    runner.check(FlipbookScript.frame_region(24) == Rect2(1608, 1608, 384, 384),
            "[24] 2000: frame_region(24) is bottom-right corner")
    # 全部 25 帧：region 落在 2000×2000 图集内
    var all_valid: bool = true
    for frame in 25:
        var region: Rect2 = FlipbookScript.frame_region(frame)
        var inside: bool = region.position.x >= 0 and region.position.y >= 0 and region.end.x <= 2000 and region.end.y <= 2000
        var sized: bool = region.size == Vector2(384, 384)
        if not (inside and sized):
            all_valid = false
    runner.check(all_valid, "[24] 2000: all 25 frame regions inside atlas and sized 384")


# 2048×2048 图集：atlas_size=2048，content=393，gutter=8
func _check_frame_region_2048(runner) -> void:
    # frame 0: col=0, row=0 → (0+8, 0+8, 393, 393)
    runner.check(FlipbookScript.frame_region(0, 5, 2048, 393, 8) == Rect2(8, 8, 393, 393),
            "[24] 2048: frame_region(0) is first cell")
    # frame 4: col=4 → col_start=roundi(4*2048/5)=roundi(1638.4)=1638 → (1638+8, 8, 393, 393)
    runner.check(FlipbookScript.frame_region(4, 5, 2048, 393, 8) == Rect2(1646, 8, 393, 393),
            "[24] 2048: frame_region(4) is top-right corner")
    # frame 12: col=2, row=2 → col_start=roundi(2*2048/5)=roundi(819.2)=819 → (819+8, 819+8, 393, 393)
    runner.check(FlipbookScript.frame_region(12, 5, 2048, 393, 8) == Rect2(827, 827, 393, 393),
            "[24] 2048: frame_region(12) is center frame")
    # frame 24: col=4, row=4 → (1638+8, 1638+8, 393, 393)
    runner.check(FlipbookScript.frame_region(24, 5, 2048, 393, 8) == Rect2(1646, 1646, 393, 393),
            "[24] 2048: frame_region(24) is bottom-right corner")
    # 全部 25 帧：region 落在 2048×2048 图集内
    var all_valid: bool = true
    for frame in 25:
        var region: Rect2 = FlipbookScript.frame_region(frame, 5, 2048, 393, 8)
        var inside: bool = region.position.x >= 0 and region.position.y >= 0 and region.end.x <= 2048 and region.end.y <= 2048
        var sized: bool = region.size == Vector2(393, 393)
        if not (inside and sized):
            all_valid = false
    runner.check(all_valid, "[24] 2048: all 25 frame regions inside atlas and sized 393")


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


# 循环合法性：渲染层帧 = int(floor(t * 8.823529)) % 25，任意时刻必须落在 0..24
func _check_loop_range(runner) -> void:
    var fps: float = 8.823529
    var times: Array[float] = [0.0, 0.2, 0.41, 1.0, 2.48, 4.96, 10.0, 60.0, 599.9]
    var all_valid: bool = true
    for t in times:
        var frame: int = int(floor(t * fps)) % 25
        var region: Rect2 = FlipbookScript.frame_region(frame, 5, 2048, 393, 8)
        if frame < 0 or frame > 24:
            all_valid = false
        if region.end.x > 2048.0 or region.end.y > 2048.0:
            all_valid = false
    runner.check(all_valid, "[24] furnace loop frame floor(t*8.823529)%25 always in 0..24")
    # frame24 与 frame0 占据不同单元
    runner.check(FlipbookScript.frame_region(24, 5, 2048, 393, 8) != FlipbookScript.frame_region(0, 5, 2048, 393, 8),
            "[24] seam frame 24 occupies its own cell distinct from frame 0")
