#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 2) in vec3 color_in;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	float _pad0;
	vec3 cam_pos;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir;
    float inner_tess;
    float outer_tess;
	vec4 _pad1;
};

out vec3 color;

void main() {
    color = color_in;
    gl_Position = projection * aPos;
}

