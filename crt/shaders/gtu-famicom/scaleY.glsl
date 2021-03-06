////////////////////////////////////////////////////////
//  GTU-famicom version 0.50
//  Author: aliaspider - aliaspider@gmail.com
//  License: GPLv3
////////////////////////////////////////////////////////

// Parameter lines go here:
#pragma parameter noScanlines "No Scanlines" 0.0 0.0 1.0 1.0
#pragma parameter tvVerticalResolution "TV Vert. Res" 250.0 20.0 1000.0 10.0
#pragma parameter blackLevel "Black Level" 0.07 -0.30 0.30 0.01
#pragma parameter contrast "Contrast" 1.0 0.0 2.0 0.1
#pragma parameter gamma "Gamma" 1.0 0.5 1.5 0.01
#pragma parameter cropOverscan_y "Crop Overscan Y" 0.0 0.0 1.0 1.0

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;

uniform mat4 MVPMatrix;
uniform int FrameDirection;
uniform int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// vertex compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define outsize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float cropOverscan_y;
#else
#define cropOverscan_y 0.0
#endif

void main()
{
    if (cropOverscan_y > 0.0)
        gl_Position.y /= (224.0 / 240.0);
    gl_Position = MVPMatrix * VertexCoord;
    COL0 = COLOR;
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform int FrameDirection;
uniform int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

// fragment compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy
#define texture(c, d) COMPAT_TEXTURE(c, d)
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define outsize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float noScanlines;
uniform COMPAT_PRECISION float tvVerticalResolution;
uniform COMPAT_PRECISION float blackLevel;
uniform COMPAT_PRECISION float contrast;
uniform COMPAT_PRECISION float gamma;
#else
#define noScanlines 0.0
#define tvVerticalResolution 250.0
#define blackLevel 0.07
#define contrast 1.0
#define gamma 1.0
#endif

#define pi          3.14159265358
#define normalGauss(x) ((exp(-(x)*(x)*0.5))/sqrt(2.0*pi))

#define Y(j) (offset.y-(j))
#define a(x) abs(x)
#define d(x,b) (pi*b*min(a(x)+0.5,1.0/b))
#define e(x,b) (pi*b*min(max(a(x)-0.5,-1.0/b),1.0/b))
#define STU(x,b) ((d(x,b)+sin(d(x,b))-e(x,b)-sin(e(x,b)))/(2.0*pi))

#define SOURCE(j) vec2(vTexCoord.x,vTexCoord.y - Y(j) * SourceSize.w)
#define C(j) (texture(Source, SOURCE(j)).xyz)

#define VAL(j) (C(j)*STU(Y(j),(tvVerticalResolution / InputSize.y)))
#define VAL_scanlines(j) (scanlines(Y(j),C(j)))

float normalGaussIntegral(float x)
{
    float a1 = 0.4361836;
    float a2 = -0.1201676;
    float a3 = 0.9372980;
    float p = 0.3326700;
    float t = 1.0 / (1.0 + p*abs(x));
    
    return (0.5-normalGauss(x) * (t*(a1 + t*(a2 + a3*t))))*sign(x);
}

vec3 scanlines( float x , vec3 c){
    float temp = sqrt(2.*pi)*(tvVerticalResolution / InputSize.y);

    float rrr = 0.5 * (InputSize.y * outsize.w);
    float x1 = (x + rrr)*temp;
    float x2 = (x - rrr)*temp;
    c.r = c.r*(normalGaussIntegral(x1) - normalGaussIntegral(x2));
    c.g = c.g*(normalGaussIntegral(x1) - normalGaussIntegral(x2));
    c.b = c.b*(normalGaussIntegral(x1) - normalGaussIntegral(x2));
    c *= OutputSize.y / InputSize.y;

    return c;
}

void main()
{
    vec2 offset = fract((vTexCoord.xy * SourceSize.xy) - 0.5);
    vec3 tempColor = vec3(0.0);
    
    float range = ceil(0.5 + SourceSize.y / tvVerticalResolution);
    range = min(range, 255.0);
    
    float i;
//  for (i=-range;i<range+2.0;i++){

    if (noScanlines > 0.0)
        for (i = 1.0-range; i < range + 1.0; ++i)
            tempColor += VAL(i);
    else
        for (i = 1.0 - range; i < range + 1.0; ++i)
            tempColor += VAL_scanlines(i);

    tempColor -= vec3(blackLevel);
    tempColor *= (contrast / vec3(1.0 - blackLevel));
    tempColor = pow(tempColor, vec3(gamma));
    
    FragColor = vec4(tempColor, 1.0);
} 
#endif
