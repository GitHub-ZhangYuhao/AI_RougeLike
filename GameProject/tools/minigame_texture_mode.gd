extends SceneTree
## Minigame texture compression mode tool: switches texture .import files
## between VRAM (ETC2/S3TC) and Lossy (WebP) compression modes.
##
## Why this exists: the godothub/godot-minigame community WeChat export
## template (Godot Engine for Wechat v4.7.2.rc.custom_build) binds ETC2
## compressed textures to WebGL with an invalid format enum
## (`WebGL: INVALID_ENUM: compressedTexImage2D: invalid format`), silently
## failing to render every VRAM-compressed texture in the exported minigame
## (confirmed via VConsole on both the simulator and a real device — logic
## and hit-testing work fine, only texture binding fails). Switching to Lossy
## (WebP, CPU-decoded, uploaded as a normal uncompressed GL texture) avoids
## the compressed-texture upload path entirely and renders correctly.
##
## Usage (dry-run):
##   Godot --headless --path . --script res://tools/minigame_texture_mode.gd
## Apply (VRAM -> Lossy, for minigame export):
##   Godot --headless --path . --script res://tools/minigame_texture_mode.gd -- --apply
## Revert (Lossy -> VRAM, back to default project state):
##   Godot --headless --path . --script res://tools/minigame_texture_mode.gd -- --revert --apply
## Then run --import to rebuild affected textures. minigame_export.ps1 does
## this automatically around the minigame export and restores the default
## .import state afterwards (repo-wide .import snapshot), so the repo never
## stays in lossy-mode state.

const MODE_LOSSLESS := 0
const MODE_LOSSY := 1
const MODE_VRAM := 2
const LOSSY_QUALITY := 0.85

var apply_mode := false
var revert_mode := false
var changed := 0
var skipped := 0
var bytes_before := 0
var report_lines: Array[String] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	apply_mode = args.has("--apply")
	revert_mode = args.has("--revert")
	_scan_dir("res://assets")
	report_lines.push_front("=== minigame_texture_mode (%s, %s) ===" % [
		"APPLY" if apply_mode else "dry-run",
		"VRAM->Lossy" if not revert_mode else "Lossy->VRAM"])
	report_lines.append("")
	report_lines.append("files to change: %d, untouched: %d" % [changed, skipped])
	report_lines.append("current vram ctex total: %.2f MB" % [bytes_before / 1048576.0])
	print("\n".join(report_lines))
	quit(0)


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
	if text.is_empty() or not text.contains("compress/mode="):
		return  # not a texture import
	var current := _current_mode(text)
	var target := MODE_VRAM if revert_mode else MODE_LOSSY
	if current == target:
		skipped += 1
		return
	# only touch files that are currently in the "other" state we expect
	# (VRAM when converting to lossy, lossy when reverting to VRAM)
	var expected_current := MODE_LOSSY if revert_mode else MODE_VRAM
	if current != expected_current:
		skipped += 1
		return
	var source := _source_of(text)
	var etc2_path := _remap_ctex(text)
	bytes_before += _file_size(etc2_path)
	changed += 1
	report_lines.append("%-70s mode %d -> %d" % [source.trim_prefix("res://"), current, target])
	if apply_mode:
		var updated := text.replace(
			"compress/mode=%d" % current, "compress/mode=%d" % target)
		if not revert_mode:
			updated = updated.replace(
				"compress/lossy_quality=0.7", "compress/lossy_quality=%s" % LOSSY_QUALITY)
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


func _remap_ctex(text: String) -> String:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("path.etc2=\""):
			return l.trim_prefix("path.etc2=\"").trim_suffix("\"")
		if l.begins_with("path=\""):
			return l.trim_prefix("path=\"").trim_suffix("\"")
	return ""


func _current_mode(text: String) -> int:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("compress/mode="):
			return l.trim_prefix("compress/mode=").to_int()
	return -1


func _file_size(res_path: String) -> int:
	if res_path.is_empty() or not FileAccess.file_exists(res_path):
		return 0
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size
