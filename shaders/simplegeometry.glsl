#version 450 core

layout (triangles) in; 
layout (triangle_strip, max_vertices = 3) out;
// layout (std430, binding = 1) buffer obj_poss {
//     vec3 obj_poss_data[];
// };

in VS_OUT {
    vec2 uv;
} gs_in[];

out vec2 uv;
uniform mat4 projection;

void main() {
    for(int i=0; i < 3; i++) {
        vec4 new_pos = gl_in[i].gl_Position;
        // new_pos -= vec4(obj_poss_data[gs_in[i].v_id], 0.0);
        gl_Position = projection * new_pos;   
        uv = gs_in[i].uv;
        EmitVertex();
    }
    EndPrimitive();
}

