import { voronoi2d } from "@vgpu/wgsl-std/noise";
import { fbmSimplex2d, simplex3d } from "@vgpu/wgsl-std/noise/simplex";
import { remap, saturate } from "@vgpu/wgsl-std/math";

struct Params {
  time: f32,
  aspect: f32,
  strength: f32,
  _pad: f32,
  texel: vec2f,
  pointer: vec2f,
}

@group(0) @binding(0) var<uniform> params: Params;

const ACCENT = vec3f(0.847, 1.0, 0.243);
const INK = vec3f(0.961, 0.961, 0.949);
const MUTED = vec3f(0.608, 0.608, 0.588);
const BG = vec3f(0.027);

fn sdCircle(p: vec2f, r: f32) -> f32 {
  return length(p) - r;
}

fn sdRing(p: vec2f, r: f32, w: f32) -> f32 {
  return abs(length(p) - r) - w;
}

fn glow(d: f32, k: f32) -> f32 {
  return saturate(k / (k + d * d));
}

fn nodePos(index: f32, t: f32) -> vec2f {
  let a = t * 0.11 + index * 2.09439510239;
  return vec2f(cos(a) * 0.46, sin(a) * 0.30);
}

@fragment fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let t = params.time;
  let p = vec2f((uv.x - 0.64) * params.aspect, 0.48 - uv.y) * 2.0;
  let pointer = vec2f((params.pointer.x - 0.64) * params.aspect, 0.48 - params.pointer.y) * 2.0;

  let warp = vec2f(
    fbmSimplex2d(p * 1.05 + vec2f(t * 0.03, 0.0), 3, 2.17, 0.5),
    fbmSimplex2d(p * 1.05 + vec2f(19.4, 7.1) - vec2f(0.0, t * 0.025), 3, 2.17, 0.5),
  );
  let fieldP = p + warp * 0.07;
  let cells = voronoi2d(fieldP * 4.2 + vec2f(t * 0.04, 0.0));
  let edges = saturate((cells.f2 - cells.f1) * 11.0);
  let coreDist = length(p);
  let fragment = edges * saturate(remap(0.48, 1.25, 0.0, 1.0, coreDist));

  let planet = sdCircle(p, 0.24);
  let planetMask = saturate(-planet * 40.0);
  let rim = saturate(1.0 - abs(planet) / 0.012);
  let nrm = normalize(p + vec2f(0.0001, 0.0001));
  let shade = saturate(0.12 + 0.9 * dot(nrm, normalize(vec2f(-0.55, 0.68))));
  let core = glow(length(p), 0.0014);

  let ringA = saturate(1.0 - abs(length(p / vec2f(0.56, 0.18)) - 1.0) / 0.016);
  let ringB = saturate(1.0 - abs(length(p / vec2f(0.78, 0.26)) - 1.0) / 0.012);
  let ringC = saturate(1.0 - abs(sdRing(p, 0.36, 0.0)) / 0.01);
  let hideBack = saturate(remap(-0.04, 0.14, 1.0, 0.12, p.y));

  var nodes = 0.0;
  var nodeAccent = 0.0;
  for (var i = 0; i < 3; i++) {
    let np = nodePos(f32(i), t);
    let local = p - np;
    nodes += saturate(1.0 - abs(sdCircle(local, 0.022)) / 0.008);
    nodeAccent += glow(length(local), 0.00055);
    let spoke = abs(p.x * np.y - p.y * np.x) / max(length(np), 0.001);
    let along = saturate(dot(p, np) / max(dot(np, np), 0.001));
    nodes += saturate(1.0 - spoke / 0.006) * along * 0.18;
  }

  let intent = glow(length(p - pointer), 0.004) * params.strength;
  let toCore = abs(p.x * pointer.y - p.y * pointer.x) / max(length(pointer), 0.14);
  let alongIntent = saturate(dot(p, pointer) / max(dot(pointer, pointer), 0.001));
  let flow = saturate(1.0 - toCore / 0.01) * alongIntent * params.strength * 0.28;

  let fog = saturate(remap(-0.25, 0.5, 0.0, 1.0, simplex3d(vec3f(p * 1.4, t * 0.07))));
  let grain = simplex3d(vec3f(uv * 420.0, t * 0.5)) * 0.016;

  var col = BG;
  col += MUTED * fragment * (0.09 + 0.12 * fog);
  col += vec3f(0.08, 0.08, 0.075) * planetMask * shade;
  col += INK * rim * 0.7;
  col += ACCENT * core * 0.7;
  col += INK * ringA * hideBack * 0.85;
  col += INK * ringB * 0.38;
  col += ACCENT * ringC * hideBack * 0.22;
  col += INK * nodes * 0.9;
  col += ACCENT * nodeAccent * 1.25;
  col += ACCENT * intent * 0.75;
  col += ACCENT * flow * 0.32;

  let vignette = saturate(1.1 - length(p * vec2f(0.62, 0.82)) * 0.42);
  col *= vignette;
  col += grain;
  col = mix(col, ACCENT * 0.06, intent * 0.1);

  return vec4f(col, 1.0);
}
