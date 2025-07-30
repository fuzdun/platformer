#version 450 core

in vec2 uv;
out vec4 fragColor;

layout (std140, binding = 0) uniform Common
{
    mat4 _;
    float i_time;
};

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
    // vec2 pixellated_uv = floor(uv * 250) / 250;
    vec2 pixellated_uv = uv;
    float shade = pattern(pixellated_uv);
    vec3 pattern_col = vec3(colormap(shade).rgb) * .8;
    fragColor = vec4(pattern_col * 0.5, 1.0);
}

