#version 450 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

in VS_OUT {
    vec2 uv;
} gs_in[];

out vec2 uv;
uniform mat4 projection;

void main() {
    for(int i=0; i < 3; i++) {
        gl_Position = projection * gl_in[i].gl_Position;
        uv = gs_in[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

