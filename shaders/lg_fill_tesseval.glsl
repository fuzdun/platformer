#version 460 core

layout(triangles, equal_spacing, ccw) in;

in TC_OUT {
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

patch in vec4 t0_proj_pos;
patch in vec4 t1_proj_pos;
patch in vec4 t2_proj_pos;
patch in vec2 t0_proj_pos_ndc;
patch in float t0zd;
patch in float t1zd;
patch in float t2zd;
patch in vec2 v0;
patch in vec2 v1;
patch in float d00;
patch in float d01;
patch in float d11;
patch in float denom;


out TE_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    float plane_dist;
    float crack_time;

    vec3 t0_pos;
    vec3 t1_pos;
    vec3 t2_pos;

    vec4 t0_proj_pos;
    vec4 t1_proj_pos;
    vec4 t2_proj_pos;
    vec2 t0_proj_pos_ndc;
    float t0zd;
    float t1zd;
    float t2zd;
    vec2 v0;
    vec2 v1;
    float d00;
    float d01;
    float d11;
    float denom;

    vec2 t0_uv;
    vec2 t1_uv;
    vec2 t2_uv;
} te_out;

void main() {
    vec3 p0 = gl_in[0].gl_Position.xyz * gl_TessCoord.x;
    vec3 p1 = gl_in[1].gl_Position.xyz * gl_TessCoord.y;
    vec3 p2 = gl_in[2].gl_Position.xyz * gl_TessCoord.z;
    gl_Position = vec4(p0 + p1 + p2, 1);

    vec2 t0 = tc_out[0].uv * gl_TessCoord.x;
    vec2 t1 = tc_out[1].uv * gl_TessCoord.y;
    vec2 t2 = tc_out[2].uv * gl_TessCoord.z;
    vec2 uv = t0 + t1 + t2;
    te_out.uv = uv;

    te_out.normal_frag = tc_out[0].normal_frag;
    te_out.obj_pos = tc_out[0].obj_pos;
    te_out.player_dist = tc_out[0].player_dist;
    te_out.plane_dist = tc_out[0].plane_dist;
    te_out.crack_time = tc_out[0].crack_time;

    te_out.t0_pos = tc_out[0].pos;
    te_out.t1_pos = tc_out[1].pos;
    te_out.t2_pos = tc_out[2].pos;

    te_out.t0_proj_pos = t0_proj_pos;
    te_out.t1_proj_pos = t1_proj_pos;
    te_out.t2_proj_pos = t2_proj_pos;

    te_out.t0_proj_pos_ndc = t0_proj_pos_ndc;

    te_out.t0zd = t0zd;
    te_out.t1zd = t1zd;
    te_out.t2zd = t2zd;

    te_out.v0 = v0;
    te_out.v1 = v1;
    te_out.d00 = d00;
    te_out.d01 = d01;
    te_out.d11 = d11;
    te_out.denom = denom;

    te_out.t0_uv = tc_out[0].uv;
    te_out.t1_uv = tc_out[1].uv;
    te_out.t2_uv = tc_out[2].uv;
}

