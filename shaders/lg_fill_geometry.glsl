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
    // vec3 pos;
    float crack_time;

    vec3 t0_pos;
    vec3 t1_pos;
    vec3 t2_pos;
    vec2 t0_uv;
    vec2 t1_uv;
    vec2 t2_uv;
} te_out[];

uniform float shatter_delay;

out vec3 global_pos;
out vec2 perspective_uv;
out vec3 normal_frag;
out float plane_dist;
out float displacement;

out vec3 t0_pos;
out vec3 t1_pos;
out vec3 t2_pos;
out vec2 t0_uv;
out vec2 t1_uv;
out vec2 t2_uv;

#define MIN_INTERVAL 100.0
#define MAX_INTERVAL 400.0 
#define ASSEMBLE_WINDOW 400.0

// #define SHATTER_DELAY 2000.0
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

    // vec4 disp = ASSEMBLE ? (avg_pos - te_out[0].obj_pos) * easeOutCubic(easeInCubic(dist_fact)) * 2.5 : vec4(0);
    vec4 disp = ASSEMBLE ? (avg_pos - te_out[0].obj_pos) * easeOutCubic(easeInCubic(dist_fact)) * -0.5 : vec4(0);
    // disp.z *= 0.75;
    vec4 new_avg = avg_pos + disp;

    t0_pos = te_out[0].t0_pos;
    t1_pos = te_out[0].t1_pos;
    t2_pos = te_out[0].t2_pos;
    t0_uv = te_out[0].t0_uv;
    t1_uv = te_out[0].t1_uv;
    t2_uv = te_out[0].t2_uv;

    plane_dist = te_out[0].plane_dist; 
    displacement = dist_fact;
    normal_frag = te_out[0].normal_frag;
    vec3 rot_vec = vec3(random(seed_val_1), random(seed_val_2), random(seed_val_3));
    mat4 rot_mat = rotation3d(rot_vec, (seed_val_2 - 0.5) * CRACK_ROT_AMT);
    float dist = te_out[0].player_dist;

    float crack_time = te_out[0].crack_time;
    float shatter_time = crack_time + shatter_delay;

    float shatter_offset = (SHATTER_WINDOW - SHATTER_INTERVAL) * seed_val_2;
    float t = max(0, min(1, (i_time - (shatter_time + shatter_offset)) / SHATTER_INTERVAL)); 
    float fall_t = easeInCubic(t);
    float shatter_t = easeOutCubic(t);
    vec2 horizontal_offset = vec2(
        (random(seed_val_2) - 0.5) * SHATTER_HORIZONTAL_DIST,
        (random(seed_val_3) - 0.5) * SHATTER_HORIZONTAL_DIST
    );

    bool cracked = crack_time != 0 && i_time > crack_time;
    bool shattered = crack_time != 0 && i_time > shatter_time;

    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        // new_pos.xy += (projection * new_pos).xy * dist * dist * .000008;
        new_pos += disp;   
        vec4 local_pos = new_pos - new_avg;
        local_pos = cracked ? rot_mat * local_pos : local_pos;
        local_pos *= shattered ? 1.0 - shatter_t : 1.0;
        local_pos *= cracked ? 1.0 - (seed_val_2 * CRACK_WIDTH) : 1.0;
        local_pos *= 1.0 - dist_fact;
        new_pos = new_avg + local_pos;
        // new_pos += shrink_vec * crack_amt;
        // new_pos += SHRINK ? shrink_vec * (dist_fact - crack_amt) : vec4(0);
        if (shattered) {
            // float shatter_inverval = MAX_SHATTER_INTERVAL * seed_val_2;
            // new_pos += shrink_vec * shatter_t;
            new_pos.y -= fall_t * SHATTER_VERTICAL_DIST;
            vec4 offset_vec = vec4(horizontal_offset.x, 0, horizontal_offset.y , 0);
            new_pos += shatter_t * offset_vec;
        }


        vec4 proj_pos = projection * new_pos;
        // vec4 proj_pos = projection * gl_in[i].gl_Position;
        vec4 snapped_pos = proj_pos;
        // snapped_pos.xyz /= proj_pos.w;
        // bool in_ndc = snapped_pos.x >= -1 && snapped_pos.x <= 1 && snapped_pos.y >= -1 && snapped_pos.y <= 1;
        // snapped_pos.xy = floor(100 * snapped_pos.xy) / 100;
        // snapped_pos.xyz *= proj_pos.w;
        gl_Position = snapped_pos;
        global_pos = new_pos.xyz;
        perspective_uv = te_out[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

