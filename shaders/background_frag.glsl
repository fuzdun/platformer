#version 460 core


uniform vec4[16] crunch_pts;
uniform int crunch_pt_count;

in vec2 uv;
out vec4 fragColor;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 8) uniform Intensity
{
    float intensity;
};


vec3 tonemap(vec3 x) {
   return (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);
}

vec3 tonemap2(vec3 x)
{
    x *= 16.0;
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}


#define RADIUS 1.5
#define BASE_TRANSPARENCY 0.1

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// float hash3(vec3 p) {
//     return fract(sin(dot(p, vec3(127.1, 311.7, 654.3))) * 43758.5453123);
// }

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i + vec2(0.0, 0.0)), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

float ease_out(float x) {
    return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x) * (1.0 - x);
}

float random(float n){return fract(sin(n) * 43758.5453123);}

void main() {
    vec2 standard_uv = uv * 2.0 - 1.0;



    float z = 0.0;
    float d = 0.0;
    vec2 uv = standard_uv;
    vec3 ray = normalize(vec3(uv, -1.0));
    vec3 col = vec3(0.0);
    float t = i_time / 2000;

    for (float i = 0.0; i < 2.; i++) {
        vec3 p = z * ray;
        p.z += 10.;   
        p.xy *= mat2(cos(p.z * .15 + vec4(2.5,2.5,2.5,0)));
        for (float freq = 1.1; freq <= 2.0; freq *= 1.4) {
            vec3 dir = p.zxy + vec3(t * 1.2, t * 1.1, -t * 1.9);
            vec3 off = cos(dir * freq) / freq;
            p += off;
        }
            
        float dist = cos(p.y * 0.5 + t * 3.7) + sin(p.x * 0.25 + t * 1.3) + p.z;
        float stepSize = .01 + dist / 1.0;
        z += stepSize;
        col = (sin(z / 3.0 + vec3(2.3, 1.5, 8.1)) + 1.0) / (stepSize * 10.0);
    }
    vec4 base_color = vec4(tonemap(col), 1.0);






    vec2 floored_uv = round(standard_uv * 5.0) / 5.0;
    vec2 uv_deviation = standard_uv - floored_uv;

    // center-relative uv with distortion based on position within screen-space cells
    vec2 boxed_uv = standard_uv + uv_deviation * uv_deviation * 30.;

    float final_transparency = 0.0;
    vec3 color = vec3(0);

    for (int i = 0; i < crunch_pt_count; i++) {
        vec4 cpt = crunch_pts[i]; 
        vec4 proj_pt = projection * vec4(cpt.xyz, 1.0);
        vec2 pt = (proj_pt / proj_pt.w).xy;
        float standard_crunch_pt_dist = length(standard_uv - pt);
        float radial_transparency = smoothstep(0.0, 0.1, standard_crunch_pt_dist) - smoothstep(RADIUS, RADIUS + 0.1, standard_crunch_pt_dist);
        vec2 boxed_crunch_pt_diff = boxed_uv - pt;
        float time_t = max((i_time - cpt.w), 0.01) /(1200.0 - 600 * intensity);
        float noise_sample = noise(i_time / 1000.0 + i + normalize(boxed_crunch_pt_diff) + time_t * vec2(0.25, 0.25));
        float transparency = (1.0 - length(boxed_crunch_pt_diff)) - noise_sample + time_t;
        float smoothed_transparency = smoothstep(0.0, 0.1, transparency) - smoothstep(0.90, 1.00, transparency);
        smoothed_transparency *= radial_transparency * BASE_TRANSPARENCY + 0.35 * intensity;
        final_transparency = max(smoothed_transparency, final_transparency);
        vec3 this_color = vec3(random(cpt.w), random(cpt.w * 2.0), random(cpt.w * 3.0));
        color = mix(color, this_color, smoothed_transparency);
    }
    // col.a = 0
    
    // float noise_sample = noise(normalize(standard_uv) + i_time * vec2(0.5, 0.5));
    // float noise_disp = noise_sample * ease_out(t) * .2;
    // // Time varying pixel color
    // float diffusion = length(center_uv) / (t - noise_disp);
    // vec3 col = abs(sin(vec3(2.1, 0.0, 0.0) + diffusion * vec3(1.0, 0.0, 1.0)));
    // fragColor = mix(vec4(col, 1.0), vec4(0.0, 0.0, 0.0, 0.0), diffusion * diffusion * 0.7 + 0.3 + i_time / 4000.0);
    // // fragColor = mix(vec4(col, 1.0), vec4(0.0, 0.0, 0.0, 0.0), diffusion * diffusion * 0.7 + 0.3);
    fragColor = mix(base_color, vec4(color, final_transparency), 0.75);
}

