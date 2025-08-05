#version 460 core

in vec2 uv;
in vec3 obj_pos;
in float dist_fact;

out vec4 fragColor;

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

void main()
{
    float dist = length(obj_pos - player_pos);
    // float dist_fact = 1;
    // float dist_fact = clamp(1 - dist / 2000, 0, 1);
    float v_border = .01;
    float h_border = .01;
    float x_border_fact = smoothstep(1.0 - h_border, 1.0, uv.x) +
        1.0 - smoothstep(0.0, h_border, uv.x);
    float y_border_fact = smoothstep(1.0 - v_border, 1.0, uv.y) +
        1.0 - smoothstep(0.0, v_border, uv.y);
    float border_fact = max(x_border_fact, y_border_fact);
    // if (cracked != 0) {
    //     border_fact = 0;
    // }
    fragColor = mix(vec4(0.0), vec4(0.75, 0.75, 0.75, 1.0), border_fact - dist_fact);
    // fragColor = vec4(1.0);
    // fragColor = vec4(crack_time, 0, 0, 1.0);
    if (fragColor.a < .85) {
        discard;
    }
}

