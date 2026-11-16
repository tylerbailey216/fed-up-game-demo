shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
    float radius = length((UV - 0.5) * 2.0);
    ALBEDO = vec3(0.04, 0.035, 0.065);
    ALPHA = (1.0 - smoothstep(0.55, 1.0, radius)) * 0.34;
}
