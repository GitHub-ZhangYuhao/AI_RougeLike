extends SceneTree
## Minigame texture budget tool: rewrites process/size_limit in texture
## .import files so oversized sheets shrink at import time (non-destructive,
## source files untouched; revert by resetting size_limit and reimporting).
##
## Sprite sheets are cut proportionally at runtime (UV-based atlas regions in
## player_sprite_frames.gd / world_art_view.gd), so uniform downscale keeps
## frame alignment intact.
##
## Usage (dry-run):
##   Godot --headless --path . --script res://tools/minigame_size_limit.gd
## Apply:
##   Godot --headless --path . --script res://tools/minigame_size_limit.gd -- --apply
## Slim profile (preset.3 budget):
##   Godot --headless --path . --script res://tools/minigame_size_limit.gd -- --profile slim --apply
## Then run --import to rebuild affected textures. minigame_export.ps1 does
## this automatically around the preset.3 export and restores the default
## limits afterwards (.import snapshot), so the repo never stays in slim state.

# prefix -> max longest side (pixels)
# default profile: full-quality minigame package (preset.2, WeChat 30MB budget)
const RULES: Array = [
	["res://assets/sprites/", 512],
	["res://assets/vfx/", 512],
	["res://assets/terrain/", 1024],
	["res://assets/environment/", 1024],
	["res://assets/ui/", 1024],
]
# slim profile: tighter limits for preset.3 (douyin-oriented budget);
# minigame_export.ps1 snapshots .import files and restores them afterwards
const RULES_SLIM: Array = [
	["res://assets/sprites/", 256],
	["res://assets/vfx/", 256],
	["res://assets/terrain/", 512],
	["res://assets/environment/", 512],
	["res://assets/ui/", 512],
]

var apply_mode := false
var rules: Array = RULES
var changed := 0
var skipped := 0
var bytes_before := 0
var bytes_after_est := 0
var report_lines: Array[String] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	apply_mode = args.has("--apply")
	if args.has("--profile") or args.has("slim"):
		# usage: -- --profile slim --apply   (also accepts a bare "slim")
		rules = RULES_SLIM
	_scan_dir("res://assets")
	report_lines.push_front("=== minigame_size_limit (%s, profile=%s) ===" % [
		"APPLY" if apply_mode else "dry-run",
		"slim" if rules == RULES_SLIM else "default"])
	report_lines.append("")
	report_lines.append("files to change: %d, untouched: %d" % [changed, skipped])
	report_lines.append("etc2 ctex: %.2f MB -> est %.2f MB" % [
		bytes_before / 1048576.0, bytes_after_est / 1048576.0])
	print("\n".join(report_lines))
	quit(0)


func _rule_for(path: String) -> int:
	for rule in rules:
		if path.begins_with(rule[0]):
			return rule[1]
	return 0


func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		elif entry.ends_with(".import"):
			_process_import(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _process_import(import_path: String) -> void:
	var text := FileAccess.get_file_as_string(import_path)
	if text.is_empty() or not text.contains("process/size_limit="):
		return  # not a texture import
	var source := _source_of(text)
	var prefix_limit := _rule_for(source)
	if prefix_limit <= 0:
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null:
		push_warning("cannot load source image: %s" % source)
		return
	var longest := maxi(image.get_width(), image.get_height())
	var current := _current_limit(text)
	if longest <= prefix_limit or current == prefix_limit:
		skipped += 1
		return
	var etc2_path := _remap_etc2(text)
	var current_bytes := _file_size(etc2_path)
	# the stored ctex is already downscaled when a smaller limit was applied
	# before, so scale from the effective current size, not the source size
	var effective := longest if current <= 0 else mini(longest, current)
	var est_bytes := int(current_bytes * float(prefix_limit * prefix_limit) / float(effective * effective))
	bytes_before += current_bytes
	bytes_after_est += est_bytes
	changed += 1
	report_lines.append("%-70s %4dx%-4d limit %d->%d  %6.2f -> %5.2f MB" % [
		source.trim_prefix("res://"), image.get_width(), image.get_height(),
		current, prefix_limit, current_bytes / 1048576.0, est_bytes / 1048576.0])
	if apply_mode:
		var updated := text.replace(
			"process/size_limit=%d" % current,
			"process/size_limit=%d" % prefix_limit)
		var file := FileAccess.open(import_path, FileAccess.WRITE)
		if file != null:
			file.store_string(updated)
			file.close()


func _source_of(text: String) -> String:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("source_file=\""):
			return l.trim_prefix("source_file=\"").trim_suffix("\"")
	return ""


func _remap_etc2(text: String) -> String:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("path.etc2=\""):
			return l.trim_prefix("path.etc2=\"").trim_suffix("\"")
		if l.begins_with("path=\""):
			return l.trim_prefix("path=\"").trim_suffix("\"")
	return ""


func _current_limit(text: String) -> int:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("process/size_limit="):
			return l.trim_prefix("process/size_limit=").to_int()
	return 0


func _file_size(res_path: String) -> int:
	if res_path.is_empty() or not FileAccess.file_exists(res_path):
		return 0
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size