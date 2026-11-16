shader_type spatial;
render_mode unshaded, cull_front;
uniform float width_pixels = 1.6;
void vertex() {
    vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec4 clip = PROJECTION_MATRIX * view;
    vec3 n = MODELVIEW_NORMAL_MATRIX * NORMAL;
    vec2 projected = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
    vec2 direction = projected / max(length(projected), 0.001);
    float fade = mix(1.0, 0.4, smoothstep(80.0, 450.0, -view.z));
    clip.xy += direction * width_pixels * fade * 2.0 / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
}
void fragment() { ALBEDO = vec3(0.035, 0.040, 0.062); }
