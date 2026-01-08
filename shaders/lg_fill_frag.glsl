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
in vec2 t0_uv;
in vec2 t1_uv;
in vec2 t2_uv;

in vec3 b_poss[3];

in vec3 v0;
in vec3 v1;
in float d00;
in float d01;
in float d11;
in float denom;

in float did_shatter;

uniform vec3 camera_pos;
uniform vec3[3] player_trail;
uniform vec3 crunch_pt;
uniform float crunch_time;
uniform mat4 inverse_projection;
uniform mat4 inverse_view;
uniform float slide_t;

uniform sampler2D ditherTexture;

#define TWOPI 6.2831853
#define SLIDE_RADIUS 15.0
// #define SAMPLE_RES 320 
#define SAMPLE_RES 100 
#define LINE_W 0.2

vec2 distanceToSegment( vec3 a, vec3 b, vec3 p )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), .00, 1.00 );
	return vec2(length( pa - ba*h ), h);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec3 hash3(vec3 p){
	p = vec3( dot(p,vec3(127.1,311.7, 74.7)),
			  dot(p,vec3(269.5,183.3,246.1)),
			  dot(p,vec3(113.5,271.9,124.6)));
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i + vec2(0.0, 0.0)), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x),
               u.y);
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

vec4 noised(vec3 x){
    vec3 p = floor(x);
    vec3 w = fract(x);
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);
    
    vec3 ga = hash3( p+vec3(0.0,0.0,0.0) );
    vec3 gb = hash3( p+vec3(1.0,0.0,0.0) );
    vec3 gc = hash3( p+vec3(0.0,1.0,0.0) );
    vec3 gd = hash3( p+vec3(1.0,1.0,0.0) );
    vec3 ge = hash3( p+vec3(0.0,0.0,1.0) );
	vec3 gf = hash3( p+vec3(1.0,0.0,1.0) );
    vec3 gg = hash3( p+vec3(0.0,1.0,1.0) );
    vec3 gh = hash3( p+vec3(1.0,1.0,1.0) );
    
    float va = dot( ga, w-vec3(0.0,0.0,0.0) );
    float vb = dot( gb, w-vec3(1.0,0.0,0.0) );
    float vc = dot( gc, w-vec3(0.0,1.0,0.0) );
    float vd = dot( gd, w-vec3(1.0,1.0,0.0) );
    float ve = dot( ge, w-vec3(0.0,0.0,1.0) );
    float vf = dot( gf, w-vec3(1.0,0.0,1.0) );
    float vg = dot( gg, w-vec3(0.0,1.0,1.0) );
    float vh = dot( gh, w-vec3(1.0,1.0,1.0) );
	
    return vec4( va + u.x*(vb-va) + u.y*(vc-va) + u.z*(ve-va) + u.x*u.y*(va-vb-vc+vd) + u.y*u.z*(va-vc-ve+vg) + u.z*u.x*(va-vb-ve+vf) + (-va+vb+vc-vd+ve-vf-vg+vh)*u.x*u.y*u.z,    // value
                 ga + u.x*(gb-ga) + u.y*(gc-ga) + u.z*(ge-ga) + u.x*u.y*(ga-gb-gc+gd) + u.y*u.z*(ga-gc-ge+gg) + u.z*u.x*(ga-gb-ge+gf) + (-ga+gb+gc-gd+ge-gf-gg+gh)*u.x*u.y*u.z +   // derivatives
                 du * (vec3(vb,vc,ve) - va + u.yzx*vec3(va-vb-vc+vd,va-vc-ve+vg,va-vb-ve+vf) + u.zxy*vec3(va-vb-ve+vf,va-vb-vc+vd,va-vc-ve+vg) + u.yzx*u.zxy*(-va+vb+vc-vd+ve-vf-vg+vh) ));
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

#define RING_COUNT 12.0
#define RING_SIZE 3.0
#define RING_PHASE_OFFSET 0.6
#define RING_WAVE_SIZE 2.5
float ditherRingNum(float distVal, float mask) {
    float time = i_time / 200.0;
    for (int i = 0; i < RING_COUNT; i++) {
        float ringTargetDist = i * RING_SIZE + mask * 3.5 + sin(time + RING_PHASE_OFFSET * i) * RING_WAVE_SIZE; 
        if (distVal < ringTargetDist) {
            return i / RING_COUNT;
        }
    }
    return RING_COUNT;
}

void main()
{
    vec4 glassColor = mix(vec4(0.05, 0.05, 0.10, 0.50), vec4(0.30, 0.3, 1.0, 1.00), displacement);

    // if geometry not fully assembled, use "glass" color
    if (displacement > 0.00) {
        fragColor = glassColor;
        return;
    }

    float time = i_time / 1000.0;

    // get floored uv
    float screen_width = 1920.0;
    float screen_height = 1080.0;
    vec2 screen_uv = gl_FragCoord.xy;
    screen_uv.x /= screen_width;
    screen_uv.y /= screen_width;
    screen_uv = floor(screen_uv * SAMPLE_RES) / SAMPLE_RES;

    // get normalized device coordinates
    vec2 rounded_frag = screen_uv * screen_width;
    vec3 ndc = vec3(
        (rounded_frag.x / screen_width - 0.5) * 2.0,
        (rounded_frag.y / screen_height - 0.5) * 2.0,
        1.0
    );

    // get reprojection ray
    vec4 ray_clip = vec4(ndc.xy, -1.0, 1.0);
    vec4 ray_eye = inverse_projection * ray_clip;
    vec3 ray_wor = normalize((inverse_view * vec4(ray_eye.xy, -1.0, 0.0)).xyz);

    // intersect ray with triangle plane
    vec3 intersection = (plane_dist + dot(-camera_pos, normal_frag)) / dot(-normal_frag, ray_wor) * ray_wor - camera_pos;
    intersection *= -1;

    // get uv of reprojected fragment using barycentric coordinates
    vec3 v2 = intersection - t0_pos;
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float bary_1 = (d11 * d20 - d01 * d21) / denom;
    float bary_2 = (d00 * d21 - d01 * d20) / denom;
    float bary_0 = 1.0 - bary_1 - bary_2;
    vec2 uv = t0_uv * bary_0 + t1_uv * bary_1 + t2_uv * bary_2;

    // get indicator ring color
    vec3 up = normal_frag.y == 1.0 ? vec3(1, 0, 0) : vec3(1.0, 0, 0);
    float plane_player_dist = (dot(normal_frag, player_pos) - dot(normal_frag, global_pos)) - 1.5;
    vec3 proj_player_pos = player_pos - plane_player_dist * normal_frag;
    vec3 proj_player_diff = proj_player_pos - global_pos;
    vec3 plane_x = normalize(cross(up, normal_frag));
    vec3 plane_y = normalize(cross(normal_frag, plane_x));
    float ring_uvx = dot(plane_x, proj_player_diff);
    float ring_uvy = dot(plane_y, proj_player_diff);
    float ring_a = atan(ring_uvx / ring_uvy);
    float uvd = length(proj_player_diff);
    float slide_ring_size = (1.0 - (abs(slide_t - 0.5) / 0.5)) * SLIDE_RADIUS;
    float noise_offset = noise(vec2(ring_a * 25 + time * 20, time * 10)) * 1.5;
    float ring_factor = abs(uvd - (plane_player_dist + slide_ring_size + noise_offset));
    float noise_border = smoothstep(-0.03, 0.0, ring_factor) - smoothstep(0.30, 0.33, ring_factor);

    vec3 trail_col = vec3(0.0, 0, 0);
    vec2 seg_1_dist = distanceToSegment(player_pos, player_trail[0], global_pos);
    vec2 seg_2_dist = distanceToSegment(player_trail[0], player_trail[1], global_pos);
    vec2 seg_3_dist = distanceToSegment(player_trail[1], player_trail[2], global_pos);
    float smallest_seg_dist = min(seg_1_dist[0], min(seg_2_dist[0], seg_3_dist[0]));
    float trail_t = 0;
    if (smallest_seg_dist == seg_1_dist[0]) {
        trail_t = seg_1_dist[1];
    } else if (smallest_seg_dist == seg_2_dist[0]) {
        trail_t = 1.0 + seg_2_dist[1];
    } else {
        trail_t = 2.0 + seg_3_dist[1];
    }
    trail_t /= 3.0;
    smallest_seg_dist += trail_t * 0.69;
    float line_len = length(player_pos - player_trail[0]) + length(player_trail[1] - player_trail[0]) + length(player_trail[2] - player_trail[1]);
    float freq = 0.5 * line_len;
    float width =  sin(-time * 70.0 + trail_t * TWOPI * freq) * 3.0 + 35.0;
    float border_d = 0.050 * width;
    vec3 intColor = mix(vec3(1.0, .5, 0.25), vec3(0.6, 0.0, 0.15), trail_t);
    if (dot(normal_frag, vec3(0, 1, 0)) < 0.85) {
        trail_col = seg_1_dist[1] > 0.1 ?  mix(trail_col, intColor, 1.0 - smoothstep(border_d - .004,border_d, smallest_seg_dist) ) : trail_col;
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

    vec4 grad_noise_val = noised(vec3(uv.xy * 2.0 + i_time / 1000, 0));
    vec3 grad_normal = normalize(grad_noise_val.yzw);
    float lighting_amt = dot(vec3(0, -1, 0), grad_normal);
    float lighting2_amt = dot(normalize(vec3(1, 1, 1)), grad_normal);
    vec3 pattern_col =  (lighting_amt * 0.3 + 0.7) * vec3(0.0, 0.7, 1.0) + (lighting2_amt * 0.3 + 0.7) * vec3(0.25, 0.0, 0.45);
    // vec3 pattern_col = vec3(0, 0, 1);

    float sd = (udTriangle(b_poss[0], b_poss[1], b_poss[2], global_pos));
    float border_t = did_shatter == 1.0 ? smoothstep(0.0, LINE_W, sd) : 1.0;

    vec3 col = pattern_col + trail_col + impact_col;

    // BLUE NOISE
    float mask = texture(ditherTexture, (screen_uv + player_pos.xz * vec2(1, -0.5) / 300.0) * (SAMPLE_RES / 64.0)).r;
    mask = reshapeUniformToTriangle(mask);
    
    // float ring_num = floor(mask + length(intersection - player_pos) / RING_SIZE) / RING_COUNT;
    float ring_num = ditherRingNum(length(intersection - player_pos), mask);
    mask = min(1.0, max(ring_num, 0.20)); 

    fragColor = mix(vec4(col, 1.0), glassColor, mask);
    fragColor = mix(fragColor, vec4(1.0, 1.0, 1.0, 1.0), noise_border);

    fragColor = mix(vec4(1.0, 1.0, 1.0, 1.0), fragColor, border_t);
    fragColor *= dot(normal_frag, normalize(vec3(1, 1, 1))) / 2.0 + 1.0;
}
