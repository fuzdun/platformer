#version 460 core

layout (location = 0) in vec4 a_pos;
layout (location = 1) in vec2 vertex_uv;
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

struct Break_Data {
    vec4 break_time_pos;
    vec4 crack_time_break_dir;
};

layout (std140, binding = 6) uniform Shatter_Datas
{
    Break_Data break_data[1000]; 
};

layout (std140, binding = 7) uniform Transparencies
{
    float transparencies_data[1000]; 
};

uniform float shatter_delay;

out vec2 uv;
out float transparency;

#define BREAK_FADE_LEN 200.0

void main() {
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * a_pos;
    uv = vertex_uv;
    float crack_time = break_data[gl_BaseInstance + gl_InstanceID].crack_time_break_dir[0];
    float shatter_time = crack_time + shatter_delay;
    transparency = transparencies_data[gl_BaseInstance + gl_InstanceID];
    if (crack_time != 0 && i_time > shatter_time) {
        transparency = 1.0 - clamp((i_time - shatter_time) / BREAK_FADE_LEN, 0, 1);
    }
}

