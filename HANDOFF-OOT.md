# Handoff: Ocarina of Time (Switch 2) performance work

Status as of 2026-11-05 evening. Written for whoever picks this up next (a person or an assistant
session on the PC that runs the game).

## Goal

The Legend of Zelda: Ocarina of Time for Switch 2 (`0400486024DEC000`, dumped as `.nup`) on Lichii:
render correctly, and reach **60 fps or more without frame generation** on the owner's PC
(Ryzen 7 9800X3D, RTX 4070, Windows 11).

## Where things are

| Item | Location |
|---|---|
| Fork (builds run here) | https://github.com/Drizz1le/Lichii |
| Upstream | https://github.com/zortos293/Lichii (fork of Djihads80/Eglantine) |
| Current branch | `oot-perf2`: everything below |
| Older branches | `oot-perf` (fallback build), `oot-all-fixes` (visual fixes only), `nx2-experimental` (stale copy of `oot-all-fixes`, safe to delete) |
| Last good Windows build | `oot-perf2` at `fda439d7d`, run 42129582855, artifact `lichii-windows-x86_64-fda439d7d…` (expires 7 days after 2026-11-05) |
| Launcher | `dist/lichii-oot-fast.bat`, copied next to `lichii.exe` in Windows builds |
| Switch defaults | `dist/nx2_switches.txt` (next to the exe); `%APPDATA%\eden\nx2_switches.txt` overrides it |
| Logs | `%APPDATA%\eden\log\eden_log.txt` (latest session) and `eden_log.txt.old` |

## Rules the owner set

- **Workflows run only when the owner starts them.** `release-binaries.yml` and
  `label-issues.yml` have no push, schedule or issue triggers on this fork. GitHub disabled
  Actions on the fork; only the owner turns them back on. Don't dispatch builds or re-enable
  Actions without asking.
- To build: Actions tab, **release-binaries**, **Run workflow**, pick the branch, leave
  "Publish the binaries as a GitHub release" unticked. The Windows zip is under Artifacts on the
  run page. A warm run takes 20 to 45 minutes; Windows (MSVC) finishes last.
- Don't open PRs or post on the upstream repos without the owner's go-ahead.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## How to test a build

1. Extract the zip into a new folder. Run `lichii-oot-fast.bat`, not `lichii.exe`.
2. #161 forces Ocarina's settings at boot unless a per-game override exists: GPU accuracy Low
   (named "Fast" in the UI, which turns on the GPU thread split), async shaders, CPU accuracy
   Unsafe, reactive flushing off (read traps take over), GPU video decoding, async presentation.
   Still choose Docked and frame generation off by hand.
3. Delete any `EDEN_NX2_CORE_PLAN` line from `%APPDATA%\eden\nx2_switches.txt`.
4. A new build recompiles shaders: walk through Kokiri Forest once, then stand still in one spot
   for 30 s and read the FPS.
5. Read `eden_log.txt` (see "Reading the log").

## Reading the log

Each `Booting game:` line starts a session; settings changes mid-session start new ones.
`LogSettings: M-` lines are changed settings.

| Line | Meaning |
|---|---|
| `nx2:vi2 last 600 presents: frame N us` | game frame time (16667 us = 60 fps); `blocked on the GPU fence` = waiting for the host GPU |
| `GPU thread split: engine methods run on a second thread` | split on (needs GPU accuracy Low) |
| `GPU back thread per second:` | back thread zones (ms/s); `split wait` = idle |
| `GPU thread per second:` | front thread, or the only GPU thread without the split; `split drain`, `writer wait` and `waits for the back by site` = waiting on the back |
| `Fast draw per second` / `Fast draw ineligible per second` / `Fast draw state changes … by method` | draw reuse, why draws can't be reused, which registers break reuse |
| `Buffer skip`, `Inline invalidation`, `Dynamic state per second` | the other fast-path switches |
| `Scheduler per second: … submits, … render passes, … finishes` | then `Render pass ends … at` and `Finishes … at` by call site |
| `DKB gpu_frame` / `DKB gpu_work` (EDEN_DKB_FRAME_TRACE) | host GPU time per sampled frame and the slowest shaders (`s6:` = compute, `s1+s5` = draw) |
| `Runtime pipelines in the last 10 s` | shader compile stalls |

Zones the profiler gained in this work: `storage binds`, `handle programs` and `samplers`
(inside `read handles`); `compute lookup` and `compute configure` (inside `compute`);
`deferred call` (split back, used to be part of `other`).

## What the measurements showed

From the owner's logs on `oot-perf-build-4` and earlier:

- build 80 (no grass): about 35 fps (28 ms). With the grass fixes: 21 to 26 fps.
- **GPU accuracy High turns the split off**; everything then runs on one GPU thread.
- With the split (accuracy Low), Kokiri Forest at about 24 fps, about 30,000 draws/s:
  - Back thread: about 787 ms/s in zones, `split wait` 209 ms/s, so about 33 ms of work per
    frame. Largest: `method` 179, `other` 172, `read handles` 90, `compute` 89 (27 us per
    dispatch), `draw` 65, `bind stage buffers` 55 ms/s.
  - Front thread: `split drain` 534 ms/s, i.e. mostly waiting on the back: macro DMA reads 298,
    acquires 209, list writers 194, GPU-written list waits 119 ms/s.
  - Fast draw reused about 8% of draws. The last break before most others was method `0x446`
    (`vertex_id_base`, 14,568/s) and `0x54c` (`clear_report_value`, 5,472/s). Both are fixed
    in `oot-perf`; the next log shows what breaks reuse now.
- `EDEN_NX2_CORE_PLAN=1` (one physical core per hot thread): 25 to 21 fps, slower. Left off.
- Not yet known: the host GPU frame time on the 4070, and whether the guest CPU threads limit.
  The next log answers the first (`DKB gpu_frame`); the sampling profiler (below) answers the
  second.

## What each branch contains

### `oot-all-fixes` (visuals; the owner confirmed the image is right)
Grass, ferns and canopy and the haze fix (Duck912/Jonas: pointer-loaded storage buffers,
pointer-table pools, multiply folding, query flush before MME DMA reads), #121 (white flashes),
#125, #127, page-table range cache, idle spin, clang-cl build fixes.

### `oot-perf`
Adds #147 (batched CPU readbacks, +19% measured in OoT), #141 (skip uploads of render targets a
clear overwrites, +12%), #149 (split deadlock, FSR3 frame gen, RED/SURED), upstream #488
(threaded movie decoding), the fast-draw family from `perf/oot-fast-draw`, `407136901` and
`7429fba04` (fewer front waits), plus these changes made in this work:

- `yuzu/main.cpp`: fast-draw and GPU-profile switches are reread after `nx2_switches.txt`
  loads. They are initialized before `main()`, so setting them in the file did nothing.
- `maxwell_3d.cpp`: `vertex_id_base` is a fast-draw parameter and `clear_report_value` doesn't
  break reuse.
- `puller.cpp`: met greater-or-equal acquires skip the split drain. In `oot-perf2`, #161's
  equivalent replaces the main one; the `SEM_EXECUTE` one remains.
- `memory_manager.cpp`: `GetMemoryLayoutSize` cached per thread until the page table changes.
- `gpu.cpp`: `TickWork` skips its mutex when no sync request is queued.
- `common/thread.cpp`: `EDEN_NX2_CORE_PLAN` (off; measured slower).
- `vk_rasterizer.cpp`: Ocarina blit-depth clear skip, now opt-in
  (`EDEN_NX2_SKIP_BLIT_DEPTH_CLEARS=1`). The query flush before MME DMA reads fixes its cause.

### `oot-perf2` (current)
`oot-perf` merged with upstream `nx2` (#144, #150, #142, #140, #146, #137, #129), plus:

- **#161** (999sian, 7 commits): 4096-draw submissions on desktop, event-driven semaphore
  waits, zero-spin split waits, **1-frame-ahead present for Ocarina**, inline CNTPCT and x86
  TSO loads in dynarmic, clean-buffer upload skip, dav1d and CPU-decode fallback, `.nup`
  program id resolved early (disk shader cache works for `.nup`), Ocarina setting overrides.
  `FrontDmaRead` uses #161's waits (synced writers plus the semaphore slot; full drain only for
  GPU-written pages).
- **#166** (Dr. Sergio), selected: config assert fix, LayeredFS on NUP, NUP decompression
  cache, `EDEN_NX2_HANDLE_PTR_CACHE`, `EDEN_NX2_PIPELINE_CLEAN`, `EDEN_NX2_UBO_INPLACE`.
  Skipped: MACRO_SINK (this tree already sinks 3D macro state writes), COMPUTE_SINK,
  RING_PAIRS, FENCE_LIGHT, DOWNLOAD_COALESCE, DMA_READ_FAST and ACQUIRE_PRECHECK (#161
  covers these two).
- **#143** (Felipe Lima): upscaler stand-in, plus this work's `EDEN_NX2_TENSOR_STANDIN=1` to
  use it on any GPU (Ocarina's upscaler: 11 compute programs, up to 768 emulated HMMAs each).
- **Upstream Eglantine #639**, ported: `Drain` waits until the back's idle hook has run, except
  inside `Run`, and `BufferCache::WriteMemory` downloads only on the scheduler's owner thread.
- Build fixes: `OverlapsNativeSyncpointShim`, reverted #166's 0xb0 mirror (needs
  COMPUTE_SINK), the MSVC C4456 and C4244 fixes, `GetProcessorCount` on non-x86.
- Profiler zones listed above; GPU frame trace and sampling-profiler lines in the launcher.

## Switches

| Switch | Default | Notes |
|---|---|---|
| `EDEN_NX2_SPLIT=2`, `EDEN_NX2_FENCE_BATCH=1` | on (file) | split needs GPU accuracy Low |
| `EDEN_NX2_FAST_DRAW=2`, `BUFFER_SKIP`, `INLINE_INVALIDATE`, `DYNAMIC_SKIP` | on (file and bat) | `EDEN_NX2_FAST_DRAW_VERIFY=1` counts mismatches |
| `EDEN_NX2_HANDLE_PTR_CACHE`, `PIPELINE_CLEAN`, `UBO_INPLACE` | on (file and bat) | from #166 |
| `EDEN_NX2_GPU_PROFILE=1`, `EDEN_DKB_FRAME_TRACE=1` | on (bat) | diagnostics; turn off for play |
| `EDEN_NX2_FRAMES_AHEAD=0` | off | escape if the game hangs or the GPU resets (#161 present) |
| `EDEN_NX2_TENSOR_STANDIN=1` | off | if the GPU limits; costs image quality |
| `EDEN_NX2_FLUSH_DRAWS=<n>` | off | draws per submission, default 4096 on desktop with #161 |
| `EDEN_NX2_SKIP_BLIT_DEPTH_CLEARS=1` | off | only if floor blotches return |
| `EDEN_NX2_CORE_PLAN=1` | off | measured slower |
| `EDEN_NX2_SAMPLE_PROFILE=1000`, `_DELAY=90`, `_THREADS=GPU,GPUBack,VulkanWorker,CPUCore_*` | off | function-level profile; disables the zone timers |

## Risks and open problems

- #161 hung an RX 9070 XT (AMD driver) about 30 s after boot and once froze the PC; its author
  hasn't found the cause. The owner is on NVIDIA. If it hangs: `EDEN_NX2_FRAMES_AHEAD=0` first.
- #161 forces reactive flushing off for Ocarina (read traps take over, which #147 is built
  for). Watch for anything that looks like the game reading stale GPU results.
- Issue #163: texture flicker with accuracy Low and the split, on AMD; cause unknown.
- The upscaler network is emulated on NVIDIA every frame; its GPU cost is unknown.
- No `oot-perf2` performance measurement yet. Projection: 30 to 40 fps in Kokiri Forest.
  60 without frame generation needs roughly half the remaining back-thread work removed, or
  wherever the next log points.

## Next steps

1. Get one log from `oot-perf2` with the bat as shipped (warm shaders, 30 s still). Read:
   `nx2:vi2` frame time; `DKB gpu_frame` (is the 4070 near the frame time?); back zones,
   including the new `compute lookup/configure`, `storage binds`, `handle programs`,
   `samplers` and `deferred call`; front `waits for the back by site`; `Finishes … at`;
   fast-draw breaks by method.
2. If GPU-bound: try `EDEN_NX2_TENSOR_STANDIN=1`, then the Max Resolution add-on off.
3. If back-bound: attack the largest new sub-zone. Candidates: fast-draw breakers that remain
   (classify draw-only registers as `IsFastDrawParameter`, as done for 0x446); compute
   `configure` cost per dispatch; port #166's COMPUTE_SINK (needs its `SinkMethod` and
   `SplitPlainTag` plumbing); FENCE_LIGHT with DOWNLOAD_COALESCE.
4. If front-bound: the remaining `waits for the back by site`.
5. For function-level detail: enable the sampling-profiler lines in the bat, run, then on this
   PC run `python -I tools/nx2/sample_report.py nx2_samples_<pid>.bin --exe lichii.exe`. Needs
   `llvm-symbolizer` (LLVM) and the build's `lichii.pdb`, which ships in the zip.
6. Watch the upstream PRs for updates: #161 (perf, AMD hang), #166, #143, Eglantine #639 and
   #644, and the `scratch/oot-shader-lab` and `oot-jojo` branches on Djihads80/Eglantine.
