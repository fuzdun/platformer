#version 450 core

in vec2 uv;
in float time;

out vec4 fragColor;

#define pi     3.14159265

float generator(vec2 uv,float x)
{
    return log(mod((min(length(uv.x),length(uv.y)))*x+length(uv)*(1.-x)-time*0.2,0.2)/0.2)/log(0.2);
}

void main()
{
    
    float a=1.5;
    int n=15;
    vec2 uv2=fract(uv)-0.5;
    float x=(sin(1.*time+sin(floor(uv.x)*0.15+time*2.)+sin(floor(uv.y)*0.15+time*1.)+1.)/2.);
    uv2=vec2(
    
        cos(x*pi*a)*uv2.x - sin(x*pi*a)*uv2.y, 
        sin(x*pi*a)*uv2.x + cos(x*pi*a)*uv2.y
    );
    
    
    // Time varying pixel color
    
    vec3 col=vec3(0.1,0.2,0.2)*generator(uv2,x);
    
    // Output to screen
    fragColor = vec4(col,1.0);
}
