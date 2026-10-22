shader_type canvas_item;

// Hue rotation in turns (0.0–1.0); 0.55 ≈ 200° shifts orange → deep blue/cyan.
uniform float hue_shift : hint_range(0.0, 1.0) = 0.55;
// Multiply saturation (< 1 desaturates warm → moody cool).
uniform float sat_mult : hint_range(0.0, 2.0) = 0.85;
// Multiply value/brightness.
uniform float val_mult : hint_range(0.0, 2.0) = 0.80;
// Tint overlay colour blended on top (small amount adds cohesion).
uniform vec4 tint_color : source_color = vec4(0.04, 0.15, 0.35, 1.0);
// How much of the tint to blend in (0 = none, 1 = full tint).
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 hsv = rgb2hsv(tex.rgb);
    hsv.x = fract(hsv.x + hue_shift);
    hsv.y *= sat_mult;
    hsv.z *= val_mult;
    vec3 shifted = hsv2rgb(hsv);
    // Blend in the tint for colour cohesion
    shifted = mix(shifted, tint_color.rgb, tint_strength);
    COLOR = vec4(shifted, tex.a);
}
