#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 4) uniform Transforms
{
    mat4 transforms[1000]; 
};

out vec2 uv;

void main() {
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * aPos;
    uv = vertexUV;
}

