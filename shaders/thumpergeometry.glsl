#version 460 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

in TE_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    vec3 player_pos;
    int v_id;
} te_out[];

out vec3 global_pos;
out vec2 uv;
out vec3 normal_frag;
out vec3 player_pos;

uniform mat4 projection;

void main() {
    vec4 avg_pos = (gl_in[0].gl_Position + gl_in[1].gl_Position + gl_in[2].gl_Position) / 3.0;
    int triangle_id = te_out[0].v_id + te_out[1].v_id + te_out[2].v_id;
    float interval = 200 * ((mod(triangle_id * 9999, 20) + 1) / 20);
    float dist_fact = min(1, te_out[0].player_dist / interval);
    vec4 disp = (avg_pos - te_out[0].obj_pos) * dist_fact * 50;
    if (te_out[0].player_dist > interval) {
        EndPrimitive();
        return;  
    }
    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        vec4 new_avg = avg_pos + disp * .05;
        new_pos += disp;   
        new_pos += (new_avg - new_pos) * dist_fact;
        gl_Position = projection * new_pos;


        global_pos = new_pos.xyz;
        player_pos = te_out[i].player_pos;
        uv = te_out[i].uv;
        normal_frag = te_out[i].normal_frag;
        EmitVertex();
    }
    EndPrimitive();
}

