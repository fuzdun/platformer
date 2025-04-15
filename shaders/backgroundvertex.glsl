#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;

uniform mat4 projection;
uniform vec3 offset;

out vec2 uv;

void main() {
    gl_Position = aPos;
    uv = uv_in;
}

