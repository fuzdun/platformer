#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;

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

uniform mat4 transform;

out vec2 uv;

void main() {
    uv = uv_in;
    // gl_Position = projection * transform * aPos;
    gl_Position = aPos;
}

