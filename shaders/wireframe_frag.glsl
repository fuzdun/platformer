#version 460 core

uniform vec3 color;

in float camera_dist;

out vec4 fragColor;

#define OPACITY_DIST 100.0

void main() {
    // vec3 t_color = color;
    // float fade_in_len = 100;
    // float fade_out_len = 300;
    // float trail_time_off = 50;
    // float time_off = t * trail_time_off;
    // float cur_time = i_time_frag - dash_time_frag - time_off;
    // float fade_in_t = clamp(cur_time / fade_in_len, 0, 1);
    // float fade_out_t = clamp((cur_time - fade_in_len) / fade_out_len, 0, 1);
    // float a = fade_in_t - fade_out_t;
    // t_color.b = t;
    fragColor = vec4(color, clamp(camera_dist / OPACITY_DIST, 0.0, 1.0));
    // if (camera_dist == 0.0) {
    //   fragColor = vec4(1.0);
    // }
  // }
    // fragColor = vec4(color, 1.0);
}

