#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;

uniform mat4 projection;
uniform vec3 offset;

out vec2 uv;

void main() {
    uv = uv_in;

    float scale = 5.0;
    gl_Position = projection * vec4(aPos.xyz * scale + offset, 1.0);
}

