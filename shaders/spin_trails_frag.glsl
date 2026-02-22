#version 460 core

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	float _pad0;
	vec3 cam_pos;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir;
    float inner_tess;
    float outer_tess;
	vec4 _pad1;
};

in vec3 sdf_ray;
in vec3 local_pos;

out vec4 fragColor;

uniform float spin_amt;

#define NUMBER_OF_STEPS 30
#define MINIMUM_HIT_DISTANCE 0.001
#define MAXIMUM_TRACE_DISTANCE 80

vec3 plasma(float t) {
    t = clamp(t, 0.0, 1.0);
    return clamp(vec3((0.057526+t*(2.058166+t*-1.141244)),
                      (-0.183275+t*(0.668964+t*0.479353)),
                      (0.525210+t*(1.351117+t*(-4.013494+t*2.284066)))), 0.0, 1.0);
}

float distance_from_torus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.yz)-t.x,p.x);
    return length(q)-t.y;
}

float distance_from_sphere(vec3 p, float r) {
    return length(p) - r;
}

vec4 ray_march(vec3 ro, vec3 rd) {
    float ray_depth = 0;
    float step_size = 0;
    vec3 col = vec3(0);
    float a = 0;

    for (int i = 0; i < NUMBER_OF_STEPS; ++i) {
        vec3 current_pos = ro + ray_depth * rd;

        float turbulenceFrequency = 2.4;
        for (int turbulenceIter = 0; turbulenceIter < 5; turbulenceIter++) {
            vec3 turbulenceOffset = cos((current_pos.xzy - vec3(i_time / 500, i_time / 100, turbulenceFrequency)) * turbulenceFrequency);
            turbulenceOffset.x = 0.0;
            current_pos += turbulenceOffset / turbulenceFrequency;
            turbulenceFrequency /= 0.6;
        }


        float width_fact = 1.0 - (1.0 - spin_amt) * (1.0 - spin_amt);
        float distance_to_torus = distance_from_torus(current_pos, vec2(2.0 + 8.0 * width_fact, 0.5));
        // float distance_to_sphere = distance_from_sphere(current_pos, 1.0);

        // float closest = min(distance_to_torus, distance_to_sphere);
        float closest = distance_to_torus;

        step_size = 0.1 + closest / 7.0;
        ray_depth += step_size;
        col += (plasma(cos(step_size / .1) * 0.5 + 0.5) / step_size) * 0.01;
        a += 0.004 / step_size;
    }
    // return vec4(0);
    if(a < 0.35) {
        return vec4(0);
    }
    return vec4(col, a);
}

void main() {
    fragColor = ray_march(local_pos, normalize(sdf_ray));
    // fragColor += 1.0;
}

