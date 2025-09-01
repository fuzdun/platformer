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
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    float plane_dist;
    float crack_time;
    float break_data[7];

    vec3 t0_pos;

    vec2 t0_uv;
    vec2 t1_uv;
    vec2 t2_uv;

    in vec3 v0;
    in vec3 v1;
    in float d00;
    in float d01;
    in float d11;
    in float denom;

    float transparency;
} te_out[];

uniform float shatter_delay;

out vec3 global_pos;
out vec2 perspective_uv;
out vec3 normal_frag;
out float plane_dist;
out float displacement;
out float transparency;

out vec3 t0_pos;
out vec2 t0_uv;
out vec2 t1_uv;
out vec2 t2_uv;

// out vec3 b0_pos;
// out vec3 b1_pos;
// out vec3 b2_pos;

out vec3 b_poss[3];

out vec3 v0;
out vec3 v1;
out float d00;
out float d01;
out float d11;
out float denom;

out float did_shatter;

#define MIN_INTERVAL 100.0
#define MAX_INTERVAL 400.0 
#define ASSEMBLE_WINDOW 400.0

#define SHATTER_INTERVAL 1300.0
#define SHATTER_WINDOW 1500.0
#define SHATTER_HORIZONTAL_DIST 70.0
#define SHATTER_VERTICAL_DIST 200.0
#define CRACK_WIDTH 0.02
#define CRACK_ROT_AMT 0.35

#define ASSEMBLE true
#define SHATTER true
#define SHRINK true

float easeInCubic(float x) {
    return x * x;
}

float easeOutCubic(float x) {
    return 1.0 - pow(1.0 - x, 3);
}

mat4 rotation3d(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;

  return mat4(
    oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
    oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
    oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
    0.0,                                0.0,                                0.0,                                1.0
  );
}

float random(float n){return fract(sin(n) * 43758.5453123);}

float random2 (vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233)))* 43758.5453123);
}

void main() {
    float[7] break_data = te_out[0].break_data;
    float break_time = break_data[0];
    vec3 break_pos = vec3(break_data[1], break_data[2], break_data[3]);
    vec3 break_dir = vec3(break_data[4], break_data[5], break_data[6]);
    bool broken = break_time != 0;
    float seed_val_1 = random2(te_out[0].uv + te_out[1].uv + te_out[2].uv) * 0.5 + .5;
    float seed_val_2 = fract(seed_val_1 * 43758.5453123);
    float seed_val_3 = fract(seed_val_2 * 43758.5453123);
    float interval = MIN_INTERVAL + (MAX_INTERVAL - MIN_INTERVAL) * seed_val_2;
    float offset = (ASSEMBLE_WINDOW - interval) * seed_val_2;
    float offset_dist = te_out[0].player_dist - offset;
    if (offset_dist > interval) {
        EndPrimitive();
        return;  
    }
    float dist_fact = max(0, min(1, offset_dist / interval));
    vec4 avg_pos = (gl_in[0].gl_Position + gl_in[1].gl_Position + gl_in[2].gl_Position) / 3.0;

    float break_pt_dist = length(avg_pos.xyz - break_pos) / 3.0;
    break_pt_dist *= break_pt_dist;
    float break_disp = clamp((i_time - break_time) / 1000.0, 0, 1);
    vec4 disp = broken ? vec4(break_dir * break_disp * seed_val_1 * 3000.0 / break_pt_dist, 0.0) : (avg_pos - te_out[0].obj_pos) * easeOutCubic(easeInCubic(dist_fact)) * 1.5;
    vec4 new_avg = avg_pos + disp;

    t0_pos = te_out[0].t0_pos;

    v0 = te_out[0].v0;
    v1 = te_out[0].v1;
    d00 = te_out[0].d00;
    d01 = te_out[0].d01;
    d11 = te_out[0].d11;
    denom = te_out[0].denom;
    transparency = te_out[0].transparency;

    t0_uv = te_out[0].t0_uv;
    t1_uv = te_out[0].t1_uv;
    t2_uv = te_out[0].t2_uv;

    // b0_pos = gl_in[0].gl_Position.xyz;
    // b1_pos = gl_in[1].gl_Position.xyz;
    // b2_pos = gl_in[2].gl_Position.xyz;

    plane_dist = te_out[0].plane_dist; 
    displacement = dist_fact;
    normal_frag = te_out[0].normal_frag;

    float dist = te_out[0].player_dist;
    float crack_time = te_out[0].crack_time;
    vec3 rot_vec = vec3(random(seed_val_1), random(seed_val_2), random(seed_val_3));
    mat4 rot_mat = rotation3d(rot_vec, (seed_val_2 - 0.5) * CRACK_ROT_AMT);
    float shatter_time = crack_time + shatter_delay;

    float shatter_offset = (SHATTER_WINDOW - SHATTER_INTERVAL) * seed_val_2;
    float t = max(0, min(1, (i_time - (shatter_time + shatter_offset)) / SHATTER_INTERVAL)); 
    vec2 horizontal_offset = vec2(
        (random(seed_val_2) - 0.5) * SHATTER_HORIZONTAL_DIST,
        (random(seed_val_3) - 0.5) * SHATTER_HORIZONTAL_DIST
    );

    bool cracked = crack_time != 0 && i_time > crack_time;
    bool shattered = crack_time != 0 && i_time > shatter_time;
    did_shatter = (broken || cracked || shattered) ? 1.0 : 0.0;
    float fall_t = easeInCubic(t);
    float shatter_t = easeOutCubic(t);

    vec4 new_poss[3];

    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        new_pos += disp;   
        vec4 local_pos = new_pos - new_avg;
        local_pos = cracked ? rot_mat * local_pos : local_pos;
        local_pos *= shattered ? 1.0 - shatter_t : 1.0;
        local_pos *= cracked ? 1.0 - (seed_val_2 * CRACK_WIDTH) : 1.0;
        local_pos *= broken ? 1.0 - break_disp : 1.0 - dist_fact;
        new_pos = new_avg + local_pos;
        new_pos.y -= shattered ? fall_t * SHATTER_VERTICAL_DIST : 0;
        new_pos += shattered ? (shatter_t * vec4(horizontal_offset.x, 0, horizontal_offset.y , 0)) : vec4(0);
        new_poss[i] = new_pos;
        b_poss[i] = new_pos.xyz;
    }
    for(int i=0; i < 3; i++) {
        global_pos = b_poss[i];
        gl_Position = projection * new_poss[i];
        perspective_uv = te_out[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

