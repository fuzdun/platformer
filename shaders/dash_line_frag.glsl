#version 460 core

uniform vec3 color;

in float t;
in float dash_time_frag;
in float i_time_frag;

out vec4 fragColor;

void main() {
    float fade_in_len = 100;
    float fade_out_len = 300;
    float trail_time_off = 50;
    float time_off = t * trail_time_off;
    float cur_time = dash_time_frag - time_off;
    float fade_in_t = clamp(cur_time / fade_in_len, 0, 1);
    float fade_out_t = clamp((cur_time - fade_in_len) / fade_out_len, 0, 1);
    float a = fade_in_t - fade_out_t;
    fragColor = vec4(color, a);
}

