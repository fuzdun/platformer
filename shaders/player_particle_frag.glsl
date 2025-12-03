#version 460 core

in vec2 uv;
in float f_radius;
in float i_time_frag;
flat in int id;

out vec4 fragColor;

const vec3 COLOR1 = vec3(0.9, 0.35, 0.9);
const vec3 COLOR2 = vec3(0.2, 0.2, 0.8);

float distance_from_sphere(vec3 p, vec3 c, float r) {
    return length(p - c) - r;
}

float map_world(vec3 p) {
    float t = i_time_frag / 300 + id * 1000.0;
    float displacment = (sin(3.0 * p.x + t) + 0.25) * (sin(2.0 * p.y + t) + 0.25) * (sin(1.0 * p.z + t) + 0.25) * .20;
    return distance_from_sphere(p, vec3(0.0, 0.0, 0.0), f_radius) + displacment;
}

vec3 calculate_normal(vec3 p) {
    vec2 step = vec2(0.001, 0.0);
    float x_grad = map_world(p + step.xyy) - map_world(p - step.xyy);
    float y_grad = map_world(p + step.yxy) - map_world(p - step.yxy);
    float z_grad = map_world(p + step.yyx) - map_world(p - step.yyx);
    return normalize(vec3(x_grad, y_grad, z_grad));
}

vec4 ray_march(vec3 ro, vec3 rd) {
    float total_distance_traveled = 0.0;
    const int NUMBER_OF_STEPS = 32;
    const float MINIMUM_HIT_DISTANCE = 0.001;
    const float MAXIMUM_TRACE_DISTANCE = 1000.0;

    for (int i = 0; i < NUMBER_OF_STEPS; ++i) {
        vec3 current_pos = ro + total_distance_traveled * rd;
        float distance_to_closest = map_world(current_pos);
        if (distance_to_closest < MINIMUM_HIT_DISTANCE) {
            // vec3 normal = calculate_normal(current_pos) * 0.5 + 0.5;
            vec3 normal = calculate_normal(current_pos);
            vec3 light_pos = vec3(4.0, 4.0, -6.0);
            vec3 light_dir = normalize(light_pos - current_pos);
            float diffuse_amt = dot(normal, light_dir);
            // float diffuse_amt = dot(normal, light_dir);
            // return diffuse_amt > .32 ? vec4(COLOR1, 1.0) : vec4(COLOR2, 1.0);
            return mix(vec4(COLOR1, 1.0), vec4(COLOR2, 1.0), diffuse_amt);
            // return vec4(COLOR1.xy, diffuse_amt, 1.0);
            // return vec4(COLOR1, 1.0) * diffuse_amt + vec4(COLOR2, 1.0) * (1.0 - diffuse_amt); 
        }
        if (total_distance_traveled > MAXIMUM_TRACE_DISTANCE) {
            break;
        }
        total_distance_traveled += distance_to_closest;
    }
    discard;
    // return vec4(0.0);
}

void main() {
    vec2 uv2 = uv * 2.0 - 1.0;
    vec3 camera_pos = vec3(0.0, 0.0, -5.0);
    vec3 ro = camera_pos;
    vec3 rd = vec3(uv2, 1.0);
    // vec4 col = ray_march(ro, rd);
    vec4 col = vec4(1.0, 1.0, 1.0, 1.0);
    float intensity = max(0, pow(1.0 - length(uv2), 3));
    // if (intensity <= 0.1) {
    //     discard;
    // }
    float a_fact = intensity * f_radius;
    col.a *= 1.0 - smoothstep(0.3, 0.25, a_fact);
    fragColor = col;
    // fragColor = col; 
}
// void main() {
//     float radius = length(uv - vec2(0.5, 0.5));
//     float t_fact = 1.0 - smoothstep(0.4, 0.45, radius);
//     fragColor = vec4(1.0, 0.8, 0.0, t_fact);
// }

