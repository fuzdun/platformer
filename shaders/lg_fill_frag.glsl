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

in vec3 v0;
in vec3 v1;
in float d00;
in float d01;
in float d11;
in float denom;

uniform vec3 camera_pos;
uniform vec3[3] player_trail;
uniform vec3 crunch_pt;
uniform float crunch_time;
uniform mat4 inverse_projection;
uniform mat4 inverse_view;
uniform float slide_t;

uniform sampler2D ditherTexture;

#define TWOPI 6.2831853
#define SHADES 3.0
#define SLIDE_RADIUS 15.0

vec2 distanceToSegment( vec3 a, vec3 b, vec3 p )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), .00, 1.00 );
	return vec2(length( pa - ba*h ), h);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
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

const vec3 sundir = vec3(-0.7071,0.0,-0.7071);

float rand(vec3 p) 
{
    return fract(sin(dot(p, vec3(12.345, 67.89, 412.12))) * 42123.45) * 2.0 - 1.0;
}

float noise(vec3 p) 
{
    vec3 u = floor(p);
    vec3 v = fract(p);
    vec3 s = smoothstep(0.0, 1.0, v);
    
    float a = rand(u);
    float b = rand(u + vec3(1.0, 0.0, 0.0));
    float c = rand(u + vec3(0.0, 1.0, 0.0));
    float d = rand(u + vec3(1.0, 1.0, 0.0));
    float e = rand(u + vec3(0.0, 0.0, 1.0));
    float f = rand(u + vec3(1.0, 0.0, 1.0));
    float g = rand(u + vec3(0.0, 1.0, 1.0));
    float h = rand(u + vec3(1.0, 1.0, 1.0));
    
    return mix(mix(mix(a, b, s.x), mix(c, d, s.x), s.y),
               mix(mix(e, f, s.x), mix(g, h, s.x), s.y),
               s.z);
}

float map(in vec3 p)
{    
    vec3 q = (p - vec3(0.1,0.2,0.1)* i_time / 200) * 2.0;    
    float f = 0.0;
    f += 0.2000*noise( q );
    q *= 1.5;    
    f += 0.0900*noise( q );
    q *= 2.1;   
    f += 0.03250*noise( q );    
    return clamp( f - p.y + 0.6, 0.0,1.0 );
}

vec4 raymarch( in vec2 uv)
{    
    vec4 sum = vec4(0.0);    
    float t = 0.01;
    for(int i =0; i < 8; i++) {
        vec3 pos = vec3(uv.x, 0.0, uv.y);
        pos.y += t;
        if (sum.a > 0.99)
            break;
        float den = map(pos);
        if(den > 0.01) {
            float dif = clamp((den - map(pos+0.2 * sundir)) * 1.0, 0.0, 1.0);
            vec3  lin = vec3(0.2,0.8,1.5)*dif+vec3(0.5,.6  ,0.7);
            vec4  col = vec4( mix( vec3(0.2,0.3,0.5), vec3(0.2,1.2 ,1.6), den ), den );
            col.xyz *= lin;
            col.rgb *= col.a;
            sum += col*(1.0-sum.a);
        }
        t += max(0.05,0.05*t);
    }    
    return clamp( sum, 0.0, 1.0 );
}

vec4 render( in vec2 uv)
{
    vec4 res = raymarch(uv);    
    vec3 col = (1.0 - res.a) + res.xyz;        
    return vec4( col, 1.0 );
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

#define SAMPLE_RES 240.0

void main()
{
    vec4 glassColor = mix(vec4(0.05, 0.05, 0.075, 0.40), vec4(1.00, 1.0, 1.0, 0.60), displacement);
    // if (displacement > 0.00) {
    //     fragColor = glassColor;
    //     return;
    // }

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

    vec3 v2 = intersection - t0_pos;
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float bary_1 = (d11 * d20 - d01 * d21) / denom;
    float bary_2 = (d00 * d21 - d01 * d20) / denom;
    float bary_0 = 1.0 - bary_1 - bary_2;
    vec2 uv = t0_uv * bary_0 + t1_uv * bary_1 + t2_uv * bary_2;

    float plane_off = dot(normal_frag, global_pos);
    float dist = (dot(normal_frag, player_pos) - plane_off) - 1.5;
    vec3 proj_pt = player_pos - dist * normal_frag;

    vec3 diff = global_pos - player_pos;
    vec3 t_diff = intersection - player_pos;
    vec3 planar_diff = proj_pt - global_pos;
    vec3 up = normal_frag.y == 1.0 ? vec3(1, 0, 0) : vec3(1.0, 0, 0);
    vec3 plane_x = normalize(cross(up, normal_frag));
    vec3 plane_y = normalize(cross(normal_frag, plane_x));
    float uvx = dot(plane_x, planar_diff);
    float uvy = dot(plane_y, planar_diff);
    float a = atan(uvx / uvy) * 25;
    float uvd = length(planar_diff);
    float slide_ring_size = (1.0 - (abs(slide_t - 0.5) / 0.5)) * SLIDE_RADIUS;
    float d1 = dist + slide_ring_size + noise(vec2(a + time * 20, time * 10)) * 1.5;
    float absd = abs(uvd - d1);
    float noise_border = smoothstep(-0.05, 0.0, absd) - smoothstep(0.15, 0.20, absd);
    // if (dist < .25) {
    //     noise_border = 0;
    // }
    vec3 proximity_outline_col = vec3(1.0, 1.0, 1.0) * noise_border;

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
    float k = crunch_dist - (time - crunch_time) * 20;
    float angle = atan(global_pos.z - crunch_pt.z, global_pos.x - crunch_pt.x);
    float w = crunch_dist + 25.7 * floor(angle / TWOPI * 10);
    angle -= (.2*jaggy(w/2) + .17*jaggy(w/1.7) + .13*jaggy(w/1.3)) / pow(crunch_dist, .5) * 20;
    float ripple_border = smoothstep(0, 6, k) - smoothstep(6, 12, k);
    angle = mod(angle, TWOPI / 10);
    if (0 <= angle && angle <= 2 / pow(crunch_dist, 1)) {
        impact_col = vec3(1.0, 0.0, 0.5) * ripple_border;
    }

    // vec3 pattern_col = render(uv * 4.0 - 2.0).xyz;
    // vec3 pattern_col = vec3(0, 0.8, 1.0);
    vec3 border_col = (smoothstep(0.25, 0.3, length(uv)) - smoothstep(0.3, 0.35, length(uv))) * vec3(1, 0, 0);

    // vec3 col = pattern_col + proximity_outline_col + trail_col + impact_col;
    vec3 col = vec3(bary_0, bary_1, bary_2);

    float mask = texture(ditherTexture, (screen_uv + player_pos.xz * vec2(1, -0.5) / 200.0) * (SAMPLE_RES / 64.0)).r;
    mask = reshapeUniformToTriangle(mask);
    mask = min(1.0, max(floor(mask + length(t_diff) / 8.0) / 4.0, 0.15)); 
    fragColor = mix(vec4(col, 1.0), glassColor, mask);
    fragColor *= dot(normal_frag, normalize(vec3(0, 1, 1))) / 2.0 + 0.75;
    fragColor = vec4(col, 1.0);
}
