extends SceneTree
func _initialize() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        print("MAIN LOAD FAILED")
        quit(1)
        return
    var root: Node = scene.instantiate()
    if root == null:
        print("MAIN INSTANTIATE FAILED")
        quit(1)
        return
    print("main instantiated: ", root.name, " children=", root.get_child_count())
    root.free()
    print("DONE")
    quit(0)
