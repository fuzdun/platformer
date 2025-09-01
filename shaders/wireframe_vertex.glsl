#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float _;
};

uniform vec3 camera_pos;

out float camera_dist;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    vec4 transformed_pos = transform * aPos;
    camera_dist = max(0, camera_pos.z - 50.0 - transformed_pos.z);
    gl_Position = projection * transformed_pos;
}

