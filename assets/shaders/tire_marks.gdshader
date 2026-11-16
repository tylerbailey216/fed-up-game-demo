shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float mark_clock = 0.0;
varying vec2 mark_data;
void vertex() {
    mark_data = INSTANCE_CUSTOM.xy;
}
void fragment() {
    float age = mark_clock - mark_data.x;
    float edge = 1.0 - smoothstep(0.32,0.5,abs(UV.x-0.5));
    float tread = 0.88 + 0.12 * step(0.22,fract(UV.x*5.0));
    ALBEDO = vec3(0.065,0.07,0.075);
    ALPHA = mark_data.y * edge * tread * (1.0-smoothstep(4.0,7.0,age)) * step(0.0,age);
}
