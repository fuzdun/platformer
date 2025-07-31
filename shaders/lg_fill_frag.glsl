#version 460 core

out vec4 fragColor;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

in vec3 global_pos;
in vec2 perspective_uv;
in vec3 normal_frag;
in float displacement;

in float plane_dist;
in vec3 t0_pos;
in vec3 t1_pos;
in vec3 t2_pos;
in vec2 t0_uv;
in vec2 t1_uv;
in vec2 t2_uv;

uniform vec3 camera_pos;
uniform vec3[3] player_trail;
uniform vec3 crunch_pt;
uniform float crunch_time;
uniform mat4 inverse_projection;
uniform mat4 inverse_view;

uniform sampler2D ditherTexture;

#define TWOPI 6.2831853
#define SHADES 3.0


vec2 distanceToSegment( vec3 a, vec3 b, vec3 p )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), .00, 1.00 );
	return vec2(length( pa - ba*h ), h);
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

vec3 tonemap(vec3 x)
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

vec3 pattern(vec2 uv_in) {
    float t = i_time / 500.;
    float z = 0.0;
    float d = 0.0;
    vec2 uv = uv_in * 2.0 - 1.0;
    vec3 ray = normalize(vec3(uv, -6.0));
    vec3 col = vec3(0.0);

    for (float i = 0.0; i < 10.; i++) {
        vec3 p = z * ray;
        p.z += 80.;   
        p.xy *= mat2(cos(p.z * .15 + vec4(2.5,2.5,2.5,0)));
        for (float freq = 1.1; freq <= 2.0; freq *= 1.4) {
            vec3 dir = p.zxy + vec3(t * 1.2, t * 1.1, -t * 1.9);
            vec3 off = cos(dir * freq) / freq;
            p += off;
        }
            
        float dist = cos(p.y * 0.5 + t * 3.7) + sin(p.x * 0.25 + t * 1.3) + p.z;
        float stepSize = .01 + dist / 6.0;
        z += stepSize;
            col = (sin(z / 2.0 + vec3(9.1, 4.4, 5.1)) + 1.0) / (stepSize * 1.0);
    }
    return tonemap(col);
}

float jaggy(float x)
{
    return abs(mod(x, 1) - .5) - .5;
}

float reshapeUniformToTriangle(float v) {
    v = v * 2.0 - 1.0;
    v = sign(v) * (1.0 - sqrt(max(0.0, 1.0 - abs(v))));
    return v + 0.5;
}

#define SAMPLE_RES 640.0

void main()
{
    float time = i_time / 1000.0;

    // get floored uv
    float screen_width = 1920.0;
    float screen_height = 1080.0;

    vec2 screen_uv = gl_FragCoord.xy;
    screen_uv.x /= screen_width;
    screen_uv.y /= screen_width;
    screen_uv = floor(screen_uv * SAMPLE_RES) / SAMPLE_RES;

    vec2 rounded_frag = screen_uv * screen_width;
    vec3 ndc = vec3(
        (rounded_frag.x / screen_width - 0.5) * 2.0,
        (rounded_frag.y / screen_height - 0.5) * 2.0,
        1.0
    );
    vec4 ray_clip = vec4(ndc.xy, -1.0, 1.0);
    vec4 ray_eye = inverse_projection * ray_clip;
    vec3 ray_wor = normalize((inverse_view * vec4(ray_eye.xy, -1.0, 0.0)).xyz);
    vec3 intersection = (plane_dist + dot(-camera_pos, normal_frag)) / dot(-normal_frag, ray_wor) * ray_wor - camera_pos;
    intersection *= -1;

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
    vec2 uv = t0_uv * bary_0 + t1_uv * bary_1 + t2_uv * bary_2;

    float plane_off = dot(normal_frag, global_pos);
    float dist = (dot(normal_frag, player_pos) - plane_off) - 2;
    vec3 proj_pt = player_pos - dist * normal_frag;

    vec3 diff = global_pos - player_pos;
    vec3 t_diff = intersection - player_pos;
    float a = atan(diff.x / diff.z) * 5;
    vec3 planar_diff = proj_pt - global_pos;
    float uvd = length(planar_diff);
    float d1 = dist + noise(a + time * 50) * 1.0;
    float absd = abs(uvd - d1);
    float noise_border = smoothstep(-0.05, 0.0, absd) - smoothstep(0.15, 0.20, absd);

    if (dist < .25) {
        noise_border = 0;
    }

    vec3 proximity_outline_col = vec3(1.0, 1.0, 1.0) * noise_border;

    vec3 pattern_col = pattern(uv);
    // vec3 pattern_col = vec3(colormap(shade).rgb);

    vec3 trail_col = vec3(0.0, 0, 0);
    vec2 res1 = distanceToSegment(player_pos, player_trail[0], global_pos);
    vec2 res2 = distanceToSegment(player_trail[0], player_trail[1], global_pos);
    vec2 res3 = distanceToSegment(player_trail[1], player_trail[2], global_pos);
    float d = min(res1[0], min(res2[0], res3[0]));
    float t = (d == res1[0] ? res1[1] : (d == res2[0] ? 1.0 + res2[1] : 2.0 + res3[1])) / 3.0;
    d += t * 0.69;
    float line_len = length(player_pos - player_trail[0]) + length(player_trail[1] - player_trail[0]) + length(player_trail[2] - player_trail[1]);
    float freq = 2.0 * line_len;
    float width =  sin(-time * 70.0 + t * TWOPI * freq) * 3.0 + 35.0;
    float border_d = 0.050 * width;
    vec3 intColor = mix(vec3(1.0, .5, 0.25), vec3(0.6, 0.0, 0.15), t);
    if (dot(normal_frag, vec3(0, 1, 0)) < 0.85) {
        trail_col = res1[1] > 0.1 ?  mix(trail_col, intColor, 1.0-smoothstep(border_d - .004,border_d, d) ) : trail_col;
    }

    vec3 impact_col = vec3(0.0);
    float crunch_dist = distance(global_pos, crunch_pt);    
    float k = crunch_dist - (time - crunch_time) * 30;
    float angle = atan(global_pos.z - crunch_pt.z, global_pos.x - crunch_pt.x);
    float w = crunch_dist + 25.7 * floor(angle / TWOPI * 10);
    angle -= (.2*jaggy(w/2) + .17*jaggy(w/1.7) + .13*jaggy(w/1.3)) / pow(crunch_dist, .5) * 20;
    float ripple_border = smoothstep(0, 6, k) - smoothstep(6, 12, k);
    angle = mod(angle, TWOPI / 10);
    if (0 <= angle && angle <= 2 / pow(crunch_dist, 1)) {
        impact_col = vec3(1.0, 0.0, 0.5) * ripple_border;
    }

    vec3 col = pattern_col + proximity_outline_col + trail_col + impact_col;

    float mask = texture(ditherTexture, (screen_uv + player_pos.xz * vec2(1, -0.5) / 200.0) * (SAMPLE_RES / 64.0)).r;
    mask = reshapeUniformToTriangle(mask);
    mask = min(1.0, max(floor(mask + length(t_diff) / 8.0) / 5.0, 0.15)); 
    vec4 glassColor = mix(vec4(0.025, 0.025, 0.05, 0.40), vec4(1.00, 1.0, 1.0, 0.60), displacement);
    fragColor = mix(vec4(col, 1.0), glassColor, mask);
    fragColor *= dot(normal_frag, normalize(vec3(0, 1, 1))) / 4.0 + .75;
}

