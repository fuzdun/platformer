#version 460 core

in vec2 uv;
in float time;

uniform vec3 p_outline_color;

out vec4 fragColor;

void main() {
    vec3 color = p_outline_color;
    fragColor = vec4(color, 1.0);
}
