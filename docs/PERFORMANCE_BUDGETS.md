# Performance evidence and targets

Measured November 17, 2026. Smooth PC and mobile play remains a performance objective, not a verified result on every device.

## Current evidence

Chrome uses the machine's Intel UHD Graphics 620 through ANGLE/D3D11. The populated approach contains 16 citizens and 14 cars. Browser tests with touch emulation and a 844 x 390 CSS viewport at DPR 2 render a 1688 x 780 canvas. A recent crowded on-foot sample measured about 11 FPS, 347 draw calls and 109,000 submitted primitives. Earlier four-layout functional checks measured roughly 9-23 FPS. These readings do not establish isolated device capacity: an already-running native FedUp process remained active throughout testing. With the browser benchmark closed, two Windows GPU Engine counter samples attributed 50.9% and 51.1% 3D-engine use to that native process. Its gameplay was not interrupted.

The bottleneck has not been cleanly attributed to hardware or a single subsystem. Browser resolution/view-distance reductions and stopping individual simulation systems did not yield a reliable large improvement in these competing-load samples. A traffic MultiMesh experiment lowered submissions from about 350 to 192 but did not improve measured FPS; it was removed. Avoid claiming a speedup from draw-call counts alone.

Dashboard drawing is now capped at 30 updates per second while its live telemetry remains current. Mobile button artwork and layout are retained until stick/direction/view/status or screen dimensions change. This removes unnecessary UI rebuilding; it does not change vehicle physics, drawn character gait, package rules or aspect ratio. A before/after FPS improvement has not been established under isolated conditions.

## Targets and next measurements

- Target 60 FPS on the intended PC; aim for stable 30 FPS on supported phones, with 60 where measured capacity allows. These are targets, not minimum hardware promises.
- Close or pause extra game instances, then compare the same stationary crowded block, driving route, collision burst and package-recovery sequence.
- Record actual renderer, canvas pixels, average FPS, 95th-percentile frame time, physics time and draw calls. Average FPS alone can hide stuttering.
- Test real iOS and Android hardware. Desktop touch emulation verifies controls/layout, not mobile CPU/GPU, thermal or memory capacity.
- Keep detailed animation and physical reactions near the player. Expand the population with distance-based simulation, geographically grouped rendering and controlled reaction budgets, measuring each change before increasing density.
- Keep HUD/art readable at native proportions; optimize render scale and scene cost rather than stretching or cropping the game.

`node tools/browser_city_profile.cjs <url>` samples the busy block, then cumulatively disables camera, HUD, scenery, citizens, traffic and audio for diagnosis. `--probe` samples only normal play. It writes local `docs/city-profile-smoke.json` and a screenshot. The `?qa=controls` fixture is opt-in and does not run during ordinary play. `tools/browser_controls.cjs` separately verifies actual keyboard/touch reverse, distant automatic pickups and population; its FPS reports are measurements rather than performance pass assertions.
