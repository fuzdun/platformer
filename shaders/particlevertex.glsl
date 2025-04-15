#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec4 offset;

uniform mat4 projection;
uniform vec3 player_pos;

void main() {
    gl_Position = projection * (aPos + offset + vec4(player_pos, 0.0) * 2);
}

