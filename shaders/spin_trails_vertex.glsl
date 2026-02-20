#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec3 normal_in;

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
uniform vec3 camera_pos;

out vec3 sdf_ray;
out vec3 local_pos;
out float global_ray_z;

void main() {
    local_pos = aPos.xyz;
    vec4 transformed_pos = transform * aPos;
    vec4 global_ray = transformed_pos - vec4(camera_pos, 1.0);
    sdf_ray = normalize((inverse(transform) * global_ray).xyz);
    gl_Position = projection * transformed_pos;
}

