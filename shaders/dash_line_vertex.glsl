#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in float t_in;

out float v_t;

void main() {
    gl_Position = aPos;
    v_t = t_in;
}

