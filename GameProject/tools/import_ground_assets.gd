extends SceneTree

const SOURCE_DIR: String = "res://../ArtAsset/Image/Environment/GroundTextures/StyleAnchors/v07_soft_cartoon_ground_textures/final"
const TEXTURES: Array[String] = [
    "dirt_soft_umber.png",
    "dirt_sparse_pebbles.png",
    "flagstone_cartoon_soft.png",
    "grass_dirt_soft_mix.png",
    "grass_soft_celadon.png",
    "stone_moss_soft.png",
]


func _initialize() -> void:
    var source_dir: String = ProjectSettings.globalize_path(SOURCE_DIR)
    var destination_dir: String = ProjectSettings.globalize_path("res://assets")
    for file_name: String in TEXTURES:
        var error: Error = DirAccess.copy_absolute(
            source_dir.path_join(file_name),
            destination_dir.path_join("ground_%s" % file_name)
        )
        if error != OK:
            printerr("Failed to copy %s: %s" % [file_name, error_string(error)])
            quit(1)
            return
    print("Imported %d ground textures into res://assets." % TEXTURES.size())
    quit(0)
