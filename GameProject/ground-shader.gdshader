shader_type canvas_item;

// 地面着色器（由 editable-ground.gd 应用到每个地面瓦片）。
// 可用内置变量：TEXTURE / UV / COLOR / TIME / SCREEN_UV 等。
// 保存后编辑器会热重载，地面立即生效。

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
