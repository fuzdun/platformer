#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;
layout (location = 2) in vec4 offset;

uniform mat4 projection;
uniform vec3 player_pos;

out vec2 uv;
flat out int id;

void main() {
    id = int(offset.a);
    vec4 adjusted_offset = vec4(offset.xyz, 1.0);
    uv = uv_in;
    gl_Position = projection * (aPos + adjusted_offset + vec4(player_pos, 0.0) * 2.0);
}

