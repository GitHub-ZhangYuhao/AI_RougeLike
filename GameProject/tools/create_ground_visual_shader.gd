extends SceneTree

const FRAGMENT: int = VisualShader.TYPE_FRAGMENT


func _initialize() -> void:
	var shader := VisualShader.new()
	shader.mode = Shader.MODE_CANVAS_ITEM

	var uv := VisualShaderNodeInput.new()
	uv.input_name = "uv"
	shader.add_node(FRAGMENT, uv, Vector2(-1160, 80), 30)

	var terrain_scale := _float_parameter("terrain_scale", 1.0)
	var macro_scale := _float_parameter("macro_scale", 5.0)
	var dirt_amount := _float_parameter("dirt_amount", 0.52)
	var stone_amount := _float_parameter("stone_amount", 0.28)
	shader.add_node(FRAGMENT, terrain_scale, Vector2(-1160, 220), 2)
	shader.add_node(FRAGMENT, macro_scale, Vector2(-1160, 330), 3)
	shader.add_node(FRAGMENT, dirt_amount, Vector2(-1160, 440), 4)
	shader.add_node(FRAGMENT, stone_amount, Vector2(-1160, 550), 5)

	var masks := VisualShaderNodeExpression.new()
	masks.add_input_port(0, VisualShaderNode.PORT_TYPE_VECTOR_2D, "uv")
	masks.add_input_port(1, VisualShaderNode.PORT_TYPE_SCALAR, "terrain_scale")
	masks.add_input_port(2, VisualShaderNode.PORT_TYPE_SCALAR, "macro_scale")
	masks.add_input_port(3, VisualShaderNode.PORT_TYPE_SCALAR, "dirt_amount")
	masks.add_input_port(4, VisualShaderNode.PORT_TYPE_SCALAR, "stone_amount")
	masks.add_output_port(0, VisualShaderNode.PORT_TYPE_VECTOR_2D, "sample_uv")
	masks.add_output_port(1, VisualShaderNode.PORT_TYPE_SCALAR, "detail_mask")
	masks.add_output_port(2, VisualShaderNode.PORT_TYPE_SCALAR, "dirt_mask")
	masks.add_output_port(3, VisualShaderNode.PORT_TYPE_SCALAR, "stone_mask")
	masks.expression = "sample_uv = uv * terrain_scale;\nfloat wave_a = sin((uv.x * macro_scale + uv.y * 1.7) * 6.283185);\nfloat wave_b = cos((uv.y * macro_scale * 0.73 - uv.x * 1.3) * 6.283185);\nfloat macro = wave_a * 0.5 + wave_b * 0.5;\ndetail_mask = smoothstep(-0.45, 0.45, wave_a);\ndirt_mask = smoothstep(0.15 - dirt_amount, 0.85 - dirt_amount, macro);\nstone_mask = smoothstep(0.72 - stone_amount, 1.02 - stone_amount, wave_a * wave_b);"
	shader.add_node(FRAGMENT, masks, Vector2(-850, 230), 6)
	shader.connect_nodes(FRAGMENT, 30, 0, 6, 0)
	shader.connect_nodes(FRAGMENT, 2, 0, 6, 1)
	shader.connect_nodes(FRAGMENT, 3, 0, 6, 2)
	shader.connect_nodes(FRAGMENT, 4, 0, 6, 3)
	shader.connect_nodes(FRAGMENT, 5, 0, 6, 4)

	var texture_paths: Array[String] = [
		"res://assets/ground_grass_soft_celadon.png",
		"res://assets/ground_grass_dirt_soft_mix.png",
		"res://assets/ground_dirt_soft_umber.png",
		"res://assets/ground_dirt_sparse_pebbles.png",
		"res://assets/ground_flagstone_cartoon_soft.png",
		"res://assets/ground_stone_moss_soft.png",
	]
	for index: int in texture_paths.size():
		var texture_node := VisualShaderNodeTexture.new()
		texture_node.texture = load(texture_paths[index])
		texture_node.texture_type = VisualShaderNodeTexture.TYPE_COLOR
		var id: int = 10 + index
		shader.add_node(FRAGMENT, texture_node, Vector2(-520, -40 + index * 150), id)
		shader.connect_nodes(FRAGMENT, 6, 0, id, 0)

	var grass_mix := _color_mix()
	var dirt_mix := _color_mix()
	var stone_mix := _color_mix()
	var base_mix := _color_mix()
	var final_mix := _color_mix()
	shader.add_node(FRAGMENT, grass_mix, Vector2(-180, 20), 20)
	shader.add_node(FRAGMENT, dirt_mix, Vector2(-180, 270), 21)
	shader.add_node(FRAGMENT, stone_mix, Vector2(-180, 520), 22)
	shader.add_node(FRAGMENT, base_mix, Vector2(140, 190), 23)
	shader.add_node(FRAGMENT, final_mix, Vector2(430, 280), 24)
	shader.connect_nodes(FRAGMENT, 10, 0, 20, 0)
	shader.connect_nodes(FRAGMENT, 11, 0, 20, 1)
	shader.connect_nodes(FRAGMENT, 6, 1, 20, 2)
	shader.connect_nodes(FRAGMENT, 12, 0, 21, 0)
	shader.connect_nodes(FRAGMENT, 13, 0, 21, 1)
	shader.connect_nodes(FRAGMENT, 6, 1, 21, 2)
	shader.connect_nodes(FRAGMENT, 14, 0, 22, 0)
	shader.connect_nodes(FRAGMENT, 15, 0, 22, 1)
	shader.connect_nodes(FRAGMENT, 6, 1, 22, 2)
	shader.connect_nodes(FRAGMENT, 20, 0, 23, 0)
	shader.connect_nodes(FRAGMENT, 21, 0, 23, 1)
	shader.connect_nodes(FRAGMENT, 6, 2, 23, 2)
	shader.connect_nodes(FRAGMENT, 23, 0, 24, 0)
	shader.connect_nodes(FRAGMENT, 22, 0, 24, 1)
	shader.connect_nodes(FRAGMENT, 6, 3, 24, 2)

	var tint := VisualShaderNodeColorParameter.new()
	tint.parameter_name = "terrain_tint"
	tint.default_value_enabled = true
	tint.default_value = Color("d8e2c4")
	shader.add_node(FRAGMENT, tint, Vector2(150, 520), 25)
	var tint_strength := _float_parameter("tint_strength", 0.08)
	shader.add_node(FRAGMENT, tint_strength, Vector2(430, 560), 26)
	var tint_mix := _color_mix()
	shader.add_node(FRAGMENT, tint_mix, Vector2(700, 300), 27)
	shader.connect_nodes(FRAGMENT, 24, 0, 27, 0)
	shader.connect_nodes(FRAGMENT, 25, 0, 27, 1)
	shader.connect_nodes(FRAGMENT, 26, 0, 27, 2)
	shader.connect_nodes(FRAGMENT, 27, 0, 0, 0)

	var shader_error: Error = ResourceSaver.save(shader, "res://assets/ground_visual_shader.tres")
	if shader_error != OK:
		printerr("Failed to save VisualShader: %s" % error_string(shader_error))
		quit(1)
		return
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/ground_visual_shader.tres")
	material.set_shader_parameter("terrain_scale", 1.0)
	material.set_shader_parameter("macro_scale", 5.0)
	material.set_shader_parameter("dirt_amount", 0.52)
	material.set_shader_parameter("stone_amount", 0.28)
	material.set_shader_parameter("terrain_tint", Color("d8e2c4"))
	material.set_shader_parameter("tint_strength", 0.08)
	var material_error: Error = ResourceSaver.save(material, "res://assets/ground_visual_material.tres")
	if material_error != OK:
		printerr("Failed to save ShaderMaterial: %s" % error_string(material_error))
		quit(1)
		return
	print("Created editable ground VisualShader and ShaderMaterial.")
	quit(0)


func _float_parameter(name: String, value: float) -> VisualShaderNodeFloatParameter:
	var parameter := VisualShaderNodeFloatParameter.new()
	parameter.parameter_name = name
	parameter.default_value_enabled = true
	parameter.default_value = value
	return parameter


func _color_mix() -> VisualShaderNodeMix:
	var mix_node := VisualShaderNodeMix.new()
	mix_node.op_type = VisualShaderNodeMix.OP_TYPE_VECTOR_4D_SCALAR
	return mix_node
