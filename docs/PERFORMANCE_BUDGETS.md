# Performance evidence and targets

Measured November 17, 2026. Smooth PC and mobile play remains a performance objective, not a verified result on every device.

## Current evidence

Chrome uses the machine's Intel UHD Graphics 620 through ANGLE/D3D11. The populated approach contains 16 citizens and 14 cars. Browser tests with touch emulation and a 844 x 390 CSS viewport at DPR 2 render a 1688 x 780 canvas. A recent crowded on-foot sample measured about 11 FPS, 347 draw calls and 109,000 submitted primitives. Earlier four-layout functional checks measured roughly 9-23 FPS. These readings do not establish isolated device capacity: an already-running native FedUp process remained active throughout testing. With the browser benchmark closed, two Windows GPU Engine counter samples attributed 50.9% and 51.1% 3D-engine use to that native process. Its gameplay was not interrupted.

The bottleneck has not been cleanly attributed to hardware or a single subsystem. Browser resolution/view-distance reductions and stopping individual simulation systems did not yield a reliable large improvement in these competing-load samples. A traffic MultiMesh experiment lowered submissions from about 350 to 192 but did not improve measured FPS; it was removed. Avoid claiming a speedup from draw-call counts alone.

Dashboard drawing is now capped at 30 updates per second while its live telemetry remains current. Mobile button artwork and layout are retained until stick/direction/view/status or screen dimensions change. This removes unnecessary UI rebuilding; it does not change vehicle physics, drawn character gait, package rules or aspect ratio. A before/after FPS improvement has not been established under isolated conditions.

## Isolated November 17 follow-up

After the user closed the extra native copy, no Godot game process remained during browser profiling. The unchanged crowded landscape sample measured 16.8 FPS, p95 100 ms, about 349 draw calls and 109,400 primitives at 1688 x 780 render pixels. Closing the other game helped but did not remove the bottleneck.

Traffic rendering now merges each car's original colored body panels and all four wheel meshes into one mesh, with its live brake lights separate. Wheel axle metadata applies the existing roll and front-wheel steering in both the color and ink vertex shaders. Each car retains independent physical simulation and spatial culling; no whole-city vehicle MultiMesh is used. Geometry, colors, outlined shading and the 16-citizen/14-car population remain in place. `tools/build_traffic_shaders.py` generates standalone traffic variants from the original toon/ink shaders plus the axle pose source, avoiding shader-resource include preprocessing errors in Web release exports. Rebuild the variants after changing their shared art sources.

With the corrected shaders and normal full-resolution/2x-MSAA settings, a follow-up sample measured 23.2 FPS, p95 66.5 ms, about 209 draw calls and 109,700 primitives. This is a useful reduction in submissions and a better sample, not proof of a sustained 30/60 FPS target. Earlier body-only tests and an antialiasing/render-scale diagnostic briefly reached 56-60 FPS, but unchanged-settings repeats did not sustain that result. Do not report that peak as a fix. Shader-error runs are excluded from the comparison.

Audio isolation now actually stops loop playback and its updates, rather than just setting volume to zero. A silent sample measured 24.1 FPS and a later restored-audio sample 23.3 FPS, so this test does not justify removing the audio. Scene rendering and browser/main-thread cost remain the next areas to profile; the exact hardware/software split is not fully attributed.

Native visual review checks PC, portrait and landscape scenes, including animated citizen reactions. Delivery regression checks preserve all four rendered wheel axles, separate live brakes, matching wheel rotation in color/ink passes, mobile reverse, automatic pickups, the third-crash quota, collision recovery and map switching. Keep native reviews and browser benchmarks sequential so test instances do not compete.

## Remaining targets

- Target 60 FPS on the intended PC; aim for stable 30 FPS on supported phones, with 60 where measured capacity allows. These are targets, not minimum hardware promises.
- Close or pause extra game instances, then compare the same stationary crowded block, driving route, collision burst and package-recovery sequence.
- Record actual renderer, canvas pixels, average FPS, 95th-percentile frame time, physics time and draw calls. Average FPS alone can hide stuttering.
- Test real iOS and Android hardware. Desktop touch emulation verifies controls/layout, not mobile CPU/GPU, thermal or memory capacity.
- Keep detailed animation and physical reactions near the player. Expand the population with distance-based simulation, geographically grouped rendering and controlled reaction budgets, measuring each change before increasing density.
- Keep HUD/art readable at native proportions; optimize render scale and scene cost rather than stretching or cropping the game.

`node tools/browser_city_profile.cjs <url>` samples the busy block, then cumulatively disables camera, HUD, scenery, citizens, traffic and audio for diagnosis. `--probe` samples only normal play. It writes local `docs/city-profile-smoke.json` and a screenshot. The `?qa=controls` fixture is opt-in and does not run during ordinary play. `tools/browser_controls.cjs` separately verifies actual keyboard/touch reverse, distant automatic pickups and population; its FPS reports are measurements rather than performance pass assertions.

The profiler warms the scene for eight seconds. `--steady` takes five spaced samples without changing gameplay/graphics settings; `--gpu` compares MSAA/render scale and restores original settings; `--audio` stops and restores playback. Normal-game screenshots and console shader failures are captured; any console error fails the profile rather than accepting a faster fallback render. These diagnostic settings do not change ordinary gameplay defaults.
