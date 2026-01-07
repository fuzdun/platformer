#version 460 core

layout(triangles, equal_spacing, ccw) in;

in TC_OUT {
    vec2 uv;
    vec4 obj_pos;
    flat int cracked;
    flat int broken;
    float player_dist;
} tc_out[];

out TE_OUT {
    vec2 uv;
    vec4 obj_pos;
    flat int cracked;
    flat int broken; 
    float player_dist;

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

    te_out.obj_pos = tc_out[0].obj_pos;
    te_out.player_dist = tc_out[0].player_dist;
    te_out.cracked = tc_out[0].cracked;
    te_out.broken = tc_out[0].broken;

    te_out.t0_uv = tc_out[0].uv;
    te_out.t1_uv = tc_out[1].uv;
    te_out.t2_uv = tc_out[2].uv;
}

