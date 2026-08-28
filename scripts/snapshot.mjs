import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PNG } from "pngjs";
import { resolveShader } from "@vgpu/wgsl/runtime";
import { effect, init, target } from "vgpu/node";

const root = dirname(fileURLToPath(import.meta.url));
const resolved = await resolveShader({
  entry: join(root, "../src/layer.wgsl"),
});

const width = 1280;
const height = 720;
const gpu = await init({ adapter: "software" });

try {
  const colorTarget = target(gpu, { size: [width, height] });
  const shader = effect(gpu, resolved.wgsl, {
    label: "mstrmnd-layer-snapshot",
    set: {
      params: {
        time: 8.4,
        aspect: width / height,
        strength: 0.35,
        _pad: 0,
        texel: [1 / width, 1 / height],
        pointer: [0.48, 0.5],
      },
    },
  });

  shader.draw(colorTarget);
  const pixels = await colorTarget.read();
  const png = new PNG({ width, height });
  png.data.set(pixels);
  const outDir = join(root, "../public/preview");
  mkdirSync(outDir, { recursive: true });
  const outPath = join(outDir, "layer.png");
  writeFileSync(outPath, PNG.sync.write(png));
  console.log(`wrote ${outPath}`);
} finally {
  await gpu.settled();
  gpu.dispose();
}
