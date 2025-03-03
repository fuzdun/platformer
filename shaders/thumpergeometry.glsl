#version 450 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

in VS_OUT {
    vec2 uv;
    float time;
    vec3 player_pos;
    vec3 global_pos;
    vec3[3] player_trail;
    vec3 crunch_pt_out;
    float crunch_time_frag;
    vec3 normal_frag;
    int v_index;
    // vec4 gl_Position;
    vec3 obj_pos;
    // mat4 v_projection;
} gs_in[];

out vec3 player_pos;
out vec3[3] player_trail;
out vec3 global_pos;
out float time;
out float crunch_time_frag;
out vec2 uv;
out vec3 crunch_pt_out;   
out vec3 normal_frag;

uniform mat4 projection;

void main() {
    for(int i=0; i < 3; i++) {
        // vec4 new_pos = gl_in[i].gl_Position;
        // vec3 obj_pos = obj_poss_data[gs_in[i].v_index];
        // if (i == 2) {
        // new_pos.y -= (obj_pos.z - new_pos.z) * 1;
        // }
        // vec3 off = gs_in[i].obj_pos - new_pos.xyz;
        // vec4 off = vec4(0.0, 0.0, 0.0, 0.0);
        // new_pos += vec4(off, 0.0) * .01;
        // vec4 off = vec4(gs_in[i].normal_frag * 1, 0.0);
        // gl_Position = gs_in[i].v_projection * new_pos;
        vec4 new_pos = gl_in[i].gl_Position;   
        // new_pos.y += (gs_in[i].obj_pos.z + gs_in[i].global_pos.z);
        // new_pos.y -= gs_in[i].global_pos.z;
        // new_pos.y -= gs_in[i].obj_pos.z * .1;
        gl_Position = projection * new_pos;
        player_pos = gs_in[i].player_pos;
        player_trail = gs_in[i].player_trail;
        global_pos = gs_in[i].global_pos;
        time = gs_in[i].time;
        crunch_time_frag = gs_in[i].crunch_time_frag;
        uv = gs_in[i].uv;
        crunch_pt_out = gs_in[i].crunch_pt_out;
        normal_frag = gs_in[i].normal_frag;
        EmitVertex();
    }
    EndPrimitive();
}

