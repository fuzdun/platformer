#version 460 core

layout (location = 0) in vec4 a_pos1;
layout (location = 1) in vec4 a_pos0;
layout (location = 2) in vec3 a_vel1;
layout (location = 3) in vec3 a_vel0;

out VS_OUT {
    vec3 vel;
} vs_out;

uniform float interp_t;

void main() {
    gl_Position = mix(a_pos0, a_pos1, interp_t);
    vs_out.vel = mix(a_vel0, a_vel1, interp_t);
}

