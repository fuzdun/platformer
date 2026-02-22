#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec3 normal_in;

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

uniform mat4 transform;

out vec3 sdf_ray;
out vec3 local_pos;
out float global_ray_z;

void main() {
    local_pos = aPos.xyz;
    vec4 transformed_pos = transform * aPos;
    vec4 global_ray = transformed_pos - vec4(cam_pos, 1.0);
    sdf_ray = normalize((inverse(transform) * global_ray).xyz);
    gl_Position = projection * transformed_pos;
}

