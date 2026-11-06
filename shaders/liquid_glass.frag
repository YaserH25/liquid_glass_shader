#version 460 core

// Liquid glass, applied to what lies behind a rounded shape (a pill).
//
// Deep inside, the backdrop shows through clearly (saturated, lightly
// frosted, optionally magnified). Toward the rim the glass curves away, so
// the view bends inward: content near the edge is drawn out, each colour
// channel a little differently (dispersion), and light catches the top of
// the rim.
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

// The backdrop at px under a Gaussian frost of uFrost: sixteen taps of
// equal weight. Their distances from px are the Gaussian's own quantiles
// and each turns by the golden angle from the one before, so no two taps
// line up in any direction; the set has exactly the Gaussian's spread
// (unit covariance, before scaling by uFrost). The backdrop is sampled at
// the nearest texel, so taps that lined up would show an edge behind the
// glass as steps.
vec3 frosted(vec2 px) {
  if (uFrost <= 0.0) {
    return backdrop(px);
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
  return sum * (1.0 / 16.0);
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
    fragColor = vec4(clamp(withSaturation(frosted(base)), 0.0, 1.0), 1.0);
    return;
  }

  vec2 normal = roundedRectNormal(p, halfSize, r);

  // A dome profile, steepest at the edge.
  float slope = 1.0 - sqrt(1.0 - rim * rim);
  vec2 bend = -normal * uBend * slope;

  vec3 color = frosted(base + bend);

  // Colours split only close to the rim; the middle stays true and pays
  // for no extra samples.
  float split = uDispersion * smoothstep(0.6, 1.0, rim);
  if (split > 0.001) {
    color.r = frosted(base + bend * (1.0 + split)).r;
    color.b = frosted(base + bend * (1.0 - split)).b;
  }

  color = withSaturation(color);

  // Light from above catches only the top of the rim, as a thin line.
  float facing = max(-normal.y, 0.0);
  float facing2 = facing * facing;
  float highlight = facing2 * facing2 * smoothstep(0.8, 1.0, rim);
  color += uSpecular * highlight;

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
