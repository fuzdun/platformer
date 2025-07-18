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
    float i_time;
    // float plane_dist;
    vec3 t0_pos;
    vec3 t1_pos;
    vec3 t2_pos;
    vec2 t0_uv;
    vec2 t1_uv;
    vec2 t2_uv;
} te_out[];

out vec3 global_pos;
out vec2 perspective_uv;
out vec2 affine_uv;
out vec3 normal_frag;
out vec3 player_pos;
out int in_view;
out float i_time;
out float displacement;
// out float plane_dist;
out vec3 t0_pos;
out vec3 t1_pos;
out vec3 t2_pos;
out vec2 t0_uv;
out vec2 t1_uv;
out vec2 t2_uv;
// out vec3 t_normal;

#define MAX_INTERVAL 200.0 

float random (vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233)))* 43758.5453123);
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
    vec4 disp = (avg_pos - te_out[0].obj_pos) * dist_fact * dist_fact * dist_fact * 2;
    disp.z *= 0.75;
    // vec4 disp = vec4(0);
    t0_pos = te_out[0].t0_pos;
    t1_pos = te_out[0].t1_pos;
    t2_pos = te_out[0].t2_pos;
    t0_uv = te_out[0].t0_uv;
    t1_uv = te_out[0].t1_uv;
    t2_uv = te_out[0].t2_uv;
    // plane_dist = te_out[0].plane_dist;
    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        vec4 new_avg = avg_pos + disp;
        new_pos += disp;   
        new_pos += (new_avg - new_pos) * dist_fact;
        vec4 proj_pos = te_out[0].projection * new_pos;
        vec4 snapped_pos = proj_pos;
        // snapped_pos.xyz /= proj_pos.w;
        // bool in_ndc = snapped_pos.x >= -1 && snapped_pos.x <= 1 && snapped_pos.y >= -1 && snapped_pos.y <= 1;
        // in_view = in_ndc ? 1 : 0;
        // snapped_pos.xy = floor(100 * snapped_pos.xy) / 100;
        // snapped_pos.xyz *= proj_pos.w;
        gl_Position = snapped_pos;

        global_pos = new_pos.xyz;
        player_pos = te_out[i].player_pos;
        perspective_uv = te_out[i].uv;
        affine_uv = te_out[i].uv;
        normal_frag = te_out[i].normal_frag;
        i_time = te_out[i].i_time;
        displacement = dist_fact;

        EmitVertex();
    }
    EndPrimitive();
}

