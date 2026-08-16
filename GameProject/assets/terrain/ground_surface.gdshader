shader_type canvas_item;
render_mode unshaded, blend_mix;

// New ground renderer: one 1024 px seamless texture repeated exactly 4 脳 4.
uniform sampler2D ground_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile_count : hint_range(1.0, 8.0, 1.0) = 4.0;
uniform float secondary_detail : hint_range(0.0, 0.2, 0.005) = 0.02;
uniform float macro_variation : hint_range(0.0, 0.2, 0.005) = 0.025;
uniform vec4 night_grade : source_color = vec4(0.82, 0.90, 1.0, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float brightness : hint_range(0.5, 1.5, 0.01) = 1.03;
uniform float contrast : hint_range(0.5, 1.5, 0.01) = 1.02;

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

void fragment() {
  // Polygon UV spans 0..4, so this sample produces an exact 4 脳 4 layout.
  vec2 tiled_uv = UV;
  vec3 color = texture(ground_albedo, fract(tiled_uv)).rgb;

  // A faint higher-frequency sample softens obvious repeated landmarks while
  // preserving seamless sampling at every tile boundary.
  vec3 detail = texture(ground_albedo, fract(tiled_uv * 2.0 + vec2(0.371, 0.613))).rgb;
  color = mix(color, detail, secondary_detail);

  // Large, continuous modulation is evaluated across the whole 4096 world,
  // not per tile, so the repeated texture does not read as sixteen squares.
  vec2 map_uv = tiled_uv / max(tile_count, 1.0);
  float macro = value_noise(map_uv * 7.0);
  macro = mix(macro, value_noise(map_uv * 13.0 + vec2(5.7, 2.9)), 0.35);
  color *= 1.0 + (macro - 0.5) * macro_variation;

  color *= brightness;
  color = clamp(vec3(0.5) + (color - vec3(0.5)) * contrast, vec3(0.0), vec3(1.0));
  color = mix(color, color * night_grade.rgb, grade_strength);
  COLOR = vec4(color, 1.0);
}

