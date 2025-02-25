#version 450 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;
layout (std430, binding = 0) buffer z_dist {
    float z_dist_data[];
}; 

out vec2 uv;
out float time;
out vec3 player_pos;
out vec3 global_pos;
out vec3[3] player_trail;
out vec3 crunch_pt_out;
out float crunch_time_frag;
out vec3 normal_frag;

uniform float i_time;
uniform mat4 projection;
uniform vec3 player_pos_in;
uniform vec3[3] player_trail_in;
uniform vec3 crunch_pt;
uniform float crunch_time;

void main() {
    float dist = max(0, player_pos_in.z - (z_dist_data[gl_VertexID] + 60) - aPos.z);
    float dist_fact = dist * dist * 0.05;
    vec4 new_pos = aPos;
    vec4 projected = projection * new_pos;
    vec3 ndc = projected.xyz / projected.w;
    new_pos.xy += ndc.xy * dist_fact;
    gl_Position = projection * new_pos;
    // gl_Position = projection * aPos;

    crunch_pt_out = crunch_pt;
    crunch_time_frag = crunch_time;
    uv = vertexUV;
    time = i_time;
    player_pos = player_pos_in;
    player_trail = player_trail_in;
    global_pos = vec3(aPos);
    normal_frag = normal_in;
}

