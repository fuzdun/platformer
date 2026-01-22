#version 460 core

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

in vec2 perspective_uv;
in vec3 normal_frag;
in float displacement;

in float plane_dist;
in vec3 t0_pos;
in vec2 t0_uv;
in vec2 t1_uv;
in vec2 t2_uv;

// in vec3 b0_pos;
// in vec3 b1_pos;
// in vec3 b2_pos;
in vec3 b_poss[3];

in vec3 global_pos;

in vec3 v0;
in vec3 v1;
in float d00;
in float d01;
in float d11;
in float denom;

in float did_shatter;

uniform vec3 camera_pos;
uniform mat4 inverse_projection;
uniform mat4 inverse_view;

uniform sampler2D ditherTexture;

out vec4 fragColor;

#define LINE_W 0.4
#define SAMPLE_RES 600
#define SCREEN_WIDTH 1920.0
#define SCREEN_HEIGHT 1080.0

float reshapeUniformToTriangle(float v) {
    v = v * 2.0 - 1.0;
    v = sign(v) * (1.0 - sqrt(max(0.0, 1.0 - abs(v))));
    return v + 0.5;
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

float dot2( in vec3 v ) { return dot(v,v); }

float udTriangle( in vec3 v1, in vec3 v2, in vec3 v3, in vec3 p )
{
    vec3 v21 = v2 - v1; vec3 p1 = p - v1;
    vec3 v32 = v3 - v2; vec3 p2 = p - v2;
    vec3 v13 = v1 - v3; vec3 p3 = p - v3;
    vec3 nor = cross( v21, v13 );

    return sqrt(min(min( 
        dot2(v21*clamp(dot(v21,p1)/dot2(v21),0.0,1.0)-p1), 
        dot2(v32*clamp(dot(v32,p2)/dot2(v32),0.0,1.0)-p2)), 
        dot2(v13*clamp(dot(v13,p3)/dot2(v13),0.0,1.0)-p3)));
}

const float BAYER16[16] = float[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float GetBayerDither(float grayscale, vec2 uv) {    
    ivec2 pixelCoord = ivec2(uv * (SAMPLE_RES));
    int pixelIndex16 = (pixelCoord.x % 4) + (pixelCoord.y % 4) * 4;
    return grayscale > (float(BAYER16[pixelIndex16]) + 0.5) / 16.0 ? 1.0 : 0.0;
}

void main()
{
    vec2 screen_uv = gl_FragCoord.xy;
    screen_uv.x /= SCREEN_WIDTH;
    screen_uv.y /= SCREEN_WIDTH;
    screen_uv = floor(screen_uv * SAMPLE_RES) / SAMPLE_RES;

    vec2 rounded_frag = screen_uv * SCREEN_WIDTH;
    vec3 ndc = vec3(
        (rounded_frag.x / SCREEN_WIDTH - 0.5) * 2.0,
        (rounded_frag.y / SCREEN_HEIGHT - 0.5) * 2.0,
        1.0
    );
    vec4 ray_clip = vec4(ndc.xy, -1.0, 1.0);
    vec4 ray_eye = inverse_projection * ray_clip;
    vec3 ray_wor = normalize((inverse_view * vec4(ray_eye.xy, -1.0, 0.0)).xyz);
    vec3 intersection = (plane_dist + dot(-camera_pos, normal_frag)) / dot(-normal_frag, ray_wor) * ray_wor - camera_pos;
    intersection *= -1;

    vec3 t_diff = intersection - player_pos;

    vec3 v2 = intersection - t0_pos;
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float bary_1 = (d11 * d20 - d01 * d21) / denom;
    float bary_2 = (d00 * d21 - d01 * d20) / denom;
    float bary_0 = 1.0 - bary_1 - bary_2;
    vec2 uv = t0_uv * bary_0 + t1_uv * bary_1 + t2_uv * bary_2;

    float plane_off = dot(normal_frag, global_pos);
    float dist = (dot(normal_frag, player_pos) - plane_off) + 4.5;
    vec3 up = normal_frag.y == 1.0 ? vec3(1, 0, 0) : vec3(1.0, 0, 0);
    vec3 plane_x = normalize(cross(up, normal_frag));
    vec3 plane_y = normalize(cross(normal_frag, plane_x));
    vec3 proj_pt = player_pos - dist * normal_frag;
    vec3 planar_diff = proj_pt - global_pos;
    float uvd = length(planar_diff);
    float uvx = dot(plane_x, planar_diff);
    float uvy = dot(plane_y, planar_diff);
    float a = atan(uvx / uvy) * 25;
    float d1 = dist + noise(vec2(a + i_time / 60.0, i_time / 80.0)) * 2.5;
    float absd = abs(uvd - d1);
    float noise_border = smoothstep(-0.2, 0.0, absd) - smoothstep(0.2, 0.4, absd);
    vec4 proximity_outline_col = vec4(1.0, 1.0, 0.0, 1.0) * noise_border;

    float sd = (udTriangle(b_poss[0], b_poss[1], b_poss[2], global_pos));
    float border_t = smoothstep(0.0, LINE_W, sd);

    float mask = GetBayerDither(ceil(length(t_diff) / 4.5) / 30.0 - 0.2, screen_uv);

    fragColor = mix(vec4(0.5, 0.0, 0.5, 0.8), vec4(0.0, 0.0, 0.0, 1.0), mask);
    fragColor = mix(vec4(1.0, 0.0, 0.0, 1.0), fragColor, border_t);
    fragColor += proximity_outline_col;
    fragColor.r *= 1.5 + (1.0 - (mask / 2.0));
}

