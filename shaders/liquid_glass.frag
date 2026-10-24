#version 460 core

// Liquid glass, applied to what lies behind a rounded shape (a pill).
//
// Deep inside, the backdrop shows through clearly (saturated, optionally
// magnified; any frost is a blur applied before this shader). Toward the rim the glass curves away,
// so the view bends inward: content near the edge is drawn out, each colour
// channel a little differently (dispersion), and light catches the top of
// the rim.
//
// Only pixels inside the glass sample the backdrop; the rest return at once,
// so the cost stays with the glass's own area on every GPU. Inside, pixels
// farther than the rim band from the edge are flat glass: no bend, colour
// split or highlight, so they skip all of that work.
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
    fragColor = vec4(clamp(withSaturation(backdrop(base)), 0.0, 1.0), 1.0);
    return;
  }

  vec2 normal = roundedRectNormal(p, halfSize, r);

  // A dome profile, steepest at the edge.
  float slope = 1.0 - sqrt(1.0 - rim * rim);
  vec2 bend = -normal * uBend * slope;

  vec3 color = backdrop(base + bend);

  // Colours split only close to the rim; the middle stays true and pays
  // for no extra samples.
  float split = uDispersion * smoothstep(0.6, 1.0, rim);
  if (split > 0.001) {
    color.r = backdrop(base + bend * (1.0 + split)).r;
    color.b = backdrop(base + bend * (1.0 - split)).b;
  }

  color = withSaturation(color);

  // Light from above catches only the top of the rim, as a thin line.
  float facing = max(-normal.y, 0.0);
  float facing2 = facing * facing;
  float highlight = facing2 * facing2 * smoothstep(0.8, 1.0, rim);
  color += uSpecular * highlight;

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
