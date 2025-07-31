#version 450 core

in vec2 uv;
out vec4 fragColor;

layout (std140, binding = 0) uniform Common
{
    mat4 _;
    float i_time;
};

#define RADIUS 0.5
#define CRUNCH_PT_COUNT 2


vec4 colormap(float x) {
    float v = cos(20.0 * x) * 28.0 + 30.0 * x + 27.0;
    if (v > 255.0) {
        v = 510.0 - v;
    }
    v = v / 255.0;
    return vec4(v, v * 1, v, 1.0);
}


float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

float ease_out(float x) {
    return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x) * (1.0 - x);
}



float fbm (vec2 p )
{
    // float intv1 = sin((i_time + 12.0) / 10.0);
    // float intv2 = cos((i_time + 12.0) / 10.0);

    // mat2 mtx_off = mat2(intv1, 1.0, intv2, 1.0);
    mat2 mtx = mat2(1.6, 1.2, -1.2, 1.6);
    // mtx = mtx_off * mtx;
    float f = 0.0;
    f += 0.25*noise( p + (i_time / 2000) * 1.5); p = mtx*p;
    f += 0.25*noise( p ); p = mtx*p;
    f += 0.25*noise( p ); p = mtx*p;
    f += 0.25*noise( p );
    return f;
}

float pattern( in vec2 p )
{
	return fbm(p + fbm(p + fbm(p)));
}

void main() {
    float shade = pattern(uv);
    vec3 pattern_col = vec3(colormap(shade).rgb) * .8;
    fragColor = vec4(0);
    // fragColor = vec4(pattern_col * 0.5, 1.0);

    float t = i_time / 1000.0;
    vec2 center_uv = uv * 2.0 - 1.0;

    vec2 floored_uv = round(center_uv * 10.0) / 10.0;
    vec2 diff = center_uv - floored_uv;
    center_uv = center_uv + diff * diff * 20.0;

    vec2 crunch_pts[CRUNCH_PT_COUNT] = vec2[](vec2(-0.5, -0.5), vec2(0.5, 0.5));

    vec3 col = vec3(0.0);

    for (int i = 0; i < CRUNCH_PT_COUNT; i++) {
        vec2 pt = crunch_pts[i]; 
        vec2 pt_diff = center_uv - pt;
        float noise_sample = noise(i + normalize(pt_diff) + i_time * vec2(0.5, 0.5));
        float noise_disp = noise_sample * ease_out(t) * .2;
        float diffusion = length(pt_diff) / (t - noise_disp);
        vec3 this_col = abs(sin(vec3(2.1, 0.0, 0.0) + diffusion * vec3(1.0, 0.0, 1.0)));
        float mix_fact = clamp(diffusion * diffusion * 0.7 + 0.3 + i_time / 4000.0, 0, 1);
        col = mix(this_col, col, mix_fact);
    }
    fragColor = vec4(col, 1.0);
    
    // float noise_sample = noise(normalize(center_uv) + i_time * vec2(0.5, 0.5));
    // float noise_disp = noise_sample * ease_out(t) * .2;
    // // Time varying pixel color
    // float diffusion = length(center_uv) / (t - noise_disp);
    // vec3 col = abs(sin(vec3(2.1, 0.0, 0.0) + diffusion * vec3(1.0, 0.0, 1.0)));
    // fragColor = mix(vec4(col, 1.0), vec4(0.0, 0.0, 0.0, 0.0), diffusion * diffusion * 0.7 + 0.3 + i_time / 4000.0);
    // // fragColor = mix(vec4(col, 1.0), vec4(0.0, 0.0, 0.0, 0.0), diffusion * diffusion * 0.7 + 0.3);
    //
}

