shader_type spatial;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool asphalt = false;
uniform bool use_vertex_color = false;
uniform bool distant_haze = true;
uniform float shade_strength = 1.0;
uniform vec3 headlight_position = vec3(0.0);
uniform vec3 headlight_forward = vec3(0.0,0.0,-1.0);
uniform float headlight_strength = 0.0;
uniform float headlight_range = 35.0;
uniform float leaf_sway = 0.0;
uniform vec3 brush_position = vec3(0.0);
uniform float brush_strength = 0.0;
varying vec3 world_normal;
varying vec3 world_pos;
varying float camera_distance;
void vertex() {
	if (leaf_sway > 0.0 && brush_strength > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
		vec2 away = world.xz-brush_position.xz;
		float bend = (1.0-smoothstep(1.0,3.0,length(away))) * (1.0-smoothstep(2.8,4.0,world.y-brush_position.y)) * brush_strength;
		VERTEX.xz += away/max(length(away),0.1) * bend * 0.30;
	}
    VERTEX.x += sin(TIME*0.9+(MODEL_MATRIX*vec4(VERTEX,1.0)).z*0.22)*leaf_sway;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
void fragment() {
    float sun = dot(normalize(world_normal), normalize(vec3(-0.45, 0.82, 0.32)));
    float band = sun > 0.6 ? 1.0 : (sun > 0.0 ? 0.83 : 0.62);
    vec3 shadow = mix(vec3(0.69, 0.76, 0.89), vec3(1.0), band);
    vec3 color = (use_vertex_color ? COLOR.rgb : base_color.rgb) * mix(vec3(1.0), band * shadow, shade_strength);
    if (asphalt) {
        float grain = fract(sin(dot(floor(world_pos.xz * 5.0), vec2(12.9898, 78.233))) * 43758.5453);
        color += (grain - 0.5) * 0.006;
        float lane = mod(length(world_pos.xz) - 260.0 + 1.8, 3.6) - 1.8;
        float wear = 1.0 - smoothstep(0.12, 0.42, abs(abs(lane) - 0.65));
        color -= wear * 0.012;
    }
    float distance_to_eye = length(world_pos - CAMERA_POSITION_WORLD);
    if (headlight_strength > 0.0) {
    vec3 relative = world_pos-headlight_position;
    float along = dot(relative,headlight_forward);
    float side = length(relative-headlight_forward*along);
    float forward_distance = max(along, 0.0);
    float beam = (1.0-smoothstep(1.0+forward_distance*0.10,2.0+forward_distance*0.15,side));
    beam *= smoothstep(2.0,5.0,along)*(1.0-smoothstep(headlight_range*0.65,headlight_range,along));
    beam *= step(0.4,world_normal.y)*headlight_strength;
    color += vec3(0.23,0.20,0.10)*beam;
    }
    float haze = distant_haze ? smoothstep(210.0, 1000.0, distance_to_eye) * 0.62 : 0.0;
    ALBEDO = mix(color, vec3(0.53, 0.70, 0.78), haze);
}
