shader_type spatial;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
varying vec3 world_normal;
void vertex(){ world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
    float sun=dot(normalize(world_normal),normalize(vec3(-.45,.82,.32)));
    float band=sun>.55?1.0:(sun>-.12?.94:.81);
    vec3 paint=use_vertex_color?COLOR.rgb:base_color.rgb;
    vec3 shade=mix(vec3(.96,.91,1.0),vec3(1.0),band);
    ALBEDO=paint*band*shade;
}
