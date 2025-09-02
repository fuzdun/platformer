#version 460 core

in vec2 uv;
in float transparency;

out vec4 fragColor;

void main()
{
	   fragColor = vec4(0.0, 0.0, 0.5, transparency);
}

