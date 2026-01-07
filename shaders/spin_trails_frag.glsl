#version 460 core

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

in vec3 sdf_ray;
in vec3 local_pos;

out vec4 fragColor;

uniform sampler2D depth_buffer;

#define NUMBER_OF_STEPS 25
#define MINIMUM_HIT_DISTANCE 0.001
#define MAXIMUM_TRACE_DISTANCE 80

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
    vec4 col = vec4(0);

    for (int i = 0; i < NUMBER_OF_STEPS; ++i) {
        vec3 current_pos = ro + ray_depth * rd;

        float turbulenceFrequency = 1.4;
        for (int turbulenceIter = 0; turbulenceIter < 5; turbulenceIter++) {
            vec3 turbulenceOffset = cos((current_pos.xzy - vec3(i_time / 0.1, i_time, turbulenceFrequency)) * turbulenceFrequency);
            turbulenceOffset.x = 0.0;
            current_pos += turbulenceOffset / turbulenceFrequency;
            turbulenceFrequency /= 0.6;
        }


        // current_pos *= 1.0 + sin((atan(current_pos.y, current_pos.z) + i_time / 400) * 5.0) / 4.0;
        float distance_to_torus = distance_from_torus(current_pos, vec2(5.0, 0.30));
        // float distance_to_sphere = distance_from_sphere(current_pos, 1.0);

        // if (distance_to_torus < 0.01) {
        //     return vec4(1, 0.75, 0.2, 1);
        // }

        // if (distance_to_sphere < 0.01) {
        //     return vec4(0);
        // }

        // float closest = min(distance_to_torus, distance_to_sphere);
        float closest = distance_to_torus;

        step_size = 0.1 + closest / 7.0;
        ray_depth += step_size;
        col += vec4(0.006, 0.004, 0.001, 0.008) / step_size;
    }
    // return vec4(0);
    if(col.a < 0.65) {
        return vec4(0);
    }
    return col;
}

void main() {
    vec4 frag_depth = texture(depth_buffer, gl_FragCoord.xy);
    fragColor = ray_march(local_pos, normalize(sdf_ray));
    // fragColor += vec4(0.0, 1.0, 0, 0.5);
}

