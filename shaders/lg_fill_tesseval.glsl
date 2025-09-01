#version 460 core

layout(triangles, equal_spacing, ccw) in;

in TC_OUT {
    vec2 uv;
    // vec3 pos;
} tc_out[];

patch in vec3 v0;
patch in vec3 v1;
patch in float d00;
patch in float d01;
patch in float d11;
patch in float denom;

patch in vec3 normal_frag;
patch in vec4 obj_pos;
patch in float player_dist;
patch in float plane_dist;
patch in float crack_time;
patch in float break_data[7];
patch in float transparency;

out TE_OUT {
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

    out vec3 v0;
    out vec3 v1;
    out float d00;
    out float d01;
    out float d11;
    out float denom;

    out float transparency;
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

    te_out.normal_frag = normal_frag;
    te_out.obj_pos = obj_pos;
    te_out.player_dist = player_dist;
    te_out.plane_dist = plane_dist;
    te_out.crack_time = crack_time;
    te_out.break_data = break_data;
    te_out.transparency = transparency;

    te_out.t0_pos = gl_in[0].gl_Position.xyz;

    te_out.t0_uv = tc_out[0].uv;
    te_out.t1_uv = tc_out[1].uv;
    te_out.t2_uv = tc_out[2].uv;

    te_out.v0 = v0;
    te_out.v1 = v1;
    te_out.d00 = d00;
    te_out.d01 = d01;
    te_out.d11 = d11;
    te_out.denom = denom;
}

