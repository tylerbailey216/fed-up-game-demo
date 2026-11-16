shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D skyline : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment() {
    vec4 art = texture(skyline, UV);
    ALBEDO = mix(art.rgb, vec3(0.53, 0.69, 0.78), 0.13);
    ALPHA = art.a;
    ALPHA_SCISSOR_THRESHOLD = 0.6;
}
