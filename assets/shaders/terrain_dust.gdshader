shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float spray_clock=0.0;
varying float puff_age;
void vertex() {
    float age=spray_clock-INSTANCE_CUSTOM.x;
    puff_age=age;
    // Collapse expired quads before rasterization. Fragment discard alone would
    // still shade large old billboards, especially the never-used pool slots.
    float alive=step(0.0,age)*(1.0-step(1.0,age));
    float t=clamp(age,0.0,1.0);
    vec3 velocity=INSTANCE_CUSTOM.yzw;
    vec3 offset=velocity*(1.0-exp(-2.2*t))/2.2;
    offset.y+=t*0.16;
    vec3 center=(VIEW_MATRIX*vec4(MODEL_MATRIX[3].xyz+offset,1.0)).xyz;
    vec2 size=vec2(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz));
    POSITION=PROJECTION_MATRIX*vec4(center+vec3(VERTEX.xy*size*(1.0+t*1.1)*alive,0.0),1.0);
}
void fragment() {
    if(puff_age<0.0 || puff_age>1.0) discard;
    vec2 p=UV-vec2(0.5);
    float lobes=0.035*sin(atan(p.y,p.x)*5.0);
    float shape=1.0-smoothstep(0.29,0.47,length(p)+lobes);
    ALBEDO=COLOR.rgb*mix(0.82,1.0,step(0.48,UV.y));
    ALPHA=shape*0.24*smoothstep(0.0,0.08,puff_age)*(1.0-smoothstep(0.25,1.0,puff_age));
}
