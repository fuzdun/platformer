#version 460 core

layout (lines) in; 
layout (line_strip, max_vertices = 100) out;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	vec2 _padding0;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir_in;
    float inner_tess;
    float outer_tess;
};

uniform float resolution;

in float v_t[];
out float t;
out float dash_time_frag;
out float i_time_frag;

float rand(float n){return mod(sin(n) * 43758.5453123, 360);}

void main() {

    dash_time_frag = dash_total;
    i_time_frag = i_time;

    vec4 step = (gl_in[1].gl_Position - gl_in[0].gl_Position) / resolution;

    for(int i=0; i < 3; i++) {
        gl_Position = projection * gl_in[0].gl_Position + step * i;
        t = float(i) / resolution - 1;
        EmitVertex();
    }

    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 lateral = cross(normalize(step.xyz), up);
    for(int i=3; i < resolution - 3; i++) {
        vec4 interp_pos = gl_in[0].gl_Position + step * i;
        float rnd_angle = rand(float(i) + dash_time);
        float w_disp = sin(rnd_angle);
        float h_disp = cos(rnd_angle);
        interp_pos.xyz += (up * h_disp + lateral * w_disp) * .5;

        gl_Position = projection * interp_pos;
        t = float(i) / resolution - 1;
        EmitVertex();
    }

    for(int i=int(resolution - 3); i < resolution; i++) {
        gl_Position = projection * gl_in[1].gl_Position - (resolution - i) * step;
        t = float(i) / resolution - 1;
        EmitVertex();
    }

    EndPrimitive();
}

