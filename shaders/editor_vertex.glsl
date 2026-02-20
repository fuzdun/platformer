#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

uniform int selected_index;

out int selected;

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

layout (std140, binding = 4) buffer Transforms
{
    mat4 transforms[1000]; 
};

out vec2 uv;

void main() {
    selected = (selected_index == gl_BaseInstance + gl_InstanceID) ? 1 : 0;
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * aPos;
    uv = vertexUV;
}

