#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

out VS_OUT {
    vec4 obj_pos;
    vec2 uv;
} vs_out;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 0.0);
    gl_Position = transform * aPos;
    vs_out.uv = vertexUV;
}

