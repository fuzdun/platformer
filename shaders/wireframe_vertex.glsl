#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

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

layout (std140, binding = 4) buffer Transforms
{
    mat4 transforms[1000]; 
};

out float camera_dist;

void main() {
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    vec4 transformed_pos = transform * aPos;
    camera_dist = max(0, cam_pos.z - 50.0 - transformed_pos.z);
    gl_Position = projection * transformed_pos;
}

