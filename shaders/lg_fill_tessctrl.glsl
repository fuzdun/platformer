#version 460 core 

layout (vertices=3) out;

in VS_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    vec4 proj_pos;
    float player_dist;
    float plane_dist;
    vec3 pos;
    float crack_time;
    float outer_tess_amt;
    float inner_tess_amt;
} vs_out[];

patch out vec4 t0_proj_pos;
patch out vec4 t1_proj_pos;
patch out vec4 t2_proj_pos;
patch out vec2 t0_proj_pos_ndc;
patch out float t0zd;
patch out float t1zd;
patch out float t2zd;
patch out vec2 v0;
patch out vec2 v1;
patch out float d00;
patch out float d01;
patch out float d11;
patch out float denom;

out TC_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    float plane_dist;
    vec3 pos;
    float crack_time;

    vec3 t0_pos;
    vec3 t1_pos;
    vec3 t2_pos;

    vec2 t0_uv;
    vec2 t1_uv;
    vec2 t2_uv;
} tc_out[];

void main() {
    tc_out[gl_InvocationID].uv = vs_out[gl_InvocationID].uv;
    tc_out[gl_InvocationID].normal_frag = vs_out[gl_InvocationID].normal_frag;
    tc_out[gl_InvocationID].obj_pos = vs_out[gl_InvocationID].obj_pos;
    tc_out[gl_InvocationID].player_dist = vs_out[gl_InvocationID].player_dist;
    tc_out[gl_InvocationID].plane_dist = vs_out[gl_InvocationID].plane_dist;
    tc_out[gl_InvocationID].pos = vs_out[gl_InvocationID].pos;
    tc_out[gl_InvocationID].crack_time = vs_out[gl_InvocationID].crack_time;
  
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;


    t0_proj_pos = vs_out[0].proj_pos;
    t1_proj_pos = vs_out[1].proj_pos;
    t2_proj_pos = vs_out[2].proj_pos;
    t0_proj_pos_ndc = t0_proj_pos.xy / t0_proj_pos.w;
    t0zd = 1.0 / t0_proj_pos.w;
    t1zd = 1.0 / t1_proj_pos.w;
    t2zd = 1.0 / t2_proj_pos.w;
    v0 = t1_proj_pos.xy / t1_proj_pos.w - t0_proj_pos_ndc;
    v1 = t2_proj_pos.xy / t2_proj_pos.w - t0_proj_pos_ndc;
    d00 = dot(v0, v0);
    d01 = dot(v0, v1);
    d11 = dot(v1, v1);
    denom = d00 * d11 - d01 * d01;

    if (gl_InvocationID == 0) {
        gl_TessLevelOuter[0] = vs_out[0].outer_tess_amt;
        gl_TessLevelOuter[1] = vs_out[0].outer_tess_amt;
        gl_TessLevelOuter[2] = vs_out[0].outer_tess_amt;
        gl_TessLevelInner[0] = vs_out[0].inner_tess_amt;
    }
}

