#version 460 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

in TE_OUT {
    vec2 uv;
    vec3 obj_pos;
    flat int cracked;
    flat int broken;
    float player_dist;

    vec2 t0_uv;
    vec2 t1_uv;
    vec2 t2_uv;
} te_out[];

out vec2 uv;
out vec3 obj_pos;
out float dist_fact;

#define MIN_INTERVAL 100.0
#define MAX_INTERVAL 400.0 
#define ASSEMBLE_WINDOW 400.0

float random2 (vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233)))* 43758.5453123);
}

void main() {
    float seed_val_1 = random2(te_out[0].uv + te_out[1].uv + te_out[2].uv) * 0.5 + .5;
    float seed_val_2 = fract(seed_val_1 * 43758.5453123);
    float interval = MIN_INTERVAL + (MAX_INTERVAL - MIN_INTERVAL) * seed_val_2;
    float offset = (ASSEMBLE_WINDOW - interval) * seed_val_2;
    float offset_dist = te_out[0].player_dist - offset;
    dist_fact = max(0, min(1, offset_dist / interval));
    if (te_out[0].cracked == 1 || te_out[0].broken == 1 || offset_dist > interval) {
        EndPrimitive();
        return;  
    }

    obj_pos = te_out[0].obj_pos;
    // cracked = te_out[0].cracked;
    for(int i=0; i < 3; i++) {
        gl_Position = projection * gl_in[i].gl_Position;
        uv = te_out[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

