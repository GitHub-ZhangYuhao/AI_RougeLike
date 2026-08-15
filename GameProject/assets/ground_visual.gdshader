shader_type canvas_item;
render_mode unshaded, blend_mix;

// Single night ground texture (replaces the 4 separate terrain textures)
uniform sampler2D night_ground : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

// Tiling scale
uniform float terrain_scale : hint_range(1.0, 16.0, 0.05) = 4.0;

// Night atmosphere — moonlight blue tint
uniform vec4 moonlight_tint : source_color = vec4(0.65, 0.70, 0.95, 1.0);
uniform float moonlight_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

// Subtle purple/blue atmosphere overlay
uniform vec4 atmosphere_tint : source_color = vec4(0.55, 0.50, 0.80, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.5, 0.01) = 0.12;

// Contrast/saturation/brightness adjustments
uniform float contrast : hint_range(0.8, 1.5, 0.01) = 1.10;
uniform float saturation : hint_range(0.5, 1.5, 0.01) = 0.90;
uniform float brightness : hint_range(0.5, 1.5, 0.01) = 0.88;

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
  // Sample the single night ground texture with tiling
  vec2 uv = UV * terrain_scale;
  vec4 tex_color = texture(night_ground, uv);

  // Apply brightness
  vec3 color = tex_color.rgb * brightness;

  // Adjust contrast
  color = clamp(vec3(0.5) + (color - vec3(0.5)) * contrast, vec3(0.0), vec3(1.0));

  // Adjust saturation
  float lum = dot(color, vec3(0.299, 0.587, 0.114));
  color = vec3(lum) + (color - vec3(lum)) * saturation;

  // Apply moonlight tint (cool blue)
  color = mix(color, color * moonlight_tint.rgb, moonlight_strength);

  // Apply subtle purple atmosphere overlay
  color = mix(color, atmosphere_tint.rgb, atmosphere_strength);

  // Subtle noise variation to help break up visible tiling
  float noise_var = value_noise(UV * 4096.0 * 0.008) * 0.06 - 0.03;
  color = clamp(color + vec3(noise_var), vec3(0.0), vec3(1.0));

  COLOR = vec4(color, tex_color.a);
}
