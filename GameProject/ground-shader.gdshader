shader_type canvas_item;

// 地形混合材质骨架：4 个图层贴图（layer_1 ~ layer_4），由 editable-ground.gd 接入材质。
// 底图是瓦片自身贴图，内置变量可用 TEXTURE / UV / COLOR / TIME 等。
// 保存本文件后编辑器会热重载；混合逻辑请你在 fragment() 里自由编写。

uniform sampler2D layer_1 : source_color, filter_linear_mipmap;
uniform sampler2D layer_2 : source_color, filter_linear_mipmap;
uniform sampler2D layer_3 : source_color, filter_linear_mipmap;
uniform sampler2D layer_4 : source_color, filter_linear_mipmap;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// 四个图层已接入材质，自行采样并决定混合方式：
	// vec4 c1 = texture(layer_1, UV);
	// vec4 c2 = texture(layer_2, UV);
	// vec4 c3 = texture(layer_3, UV);
	// vec4 c4 = texture(layer_4, UV);
	COLOR = base;
	//COLOR = vec4(1.0, 0.0, 0.0, 1.0); // 测试行：取消注释可让地面全红
}