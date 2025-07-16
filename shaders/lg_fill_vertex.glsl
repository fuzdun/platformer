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
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    vec3 player_pos;
    int v_id;
    int tess_amt;
    mat4 projection;
    float i_time;
    // float plane_dist;
    vec3 pos;
} vs_out;


void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    
    vec4 new_pos = transform * aPos;
    float dist = max(0, player_pos.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 30 - new_pos.z);
    new_pos.xy += (projection * new_pos).xy * dist * dist * .000006;
    // new_pos.xyz += (projection * new_pos).xyz * dist * dist * .000101;
    gl_Position = new_pos;
    vs_out.v_id = gl_VertexID;
    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 1.0);
    vs_out.uv = vertexUV;
    vec3 rot_normal = normalize(mat3(transpose(inverse(matrices_data[gl_BaseInstance + gl_InstanceID]))) * normal_in).xyz;
    vs_out.normal_frag = rot_normal;
    vs_out.player_pos = player_pos;
    vs_out.player_dist = dist;
    vs_out.tess_amt = dist > 0 ? 12 : 1;
    vs_out.projection = projection;
    vs_out.i_time = i_time / 1000;
    // vs_out.plane_dist = dot((transform * aPos).xyz, rot_normal);
    vs_out.pos = vec3(transform * aPos);
}

