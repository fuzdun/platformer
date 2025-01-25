#version 450 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;

out vec2 uv;
out float time;
out vec3 player_pos;
out vec3 global_pos;

uniform float i_time;
uniform mat4 projection;
uniform vec3 player_pos_in;

void main() {
    gl_Position = projection * aPos;
    uv = vertexUV;
    time = i_time;
    player_pos = player_pos_in;
    global_pos = vec3(aPos);
}
