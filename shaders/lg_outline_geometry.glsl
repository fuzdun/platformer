#version 460 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	float _pad0;
	vec3 cam_pos;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir;
    float inner_tess;
    float outer_tess;
	vec4 _pad1;
};

in TE_OUT {
    vec2 uv;
    vec4 obj_pos;
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

#define MIN_INTERVAL 50.0
#define MAX_INTERVAL 100.0 
#define ASSEMBLE_WINDOW 200.0
#define PI 3.1415926538

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

    obj_pos = te_out[0].obj_pos.xyz;

    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        vec2 xz_diff = new_pos.xz - player_pos.xz;
        float xz_dist = length(xz_diff);
        vec2 norm_obj_dir = normalize(new_pos.xz - player_pos.xz);
        float dist_flatten_fact = smoothstep(00, 400 - (150 * intensity), xz_dist);
        vec4 horizon_pt = new_pos;
        horizon_pt.y -= (cos(dist_flatten_fact * PI) - 1) * 500.0 * intensity;
        horizon_pt.xz += norm_obj_dir * sin(dist_flatten_fact * PI) * 800.0 * intensity;
        new_pos = mix(new_pos, horizon_pt, dist_flatten_fact * dist_flatten_fact);
        gl_Position = projection * new_pos;
        uv = te_out[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

