#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 2) in vec3 color_in;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	vec2 _padding0;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir_in;
    float inner_tess;
    float outer_tess;
};

out vec3 color;
out vec3 pos;

void main() {
    color = color_in;
    pos = aPos.xyz;
    gl_Position = projection * aPos;
}

