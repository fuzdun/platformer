#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std430, binding = 1) buffer z_width {
    float z_width_data[];
};

layout (std430, binding = 2) buffer crack_times {
    float crack_time_data[];
};

layout (std430, binding = 3) buffer Break_Data {
    float break_data[][7];
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

out VS_OUT {
    vec2 uv;
    vec3 obj_pos;
    flat int cracked;
    flat int broken;
    float player_dist;
    float tess_amt;
} vs_out;

out vec2 uv;
out vec3 obj_pos;
out float player_dist;
out flat int cracked;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    float crack_time = crack_time_data[gl_BaseInstance + gl_InstanceID];
    vs_out.cracked = (crack_time != 0 && i_time > crack_time) ? 1 : 0;
    float[7] break_data = break_data[gl_BaseInstance + gl_InstanceID]; 
    float break_time = break_data[0];
    vs_out.broken = (break_time != 0 && i_time > break_time) ? 1 : 0;
    vs_out.obj_pos = vec3(transform[3][0], transform[3][1], transform[3][2]);
    vec4 new_pos = transform * aPos;
    vs_out.player_dist = max(0, player_pos.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 40 - new_pos.z);;
    gl_Position = new_pos;
    vs_out.uv = vertexUV;
    vs_out.tess_amt = 12;
}

