extends SceneTree
## Pack size audit: mount exported pck via --main-pack, walk res://,
## group sizes by extension and top-level dir. ASCII-only on purpose
## (console codepage mangles CJK in headless pipelines).
## Usage: Godot --headless --main-pack <pck> --script <abs path to this file>

var by_ext := {}
var by_dir := {}
var total := 0
var file_count := 0

func _init() -> void:
	var root := DirAccess.open("res://")
	if root == null:
		push_error("cannot open res:// (pck not mounted?)")
		quit(1)
		return
	_scan("res://")
	var lines: Array[String] = []
	lines.append("=== PCK SIZE REPORT ===")
	lines.append("total: %.2f MB, %d files" % [total / 1048576.0, file_count])
	lines.append("")
	lines.append("--- by extension ---")
	var exts := by_ext.keys()
	exts.sort_custom(func(a, b): return by_ext[a][0] > by_ext[b][0])
	for e in exts:
		var v: Array = by_ext[e]
		lines.append("%-12s %10.2f MB  %6d files" % [e, v[0] / 1048576.0, v[1]])
	lines.append("")
	lines.append("--- by top dir (>0.1MB) ---")
	var dirs := by_dir.keys()
	dirs.sort_custom(func(a, b): return by_dir[a] > by_dir[b])
	for d in dirs:
		if by_dir[d] < 104857.6:
			continue
		lines.append("%-50s %10.2f MB" % [d, by_dir[d] / 1048576.0])
	var text := "\n".join(lines)
	print(text)
	var out := FileAccess.open("user://pck_size_report.txt", FileAccess.WRITE)
	if out != null:
		out.store_string(text)
	quit(0)

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		var full := path.path_join(n)
		if dir.current_is_dir():
			_scan(full)
		else:
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null:
				var size := f.get_length()
				total += size
				file_count += 1
				var ext := full.get_extension().to_lower()
				if ext.is_empty():
					ext = "<none>"
				if not by_ext.has(ext):
					by_ext[ext] = [0, 0]
				by_ext[ext][0] += size
				by_ext[ext][1] += 1
				var rel := full.trim_prefix("res://")
				var top := rel.get_slice("/", 0) if rel.contains("/") else "<root>"
				by_dir[top] = by_dir.get(top, 0) + size
		n = dir.get_next()
	dir.list_dir_end()