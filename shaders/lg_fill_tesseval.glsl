#version 460 core

layout(triangles, equal_spacing, ccw) in;

in TC_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    vec3 player_pos;
    int v_id;
    mat4 projection;
    float i_time;
    vec3 pos;
} tc_out[];

out TE_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    vec3 player_pos;
    int v_id;
    mat4 projection;
    float i_time;
    vec3 t0_pos;
    vec3 t1_pos;
    vec3 t2_pos;
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

    int v_id = int(uv.x * 10) + int(uv.y * 10);
    te_out.v_id = v_id;

    te_out.normal_frag = tc_out[0].normal_frag;
    te_out.obj_pos = tc_out[0].obj_pos;
    te_out.player_dist = tc_out[0].player_dist;
    te_out.player_pos = tc_out[0].player_pos;
    te_out.projection = tc_out[0].projection;
    te_out.i_time = tc_out[0].i_time;
    te_out.t0_pos = tc_out[0].pos;
    te_out.t1_pos = tc_out[1].pos;
    te_out.t2_pos = tc_out[2].pos;
    te_out.t0_uv = tc_out[0].uv;
    te_out.t1_uv = tc_out[1].uv;
    te_out.t2_uv = tc_out[2].uv;
}

