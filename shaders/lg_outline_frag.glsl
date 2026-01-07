#version 460 core

uniform vec3 color;

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
    float v_border = .02;
    float h_border = .02;
    float x_border_fact = smoothstep(1.0 - h_border, 1.0, uv.x) +
        1.0 - smoothstep(0.0, h_border, uv.x);
    float y_border_fact = smoothstep(1.0 - v_border, 1.0, uv.y) +
        1.0 - smoothstep(0.0, v_border, uv.y);
    float border_fact = max(x_border_fact, y_border_fact);
    fragColor = mix(vec4(0.0), vec4(color, 1.0), border_fact - dist_fact);
    if (fragColor.a < .85) {
        discard;
    }
}

