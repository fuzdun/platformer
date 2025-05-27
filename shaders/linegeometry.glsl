#version 460 core

layout (lines) in; 
layout (line_strip, max_vertices = 100) out;

uniform float resolution;
uniform mat4 projection;
uniform float dash_time;

in float v_t[];
out float t;
out float dash_time_frag;

float rand(float n){return mod(sin(n) * 43758.5453123, 360);}

void main() {
    vec4 step = (gl_in[1].gl_Position - gl_in[0].gl_Position) / resolution;
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 lateral = cross(normalize(step.xyz), up);
    for(int i=0; i < resolution; i++) {
        vec4 interp_pos = gl_in[0].gl_Position + step * i;
        float rnd_angle = rand(float(i) + dash_time);
        float w_disp = sin(rnd_angle);
        float h_disp = cos(rnd_angle);
        interp_pos.xyz += (up * h_disp + lateral * w_disp) * 1.0;
        // interp_pos.y += sin(t * 10.0 * 3.14) * 0.5;
        gl_Position = projection * interp_pos;
        t = float(i) / resolution - 1;
        dash_time_frag = dash_time;
        EmitVertex();
    }
    EndPrimitive();
}

