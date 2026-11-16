shader_type sky;
void sky() {
    float height = clamp(EYEDIR.y, 0.0, 1.0);
    COLOR = mix(vec3(0.70, 0.85, 0.89), vec3(0.065, 0.43, 0.78), pow(height, 0.45));
}
