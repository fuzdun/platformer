#version 460 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

in VS_OUT {
    vec2 uv;
    vec3 normal;
    float plane_dist;
    vec4 pos;
} vs_out[];

// out vec2 uv;
out vec3 normal;
out vec3 t0_pos;
out vec3 t1_pos;
out vec3 t2_pos;
out vec2 t0_uv;
out vec2 t1_uv;
out vec2 t2_uv;
out float plane_dist;

void main() {
    plane_dist = vs_out[0].plane_dist;
    t0_pos = vec3(vs_out[0].pos);
    t1_pos = vec3(vs_out[1].pos);
    t2_pos = vec3(vs_out[2].pos);
    t0_uv = vs_out[0].uv;
    t1_uv = vs_out[1].uv;
    t2_uv = vs_out[2].uv;
    normal = vs_out[0].normal;
    for(int i=0; i < 3; i++) {
        // uv = vs_out[i].uv;
        gl_Position = gl_in[i].gl_Position;
        EmitVertex();
    }
    EndPrimitive();
}

