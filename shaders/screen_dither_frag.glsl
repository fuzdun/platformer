#version 460 core

in vec3 normal;
in float plane_dist;
in vec3 t0_pos;
in vec3 t1_pos;
in vec3 t2_pos;
in vec2 t0_uv;
in vec2 t1_uv;
in vec2 t2_uv;

out vec4 fragColor;

uniform vec3 camera_pos;
uniform sampler2D ditherTexture;
uniform mat4 inverse_projection;
uniform mat4 inverse_view;

layout (std140, binding = 0) uniform Common
{
    mat4 _;
    float i_time;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

float colormap_red(float x) {
    if (x < 0.0) {
        return 167.0;
    } else if (x < (2.54491177159840E+02 + 2.49117061281287E+02) / (1.94999353031535E+00 + 1.94987400471999E+00)) {
        return -1.94987400471999E+00 * x + 2.54491177159840E+02;
    } else if (x <= 255.0) {
        return 1.94999353031535E+00 * x - 2.49117061281287E+02;
    } else {
        return 251.0;
    }
}

float colormap_green(float x) {
    if (x < 0.0) {
        return 112.0;
    } else if (x < (2.13852573128775E+02 + 1.42633630462899E+02) / (1.31530121382008E+00 + 1.39181683887691E+00)) {
        return -1.39181683887691E+00 * x + 2.13852573128775E+02;
    } else if (x <= 255.0) {
        return 1.31530121382008E+00 * x - 1.42633630462899E+02;
    } else {
        return 195.0;
    }
}

float colormap_blue(float x) {
    if (x < 0.0) {
        return 255.0;
    } else if (x <= 255.0) {
        return -9.84241021836929E-01 * x + 2.52502692064968E+02;
    } else {
        return 0.0;
    }
}

vec4 colormap(float x) {
    float t = x * 255.0;
    float r = colormap_red(t) / 255.0;
    float g = colormap_green(t) / 255.0;
    float b = colormap_blue(t) / 255.0;
    return vec4(r, g, b, 1.0);
}


float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float rand(float n){return fract(sin(n) * 43758.5453123);}

//float noise function 
float noise(float p){
	float fl = floor(p);
  float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
}

//vec noise function
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
    float intv1 = sin((i_time / 4000.0 + 12.0) / 10.0);
    float intv2 = cos((i_time / 4000.0 + 12.0) / 10.0);

    mat2 mtx_off = mat2(intv1, 1.0, intv2, 1.0);
    mat2 mtx = mat2(1.6, 1.2, -1.2, 1.6);
    mtx = mtx_off * mtx;
    float f = 0.0;
    f += 0.25*noise( p + i_time / 4000.0 * 1.5); p = mtx*p;
    f += 0.25*noise( p ); p = mtx*p;
    f += 0.25*noise( p ); p = mtx*p;
    f += 0.25*noise( p );
    return f;
}

float pattern( in vec2 p )
{
	return fbm(p + fbm(p + fbm(p)));
}

void main()
{
    float screen_width = 900.0;
    float screen_height = 900.0;

    vec4 rounded_frag =  gl_FragCoord;
    rounded_frag.xy = ceil(gl_FragCoord.xy / 15.0) * 15.0;

    vec3 ndc = vec3(
        (rounded_frag.x / screen_width - 0.5) * 2.0,
        (rounded_frag.y / screen_height - 0.5) * 2.0,
        1.0
    );
    vec4 ray_clip = vec4(ndc.xy, -1.0, 1.0);
    // ray_clip = ray_clip / ray_clip.w;
    vec4 ray_eye = inverse_projection * ray_clip;
    vec3 ray_wor = normalize((inverse_view * vec4(ray_eye.xy, -1.0, 0.0)).xyz);
    vec3 camera_off = -camera_pos;
    vec3 intersection = (plane_dist + dot(camera_off, normal)) / dot(-normal, ray_wor) * ray_wor + camera_off;
    intersection *= -1;
    // intersection.y *= -1;
    // vec3 intersection = plane_dist / dot(-normal, ray_wor) * ray_wor;
    // vec4 clip = inverse_projection * ndc;
    // vec4 vertex = (clip / clip.w);
    // vec4 vertex = (clip);
    // vertex = inverse_view * vertex;
    // vec3 col = vec3(intersection.x, 0.0, 0.0);
    // vec3 col = vec3(sign(dot(ray_wor, normal)), 0.0, 0.0);
    // if (length(camera_pos) == 0) {
    //     col = vec3(1.0, 0, 0);
    // }

    vec3 v0 = t1_pos - t0_pos;
    vec3 v1 = t2_pos - t0_pos;
    vec3 v2 = intersection - t0_pos;
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float denom =  d00 * d11 - d01 * d01;
    float bary_1 = (d11 * d20 - d01 * d21) / denom;
    float bary_2 = (d00 * d21 - d01 * d20) / denom;
    float bary_0 = 1.0 - bary_1 - bary_2;

    // float bary_0 = (p1_dist - abs(dot(p1_normal, intersection - t0_pos))) / p1_dist;
    // float bary_1 = (p2_dist - abs(dot(p2_normal, intersection - t1_pos))) / p2_dist;
    // float bary_2 = (p0_dist - abs(dot(p0_normal, intersection - t2_pos))) / p0_dist;

    // vec2 i_uv = vec2(intersection.x / 40.0, intersection.z / 40.0);
    vec2 i_uv = t0_uv * bary_0 + t1_uv * bary_1 + t2_uv * bary_2;

    float shade = pattern(i_uv);
    vec3 col = vec3(colormap(shade).rgb);
    // vec3 col = vec3(intersection.x / 2.0, 0, 0);
    // vec3 col = vec3(length(t0_pos) / 1000.0, 0.0, 0.0);
    // vec3 col = vec3(plane_dist / 100.0, 0, 0);
    // vec3 col = vec3(bary_0, bary_1, bary_2);
    // vec3 col = vec3(intersection.x, 0, 0);
    // vec3 col = vec3(intersection.x, intersection.y, intersection.z);
    // vec3 col = vec3(length(intersection - player_pos) / 10.0, 0, 0);

    float diff = length(player_pos - intersection);
    float mask = texture(ditherTexture, i_uv * 2.0).r;
    mask = floor(mask + length(diff) / 4.0) / 5.0; 
    // mask = reshapeUniformToTriangle(mask);
    // col.a = mask;

    // fragColor = mix(vec4(col, 1.0), vec4(0.0), length(uv));
    fragColor = mix(vec4(col, 1.0), vec4(0.0), mask);
    // fragColor = mix(vec4(col, 1.0), vec4(0.0), length(uv));
    // fragColor = vec4(col, 1.0);
}


