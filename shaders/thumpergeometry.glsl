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
    mat4 projection;
} te_out[];

out vec3 global_pos;
out vec2 uv;
out vec3 normal_frag;
out vec3 player_pos;

#define MAX_INTERVAL 300.0 

float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

void main() {
    float seed_val_1 = random(te_out[0].uv + te_out[1].uv + te_out[2].uv) * 0.5 + .25;
    float seed_val_2 = fract(seed_val_1 * 43758.5453123);
    float interval = MAX_INTERVAL * seed_val_1;
    float offset = (MAX_INTERVAL - interval) * seed_val_2;
    float offset_dist = te_out[0].player_dist - offset;
    // float offset_dist = te_out[0].player_dist;
    if (offset_dist > interval) {
        EndPrimitive();
        return;  
    }
    float dist_fact = max(0, min(1, offset_dist / interval));
    vec4 avg_pos = (gl_in[0].gl_Position + gl_in[1].gl_Position + gl_in[2].gl_Position) / 3.0;
    vec4 disp = (avg_pos - te_out[0].obj_pos) * dist_fact * dist_fact * dist_fact * 15;
    // vec4 disp = vec4(0);
    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        vec4 new_avg = avg_pos + disp;
        new_pos += disp;   
        new_pos += normalize(new_avg - new_pos) * dist_fact;
        gl_Position = te_out[0].projection * new_pos;


        global_pos = new_pos.xyz;
        player_pos = te_out[i].player_pos;
        uv = te_out[i].uv;
        normal_frag = te_out[i].normal_frag;
        EmitVertex();
    }
    EndPrimitive();
}

