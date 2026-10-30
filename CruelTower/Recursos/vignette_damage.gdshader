shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.72, 0.05, 0.05, 1.0);
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 1.4142; // 0 en el centro, 1 en las esquinas
	float vig = smoothstep(0.3, 1.0, dist) * vignette_intensity;
	float flash = flash_intensity * 0.3;
	float alpha = clamp(vig + flash, 0.0, 1.0);
	COLOR = vec4(vignette_color.rgb, alpha * vignette_color.a);
}
