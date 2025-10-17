#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std140, binding = 4) uniform Transforms
{
    mat4 transforms[1000]; 
};

uniform mat4 projection;

out VS_OUT {
    vec2 uv;
    vec3 normal;
    float plane_dist;
    vec4 pos;
} vs_out;

void main() {
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * aPos;
    vs_out.normal = normalize(mat3(transpose(inverse(transform))) * normal_in).xyz;
    vs_out.plane_dist = dot((transform * aPos).xyz, normal_in);
    vs_out.pos = transform * aPos;
    vs_out.uv = vertexUV;
}

