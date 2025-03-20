#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std430, binding = 1) buffer z_width {
    float z_width_data[];
};

uniform vec3 player_pos;
uniform mat4 projection;

out VS_OUT {
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    vec3 player_pos;
    int v_id;
    int tess_amt;
    // need to make projection a patch for performance
    mat4 projection;
} vs_out;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    vec4 new_pos = transform * aPos;
    float dist = max(0, player_pos.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 30 - new_pos.z);
    new_pos.xyz += (projection * new_pos).xyz * dist * dist * .000006;
    gl_Position = new_pos;
    vs_out.v_id = gl_VertexID;
    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 1.0);
    vs_out.uv = vertexUV;
    vs_out.normal_frag = normal_in;
    vs_out.player_pos = player_pos;
    vs_out.player_dist = dist;
    vs_out.tess_amt = dist > 0 ? 8 : 1;
    vs_out.projection = projection;
}

