#version 460 core

in vec2 uv;
out vec4 fragColor;

void main()
{
	   float v_border = .02;
	   float h_border = .02;

	   float x_border_fact = smoothstep(1.0 - h_border, 1.0, uv.x) +
	                         1.0 - smoothstep(0.0, h_border, uv.x);
	   float y_border_fact = smoothstep(1.0 - v_border, 1.0, uv.y) +
	                         1.0 - smoothstep(0.0, v_border, uv.y);
	   float border_fact = max(x_border_fact, y_border_fact);
	   vec3 border_col = border_fact * vec3(1.0, 0.8, 1.0);
	   vec3 col = vec3(0.0, 0.0, 1.0) + border_col;
	   fragColor = vec4(col, 1.0);
}


