#version 460 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;

in VS_OUT {
    vec4 obj_pos;
    vec2 uv;
} gs_in[];

out vec2 uv;
uniform mat4 projection;

void main() {
    vec4 avg_pos = (gl_in[0].gl_Position + gl_in[1].gl_Position + gl_in[2].gl_Position) / 3.0;
    vec4 disp = avg_pos - gs_in[0].obj_pos;
    for(int i=0; i < 3; i++) {
        gl_Position = projection * (gl_in[i].gl_Position + disp * .05);
        uv = gs_in[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

