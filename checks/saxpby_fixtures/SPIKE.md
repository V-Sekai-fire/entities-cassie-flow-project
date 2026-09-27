<!-- SPDX-License-Identifier: MIT -->

# Phase B spike: GPU dispatch + byte-parity on the owned GPU

Proves the emit -> dispatch -> parity loop for the curvenet GPU port (RFD 2265):
a Lean-authored kernel, compiled to SPIR-V, dispatched on a real RenderingDevice,
produces bit-for-bit the same result as the CPU oracle.

- Kernel: `Cloth.SlangCodegen.Saxpby` -> `godot-cassie/modules/cassie/thirdparty/avbd/saxpby.spv`
  (`dst[i] = fma(alpha, x[i], beta * y[i])`, `[numthreads(256,1,1)]`, bindings set 0: params/x/y/dst).
- Oracle: `oracle.c` computes the reference with `fmaf` in float32. GPU `fma` and C `fmaf`
  are both correctly-rounded IEEE fma, so the match is exact, not within a tolerance.
- Result: 4096 floats byte-exact on `Microsoft Direct3D12 (NVIDIA GeForce RTX 3090)` via Dozen.
  The wrong-beta negative control mismatches, so the check certifies the compare, not decoration.

## Running it

Needs a real RenderingDevice. Headless returns null (the `[Cassie][SlangDispatch][GPU]`
doctests skip for this reason), so run non-headless on a real device:

    # WSL: NVIDIA GPU through the Dozen (D3D12) Vulkan ICD, under WSLg
    VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/dzn_icd.x86_64.json \
      godot --rendering-driver vulkan --path . --script res://checks/saxpby_gpu_parity.gd

    # native Vulkan
    godot --rendering-driver vulkan --path . --script res://checks/saxpby_gpu_parity.gd

Regenerate the fixtures with `cc -O2 -o gen oracle.c -lm && ./gen` (writes x/y/params/ref_dst.bin).
