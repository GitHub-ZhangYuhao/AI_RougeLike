extends SceneTree
## Top-N largest files inside mounted pck. ASCII-only.

var files := []

func _init() -> void:
	_scan("res://")
	files.sort_custom(func(a, b): return a[1] > b[1])
	var n := mini(30, files.size())
	print("=== TOP %d FILES IN PCK ===" % n)
	var sum_top := 0
	for i in n:
		sum_top += files[i][1]
		print("%8.2f MB  %s" % [files[i][1] / 1048576.0, files[i][0]])
	print("top-%d subtotal: %.2f MB" % [n, sum_top / 1048576.0])
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
				files.append([full.trim_prefix("res://"), f.get_length()])
		n = dir.get_next()
	dir.list_dir_end()