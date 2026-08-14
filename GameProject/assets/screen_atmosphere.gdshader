shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 edge_color : source_color = vec4(0.025, 0.07, 0.055, 0.68);
uniform vec4 haze_color : source_color = vec4(0.22, 0.16, 0.055, 0.14);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.58;
uniform float haze_strength : hint_range(0.0, 0.2) = 0.045;

void fragment() {
  vec2 centered = (UV - vec2(0.5)) * vec2(1.0, 1.32);
  float distance_from_center = length(centered);
  float vignette = smoothstep(0.34, 0.76, distance_from_center) * vignette_strength;
  float upper_falloff = smoothstep(0.72, 0.0, UV.y) * 0.1;
  float haze_wave = sin(UV.x * 8.0 + UV.y * 3.0 + TIME * 0.12) * 0.5 + 0.5;
  float haze = haze_wave * haze_strength * smoothstep(0.15, 0.9, UV.y);
  vec3 color = mix(edge_color.rgb, haze_color.rgb, haze / max(haze_strength, 0.001));
  float alpha = clamp(vignette * edge_color.a + upper_falloff + haze * haze_color.a, 0.0, 0.58);
  COLOR = vec4(color, alpha);
}
