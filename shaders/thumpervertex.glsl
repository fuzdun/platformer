#version 450 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;
layout (std430, binding = 0) buffer z_width {
    float z_width_data[];
};
layout (std430, binding = 1) buffer obj_poss {
    vec3 obj_poss_data[];
};

out VS_OUT {
    vec2 uv;
    float time;
    vec3 player_pos;
    vec3 global_pos;
    vec3[3] player_trail;
    vec3 crunch_pt_out;
    float crunch_time_frag;
    vec3 normal_frag;
    int v_index;
    vec4 gl_Position;
    // vec3 obj_pos;
    // mat4 v_projection;
} vs_out;

// out vec3 player_pos;
// out vec3[3] player_trail;
// out vec3 global_pos;
// out float time;
// out float crunch_time_frag;
// out vec2 uv;
// out vec3 crunch_pt_out;   
// out vec3 normal_frag;

uniform float i_time;
// uniform mat4 projection;
uniform vec3 player_pos_in;
uniform vec3[3] player_trail_in;
uniform vec3 crunch_pt;
uniform float crunch_time;

// uniform mat4 transform;

void main() {
    // float dist = max(0, player_pos_in.z - (z_width_data[gl_VertexID] + 30) - aPos.z);
    // float dist_fact = dist * dist * 0.05;
    // vec4 new_pos = aPos;
    // vec4 projected = projection * new_pos;
    // vec3 ndc = projected.xyz / projected.w;
    // projected.xy += ndc.xy * dist_fact;
    // gl_Position = projected;
    // gl_Position = projection * aPos;
    vec4 off = aPos - vec4(obj_poss_data[gl_VertexID], 0.0);
    gl_Position = aPos + off * 0.1;
    vs_out.gl_Position = gl_Position;

    vs_out.crunch_pt_out = crunch_pt;
    vs_out.crunch_time_frag = crunch_time;
    vs_out.uv = vertexUV;
    vs_out.time = i_time;
    vs_out.player_pos = player_pos_in;
    vs_out.player_trail = player_trail_in;
    vs_out.global_pos = vec3(aPos);
    vs_out.normal_frag = normal_in;
    vs_out.v_index = gl_VertexID;
    // vs_out.obj_pos = obj_poss_data[gl_VertexID];
    // vs_out.v_projection = projection;

    // crunch_pt_out = crunch_pt;
    // crunch_time_frag = crunch_time;
    // uv = vertexUV;
    // time = i_time;
    // player_pos = player_pos_in;
    // player_trail = player_trail_in;
    // global_pos = vec3(aPos);
    // normal_frag = normal_in;
}

