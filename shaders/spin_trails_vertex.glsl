#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec3 normal_in;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

uniform mat4 transform;
// uniform mat4 inverse_view;
uniform vec3 camera_pos;
// uniform mat4 spin_rotation;

out vec3 sdf_ray;
out vec3 local_pos;
out float global_ray_z;

void main() {
    // local_pos = (spin_rotation * vec4(aPos.xyz, 1.0)).xyz;
    local_pos = aPos.xyz;
    vec4 transformed_pos = transform * aPos;
    vec4 global_ray = transformed_pos - vec4(camera_pos, 1.0);
    sdf_ray = normalize((inverse(transform) * global_ray).xyz);
    // sdf_ray = normalize((transpose(spin_rotation) * unrotated_sdf_ray).xyz);
    // vec3 rot_normal = normalize(mat3(transpose(inverse(transform))) * normal_in).xyz;
    gl_Position = projection * transformed_pos;
}

