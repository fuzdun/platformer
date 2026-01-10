#version 460 core

layout (points) in; 
layout (triangle_strip, max_vertices = 4) out;

uniform vec3 camera_dir;
uniform float delta_time;

#define PARTICLE_W 0.15
#define TRAIL_MAG 2.0

in VS_OUT {
    vec3 vel;
} vs_out[];

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

out vec2 uv;
out float intensity;

void main() {
    vec3 pos = gl_in[0].gl_Position.xyz;
    vec3 proj_vel = vs_out[0].vel - camera_dir * dot(vs_out[0].vel, camera_dir);
    vec3 norm_proj_vel = normalize(proj_vel);
    vec3 prev_pos = pos - proj_vel * delta_time * TRAIL_MAG;
    vec3 width_vec = normalize(cross(proj_vel, camera_dir)) * PARTICLE_W;
    intensity = gl_in[0].gl_Position.w;
    gl_Position = projection * vec4((pos - width_vec) + norm_proj_vel * PARTICLE_W, 1.0);
    uv = vec2(0, 0);
    EmitVertex(); 
    gl_Position = projection * vec4((pos + width_vec) + norm_proj_vel * PARTICLE_W, 1.0);
    uv = vec2(1, 0);
    EmitVertex(); 
    gl_Position = projection * vec4((prev_pos - width_vec) - norm_proj_vel * PARTICLE_W, 1.0);
    uv = vec2(0, 1);
    EmitVertex(); 
    gl_Position = projection * vec4((prev_pos + width_vec) - norm_proj_vel * PARTICLE_W, 1.0);
    uv = vec2(1, 1);
    EmitVertex(); 
    EndPrimitive();
}
