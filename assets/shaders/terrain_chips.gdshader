shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;
uniform float spray_clock=0.0;
varying float piece_age;
void vertex() {
    float age=spray_clock-INSTANCE_CUSTOM.x;
    piece_age=age;
    vec3 velocity=INSTANCE_CUSTOM.yzw;
    float flight=min(max(age,0.0),max(0.0,2.0*velocity.y/9.81));
    vec3 center=MODEL_MATRIX[3].xyz;
    vec3 p=VERTEX-center;
    float turn=flight*8.0;
    p.xz=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*p.xz;
    float fade=1.0-smoothstep(0.55,0.85,age);
    vec3 offset=vec3(velocity.x,0.0,velocity.z)*(1.0-exp(-3.0*flight))/3.0;
    offset.y=max(-0.02,velocity.y*flight-4.905*flight*flight);
    VERTEX=center+p*fade+offset;
}
void fragment() {
    if(piece_age<0.0 || piece_age>0.85) discard;
    float width=mix(0.15,0.5,sin(UV.y*3.141593));
    float edge=abs(UV.x-0.5);
    if(edge>width) discard;
    vec3 shade=COLOR.rgb*mix(0.67,1.0,step(0.45,UV.y));
    ALBEDO=mix(shade,shade*0.36,step(width-0.075,edge));
}
