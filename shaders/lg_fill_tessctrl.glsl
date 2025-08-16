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

patch out vec3 v0;
patch out vec3 v1;
patch out float d00;
patch out float d01;
patch out float d11;
patch out float denom;

patch out vec3 normal_frag;
patch out vec4 obj_pos;
patch out float player_dist;
patch out float plane_dist;
patch out float crack_time;

out TC_OUT {
    vec2 uv;
    vec3 pos;
} tc_out[];

void main() {
    normal_frag = vs_out[gl_InvocationID].normal_frag;
    obj_pos = vs_out[gl_InvocationID].obj_pos;
    player_dist = vs_out[gl_InvocationID].player_dist;
    plane_dist = vs_out[gl_InvocationID].plane_dist;
    crack_time = vs_out[gl_InvocationID].crack_time;
    tc_out[gl_InvocationID].uv = vs_out[gl_InvocationID].uv;

    v0 = (vs_out[1].proj_pos - vs_out[0].proj_pos).xyz;
    v1 = (vs_out[2].proj_pos - vs_out[0].proj_pos).xyz;
    d00 = dot(v0, v0);
    d01 = dot(v0, v1);
    d11 = dot(v1, v1);
    denom =  d00 * d11 - d01 * d01;
    tc_out[gl_InvocationID].pos = vs_out[gl_InvocationID].pos;
  
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;

    if (gl_InvocationID == 0) {
        gl_TessLevelOuter[0] = vs_out[0].outer_tess_amt;
        gl_TessLevelOuter[1] = vs_out[0].outer_tess_amt;
        gl_TessLevelOuter[2] = vs_out[0].outer_tess_amt;
        gl_TessLevelInner[0] = vs_out[0].inner_tess_amt;
    }
}

