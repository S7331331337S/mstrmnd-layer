import { clock, effect, frameLoop, init, surface } from "vgpu";
import type { FrameLoopHandle, Gpu, Surface } from "vgpu";
import layerShader from "./layer.wgsl";

export function startLayer(canvas: HTMLCanvasElement): () => void {
  let disposed = false;
  let loop: FrameLoopHandle | undefined;
  let gpu: Gpu | undefined;
  let canvasSurface: Surface | undefined;

  const pointer = { x: 0.64, y: 0.48, strength: 0.18, targetX: 0.64, targetY: 0.48, targetStrength: 0.18 };
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const onPointer = (event: PointerEvent) => {
    const rect = canvas.getBoundingClientRect();
    pointer.targetX = (event.clientX - rect.left) / Math.max(rect.width, 1);
    pointer.targetY = (event.clientY - rect.top) / Math.max(rect.height, 1);
    pointer.targetStrength = 1;
  };

  const onLeave = () => {
    pointer.targetStrength = 0.18;
  };

  canvas.addEventListener("pointermove", onPointer, { passive: true });
  canvas.addEventListener("pointerdown", onPointer, { passive: true });
  canvas.addEventListener("pointerleave", onLeave);

  void (async () => {
    try {
      gpu = await init();
      if (disposed) {
        gpu.dispose();
        return;
      }

      canvasSurface = surface(gpu, canvas, { dpr: [1, 2] });
      const layer = effect(gpu, layerShader, {
        label: "mstrmnd-layer",
        set: {
          params: {
            time: 0,
            aspect: Math.max(canvas.clientWidth / Math.max(canvas.clientHeight, 1), 0.5),
            strength: pointer.strength,
            _pad: 0,
            texel: canvasSurface.texelSize,
            pointer: [pointer.x, pointer.y],
          },
        },
      });

      const writeSize = () => {
        layer.set({
          params: {
            aspect: Math.max(canvas.clientWidth / Math.max(canvas.clientHeight, 1), 0.5),
            texel: canvasSurface!.texelSize,
          },
        });
      };

      canvasSurface.onResize(writeSize);
      await layer.compile(canvasSurface);

      const time = clock(gpu);
      loop = frameLoop(gpu, (frame) => {
        pointer.x += (pointer.targetX - pointer.x) * 0.12;
        pointer.y += (pointer.targetY - pointer.y) * 0.12;
        pointer.strength += (pointer.targetStrength - pointer.strength) * 0.08;
        layer.set({
          params: {
            time: reduced ? 8 : time.time,
            strength: pointer.strength,
            pointer: [pointer.x, pointer.y],
          },
        });
        frame.pass(canvasSurface!, layer);
      });

      document.documentElement.classList.add("is-live");
    } catch (error) {
      console.error(error);
      document.documentElement.classList.add("is-fallback");
    }
  })();

  return () => {
    disposed = true;
    canvas.removeEventListener("pointermove", onPointer);
    canvas.removeEventListener("pointerdown", onPointer);
    canvas.removeEventListener("pointerleave", onLeave);
    loop?.stop();
    gpu?.dispose();
  };
}
