#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;

out vec4 fragColor;

vec3 rainbowPalette(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.00, 0.18, 0.36);
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= u_resolution.x / u_resolution.y;

    float time = u_time * 0.24;

    float radial = length(p);
    float angle = atan(p.y, p.x);

    float waveA = sin(p.x * 3.6 + time * 2.1);
    float waveB = sin(p.y * 4.4 - time * 1.7);
    float swirl = sin((radial * 8.0 - angle * 3.0) - time * 2.4);
    float ribbon = sin((p.x + p.y) * 5.2 + time * 1.5);

    float energy = 0.0;
    energy += waveA * 0.30;
    energy += waveB * 0.24;
    energy += swirl * 0.28;
    energy += ribbon * 0.18;
    energy = energy * 0.5 + 0.5;

    float paletteIndex = fract(energy + radial * 0.16 - time * 0.06);
    vec3 spectral = rainbowPalette(paletteIndex);

    float centerGlow = exp(-radial * 2.8);
    float edgeFade = smoothstep(1.55, 0.18, radial);
    float ribbonMask = smoothstep(0.10, 0.92, energy);

    vec3 finalColor = spectral * ribbonMask * 0.46;
    finalColor += spectral * centerGlow * 0.20;
    finalColor *= edgeFade;

    fragColor = vec4(finalColor, 1.0);
}
