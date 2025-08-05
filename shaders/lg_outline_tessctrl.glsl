#version 460 core 

layout (vertices=3) out;

in VS_OUT {
    vec2 uv;
    vec3 obj_pos;
    flat int cracked;
    float player_dist;
    float tess_amt;

} vs_out[];

out TC_OUT {
    vec2 uv;
    vec3 obj_pos;
    flat int cracked;
    float player_dist;
} tc_out[];

void main() {
    tc_out[gl_InvocationID].uv = vs_out[gl_InvocationID].uv;
    tc_out[gl_InvocationID].obj_pos = vs_out[gl_InvocationID].obj_pos;
    tc_out[gl_InvocationID].cracked = vs_out[gl_InvocationID].cracked;
    tc_out[gl_InvocationID].player_dist = vs_out[gl_InvocationID].player_dist;
  
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;

    if (gl_InvocationID == 0) {
        gl_TessLevelOuter[0] = vs_out[0].tess_amt;
        gl_TessLevelOuter[1] = vs_out[0].tess_amt;
        gl_TessLevelOuter[2] = vs_out[0].tess_amt;
        gl_TessLevelInner[0] = vs_out[0].tess_amt == 1 ? 1 : vs_out[0].tess_amt - 3;
    }
}

