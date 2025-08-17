#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std430, binding = 1) buffer z_width {
    float z_width_data[];
};

layout (std430, binding = 2) buffer crack_time {
    float crack_time_data[];
};

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

layout (std140, binding = 3) uniform Tessellation
{
    float inner_amt;
    float outer_amt;
};

out VS_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    float plane_dist;
    float crack_time;
    float outer_tess_amt;
    float inner_tess_amt;
} vs_out;


void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    vec4 new_pos = transform * aPos;
    gl_Position = new_pos;
    vec3 rot_normal = normalize(mat3(transpose(inverse(matrices_data[gl_BaseInstance + gl_InstanceID]))) * normal_in).xyz;

    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 1.0);
    vs_out.uv = vertexUV;
    vs_out.normal_frag = rot_normal;
    vs_out.player_dist = max(0, player_pos.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 40 - new_pos.z);;
    vs_out.plane_dist = dot((transform * aPos).xyz, rot_normal);
    vs_out.crack_time = crack_time_data[gl_BaseInstance + gl_InstanceID];
    vs_out.outer_tess_amt = outer_amt;
    vs_out.inner_tess_amt = inner_amt;
}

