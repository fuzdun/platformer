#version 460 core

in vec2 uv;
in float time;

uniform vec3 p_color;

out vec4 fragColor;

void main() {
    vec3 color = {0.2, 0, 0.2};
    fragColor = vec4(color, 1.0);
}
