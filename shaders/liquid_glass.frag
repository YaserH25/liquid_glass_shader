#version 460 core

// Liquid glass, applied to what lies behind a rounded shape (a pill).
//
// Deep inside, the backdrop shows through clearly (saturated, lightly
// frosted, optionally magnified). Toward the rim the glass curves away, so
// the view bends inward: content near the edge is drawn out, each colour
// channel a little differently (dispersion), and light catches the rim
// along the top and the bottom.
//
// Only pixels inside the glass sample the backdrop; the rest return at once,
// so the cost stays with the glass's own area on every GPU. Inside, pixels
// farther than the rim band from the edge are flat glass: no bend, colour
// split or highlight, so they skip all of that work.
//
// A light frost (uFrost) is taken here, from a few taps around each pixel.
// The engine cannot tell where a shader filter samples, so a blur composed
// in front of it runs over the whole screen at full resolution: for a light
// frost that cost several times the rest of the glass. Heavier frost is the
// engine's blur, which downsamples (uFrost is then 0).
//
// Diffusion (uDiffusion) is the standard glass of iOS 27: part of what shows
// through is the backdrop scattered widely (uSpread), the rest stays sharp,
// so a busy page loses its contrast behind the glass without turning to
// fog. It is taken here too, from thirty-two more reads, so it needs no
// second pass over the screen.
//
// All lengths are in physical pixels of the backdrop texture.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;        // set by the engine: size of the backdrop texture
uniform vec4 uRect;        // the glass: left, top, right, bottom
uniform float uRadius;     // corner radius
uniform float uBand;       // how far in from the rim the glass curves
uniform float uBend;       // displacement at the rim
uniform float uDispersion; // colour split, as a fraction of the bend
uniform float uMagnify;    // magnification of the whole interior (1 = none)
uniform float uSpecular;   // strength of the rim highlight
uniform float uSaturation; // colour saturation (1 = unchanged)
uniform float uFrost;      // blur sigma of the frost taken here (0 = none)
uniform float uDiffusion;  // share of the backdrop scattered widely (0 to 1)
uniform float uSpread;     // blur sigma of that scatter
uniform float uDim;        // share of its light white backdrop loses (0 = none)
uniform sampler2D uTexture;

out vec4 fragColor;

float roundedRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The outward direction of the rounded rectangle's edge nearest to p: the
// gradient of roundedRect, in closed form instead of four more distance
// evaluations.
vec2 roundedRectNormal(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  vec2 g = q.x > 0.0 && q.y > 0.0
      ? normalize(q)
      : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
  return g * sign(p);
}

// The backdrop texture is upright on every backend (Metal, Vulkan and
// OpenGL ES). Don't flip y for OpenGL ES: that misplaced the content on
// Android.
vec3 backdrop(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
  return texture(uTexture, uv).rgb;
}

// Bright backdrop dimmed (uDim): white loses that share of its light, black
// none.
vec3 dimmed(vec3 color) {
  return color * (1.0 - uDim * dot(color, vec3(0.2126, 0.7152, 0.0722)));
}

// The scatter dims each read, and so before averaging: dark glass over a
// page of black and white then settles near the darker of the two, as on
// iOS, instead of on their mean.
vec3 far(vec2 px) {
  return dimmed(backdrop(px));
}

// The backdrop at px under a Gaussian frost of uFrost: sixteen taps of
// equal weight. Their distances from px are the Gaussian's own quantiles
// and each turns by the golden angle from the one before, so no two taps
// line up in any direction; the set has exactly the Gaussian's spread
// (unit covariance, before scaling by uFrost). The backdrop is sampled at
// the nearest texel, so taps that lined up would show an edge behind the
// glass as steps.
vec3 frosted(vec2 px) {
  if (uFrost <= 0.0) {
    return dimmed(backdrop(px));
  }
  vec3 sum = backdrop(px + vec2(0.0645, 0.3323) * uFrost) +
      backdrop(px + vec2(-0.4516, -0.1226) * uFrost) +
      backdrop(px + vec2(0.4507, -0.1298) * uFrost) +
      backdrop(px + vec2(-0.3146, 0.7582) * uFrost) +
      backdrop(px + vec2(-0.3066, -0.7990) * uFrost) +
      backdrop(px + vec2(0.7135, 0.6439) * uFrost) +
      backdrop(px + vec2(-0.9895, 0.2453) * uFrost) +
      backdrop(px + vec2(0.5314, -0.8933) * uFrost) +
      backdrop(px + vec2(0.1351, 1.4381) * uFrost) +
      backdrop(px + vec2(-1.0506, -0.9558) * uFrost) +
      backdrop(px + vec2(1.3278, 0.1174) * uFrost) +
      backdrop(px + vec2(-1.0863, 1.2356) * uFrost) +
      backdrop(px + vec2(-0.0300, -1.8435) * uFrost) +
      backdrop(px + vec2(1.1619, 1.8034) * uFrost) +
      backdrop(px + vec2(-2.1024, -0.4035) * uFrost) +
      backdrop(px + vec2(1.9466, -1.4269) * uFrost);
  // The frost is too narrow for dimming before or after it to differ.
  return dimmed(sum * (1.0 / 16.0));
}

// The backdrop around px scattered by a Gaussian of uSpread: thirty-two
// taps of equal weight, spread as frosted spreads its own, and turned by a
// different angle at each pixel (interleaved gradient noise). So few taps
// so far apart, at the same places for every pixel, show an edge behind the
// glass as a row of ghost edges; turned, neighbouring pixels read different
// places, and the ghosts become a grain too fine to see.
vec3 scattered(vec2 px, vec2 frag) {
  float angle = 6.2831853 *
      fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
  vec2 across = vec2(cos(angle), sin(angle)) * uSpread;
  mat2 turn = mat2(across.x, across.y, -across.y, across.x);
  vec3 sum =
      far(px + turn * vec2(0.1642, 0.0501)) +
      far(px + turn * vec2(-0.2443, 0.2607)) +
      far(px + turn * vec2(0.0211, -0.3542)) +
      far(px + turn * vec2(0.2803, 0.4344)) +
      far(px + turn * vec2(-0.5598, -0.0464)) +
      far(px + turn * vec2(0.5070, -0.2815)) +
      far(px + turn * vec2(-0.1904, 0.7049)) +
      far(px + turn * vec2(-0.3533, -0.6024)) +
      far(px + turn * vec2(0.7283, 0.3213)) +
      far(px + turn * vec2(-0.7949, 0.3723)) +
      far(px + turn * vec2(0.3659, -0.7626)) +
      far(px + turn * vec2(0.2698, 0.9561)) +
      far(px + turn * vec2(-0.8808, -0.4520)) +
      far(px + turn * vec2(1.0143, -0.1760)) +
      far(px + turn * vec2(-0.6501, 0.9544)) +
      far(px + turn * vec2(-0.1632, -1.0983)) +
      far(px + turn * vec2(0.9120, 0.8308)) +
      far(px + turn * vec2(-1.2792, 0.1024)) +
      far(px + turn * vec2(0.9226, -0.8823)) +
      far(px + turn * vec2(-0.0781, 1.4282)) +
      far(px + turn * vec2(-0.9366, -1.0550)) +
      far(px + turn * vec2(1.4742, 0.2504)) +
      far(px + turn * vec2(-1.3015, 0.9457)) +
      far(px + turn * vec2(0.3452, -1.5482)) +
      far(px + turn * vec2(0.8377, 1.5371)) +
      far(px + turn * vec2(-1.7258, -0.4959)) +
      far(px + turn * vec2(1.6997, -0.7418)) +
      far(px + turn * vec2(-0.7837, 1.8885)) +
      far(px + turn * vec2(-0.7308, -1.9416)) +
      far(px + turn * vec2(1.9967, 1.1071)) +
      far(px + turn * vec2(-2.4213, 0.6846)) +
      far(px + turn * vec2(1.5550, -2.3906));
  return sum * (1.0 / 32.0);
}

vec3 withSaturation(vec3 color) {
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  return mix(vec3(luma), color, uSaturation);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 center = (uRect.xy + uRect.zw) * 0.5;
  vec2 halfSize = max((uRect.zw - uRect.xy) * 0.5, vec2(1.0));
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  vec2 p = frag - center;

  float d = roundedRect(p, halfSize, r);
  if (d > 1.0) {
    // Outside the glass; the clip around it discards this anyway.
    fragColor = vec4(0.0);
    return;
  }

  vec2 base = center + p / max(uMagnify, 0.01);

  // 0 deep inside, 1 at the rim.
  float rim = clamp(1.0 + d / max(uBand, 1.0), 0.0, 1.0);
  if (rim <= 0.0) {
    // Flat glass: bend, colour split and highlight are all zero here.
    vec3 inside = frosted(base);
    if (uDiffusion > 0.0) {
      inside = mix(inside, scattered(base, frag), uDiffusion);
    }
    fragColor = vec4(clamp(withSaturation(inside), 0.0, 1.0), 1.0);
    return;
  }

  vec2 normal = roundedRectNormal(p, halfSize, r);

  // Steepest at the edge, and easing off inward as measured on iOS 27,
  // where the very rim shows what lies deep inside the glass, mirrored.
  float slope = rim * rim * sqrt(rim);
  vec2 bend = -normal * uBend * slope;

  vec3 color = frosted(base + bend);

  // Colours split only close to the rim; the middle stays true and pays
  // for no extra samples.
  float split = uDispersion * smoothstep(0.6, 1.0, rim);
  if (split > 0.001) {
    color.r = frosted(base + bend * (1.0 + split)).r;
    color.b = frosted(base + bend * (1.0 - split)).b;
  }

  // The scatter is too wide for the bend or the colour split to show in it.
  if (uDiffusion > 0.0) {
    color = mix(color, scattered(base + bend, frag), uDiffusion);
  }

  color = withSaturation(color);

  // The rim catches the light where it faces up or down, along the top and
  // the bottom and not at the sides: a thin bright line at the very edge,
  // over a fainter glow reaching a few pixels in.
  float facing = abs(normal.y);
  float facing2 = facing * facing;
  float highlight = facing2 * facing2 *
      (0.7 * smoothstep(0.92, 1.0, rim) + 0.3 * smoothstep(0.7, 1.0, rim));
  color += uSpecular * highlight;

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
