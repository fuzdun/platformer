#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;
layout (location = 2) in vec4 offset;

uniform mat4 projection;
uniform vec3 player_pos;

out vec2 uv;

void main() {
    uv = uv_in;
    gl_Position = projection * (aPos + offset + vec4(player_pos, 0.0) * 2.0);
}

