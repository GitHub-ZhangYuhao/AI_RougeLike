shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D grass_primary : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_path_mix : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_soft : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_moss : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

uniform float terrain_scale : hint_range(1.0, 8.0, 0.05) = 3.2;
uniform float macro_scale : hint_range(1.0, 16.0, 0.1) = 7.2;
uniform float dirt_amount : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float stone_amount : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float detail_contrast : hint_range(0.8, 1.5, 0.01) = 1.15;
uniform float saturation : hint_range(0.7, 1.3, 0.01) = 1.04;
uniform vec4 terrain_tint : source_color = vec4(0.90, 0.97, 0.88, 1.0);
uniform float tint_strength : hint_range(0.0, 0.5, 0.01) = 0.08;
uniform vec4 overall_tint : source_color = vec4(0.78, 0.84, 0.76, 1.0);

varying vec2 terrain_position;

void vertex() {
  terrain_position = VERTEX;
}

float hash21(vec2 point) {
  point = fract(point * vec2(123.34, 456.21));
  point += dot(point, point + 45.32);
  return fract(point.x * point.y);
}

float value_noise(vec2 point) {
  vec2 cell = floor(point);
  vec2 local = fract(point);
  local = local * local * (3.0 - 2.0 * local);
  float a = hash21(cell);
  float b = hash21(cell + vec2(1.0, 0.0));
  float c = hash21(cell + vec2(0.0, 1.0));
  float d = hash21(cell + vec2(1.0, 1.0));
  return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float terrain_noise(vec2 point) {
  float broad = value_noise(point);
  float medium = value_noise(point * 2.07 + vec2(8.3, 2.1));
  float fine = value_noise(point * 4.11 + vec2(1.7, 9.4));
  float micro = value_noise(point * 8.23 + vec2(5.3, 7.8));
  return broad * 0.48 + medium * 0.30 + fine * 0.15 + micro * 0.07;
}

vec3 boost_detail(vec3 color) {
  float luminance = dot(color, vec3(0.299, 0.587, 0.114));
  vec3 saturated = vec3(luminance) + (color - vec3(luminance)) * saturation;
  return clamp(vec3(0.5) + (saturated - vec3(0.5)) * detail_contrast, vec3(0.0), vec3(1.0));
}

void fragment() {
  vec2 normalized_position = terrain_position / 4096.0;
  vec2 base_uv = normalized_position * terrain_scale;
  mat2 turn_a = mat2(vec2(0.9848, 0.1736), vec2(-0.1736, 0.9848));
  mat2 turn_b = mat2(vec2(0.9397, -0.3420), vec2(0.3420, 0.9397));

  vec4 grass_a = texture(grass_primary, base_uv);
  vec4 grass_rotated = texture(grass_primary, turn_b * (base_uv * 1.08) + vec2(0.17, 0.73));
  vec4 grass_b = texture(grass_path_mix, turn_a * (base_uv * 0.92) + vec2(0.29, 0.47));
  vec4 dirt_layer = texture(dirt_soft, turn_b * (base_uv * 1.04) + vec2(0.61, 0.18));
  vec4 stone_layer = texture(stone_moss, turn_a * (base_uv * 0.97) + vec2(0.41, 0.84));

  float macro = terrain_noise(normalized_position * macro_scale + vec2(3.7, 1.9));
  float detail = terrain_noise(normalized_position * macro_scale * 2.8 + vec2(9.2, 4.6));
  float fine_detail = terrain_noise(normalized_position * macro_scale * 5.6 + vec2(2.1, 6.3));
  float stone_noise = terrain_noise(normalized_position * macro_scale * 1.42 + vec2(15.4, 7.1));

  vec4 ground = mix(grass_a, grass_rotated, 0.36);
  float grass_mix = smoothstep(0.41, 0.72, detail) * 0.12;
  ground = mix(ground, grass_b, grass_mix);

  float dirt_threshold = 0.75 - dirt_amount * 0.46;
  float dirt_mask = smoothstep(dirt_threshold, dirt_threshold + 0.18, macro + (detail - 0.5) * 0.14);
  ground = mix(ground, dirt_layer, dirt_mask * 0.34);

  float stone_threshold = 0.92 - stone_amount * 0.70;
  float stone_mask = smoothstep(stone_threshold, stone_threshold + 0.09, stone_noise) * (1.0 - dirt_mask * 0.45);
  ground = mix(ground, stone_layer, stone_mask * 0.38);

  vec3 color = boost_detail(ground.rgb);
  color = mix(color, color * terrain_tint.rgb, tint_strength);
  color = clamp(color + vec3((detail - 0.5) * 0.035 + (fine_detail - 0.5) * 0.018), vec3(0.0), vec3(1.0));
  COLOR = vec4(color * overall_tint.rgb, ground.a * overall_tint.a);
}
