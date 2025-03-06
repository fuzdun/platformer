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


out VS_OUT {
    vec2 uv;
    float time;
    vec3 player_pos;
    vec3[3] player_trail;
    vec3 crunch_pt_out;
    float crunch_time_frag;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    int v_id;
} vs_out;


uniform float i_time;
uniform vec3 player_pos_in;
uniform vec3[3] player_trail_in;
uniform vec3 crunch_pt;
uniform float crunch_time;

void main() {
    // vs_out.player_dist = max(0, player_pos_in.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - aPos.z);
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    vec4 new_pos = transform * aPos;
    float dist = max(0, player_pos_in.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 100 - new_pos.z);
    vs_out.player_dist = dist * dist * 0.001;
    gl_Position = new_pos;
    // vec4 new_pos = aPos;
    // vec4 projected = projection * new_pos;
    // vec3 ndc = projected.xyz / projected.w;
    // projected.xy += ndc.xy * dist_fact;
    // gl_Position = projected;
    // gl_Position = projection * aPos;
    // vec4 off = aPos - vec4(obj_poss_data[gl_VertexID], 0.0);

    vs_out.v_id = gl_VertexID;
    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 1.0);
    vs_out.uv = vertexUV;
    vs_out.time = i_time;
    vs_out.player_pos = player_pos_in;
    vs_out.player_trail = player_trail_in;
    vs_out.crunch_pt_out = crunch_pt;
    vs_out.crunch_time_frag = crunch_time;
    vs_out.normal_frag = normal_in;

}

