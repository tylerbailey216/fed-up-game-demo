# Browser and delivery update — November 16, 2026

Default location: training ring connected to a 1.3 km OpenStreetMap-derived downtown Cleveland street blockout. 1,238 road/path sections, 227 building footprints, Public Square park paths, an original procedural Terminal Tower landmark and eight physical traffic cars. Independence remains the second map. Street access and traffic rules are simplified for the game.

The truck GLB has a hollow cargo bay and two rear-door pivots. The first two registered collisions after training keep cargo secured. The third disables the truck and ejects the entire fixed stage quota once: 12, then 16, then 20 packages. There is no timed or distance-based cargo leak. On foot the worker carries one package to the truck or purple depot. Three rollovers also retain the vehicle-disable rule, with automatic safe exit once settled. Position reset cannot bypass a spilled load.

The playable worker uses a transparent illustrated animation atlas prepared from the supplied character sheet, with walk/run/carry cycles, directional idle and rotating follow camera. The original sheet remains local. The finished loading page and title menu share Cleveland key art generated from the supplied worker, truck and cockpit references. Bangers and Barlow Condensed font files include their OFL licenses.

Responsive layouts include portrait phone, portrait/landscape tablet and desktop. The illustrated desktop cockpit retains uniform scaling. Smaller screens use a separate live instrument layout. The actual 3D camera projection follows viewport aspect; multi-finger controls track steering and pedals independently. Menus scroll on short screens. The rear mirror does not render in compact mode to reduce work.

## Validation performed

- `--delivery-test`: passed actual barrel crossing, three separate physical collisions, secured cargo on the first two, exactly 12 spawned on the third, no continuous leakage, walking recovery, progression through fixed 16/20-package stages, responsive menu bounds, simultaneous steering/pedal and independent release.
- Packaged `.pck` delivery test: passed, verifying shipped maps/resources are available.
- `--outerbelt --delivery-test`: passed motorway cargo spill and safe foot exit.
- `--location-switch-test`: passed actual named map-button signals, both directions and automatic drive start.
- `--outerbelt-test --safety`: passed 1,195 barrier rays, normal/moderate containment, energy-limited steel breach, physical concrete impact, elevated recovery and 47 crossing audits. This pre-existing geometry test disables the cargo mission so repeated test collisions do not end its vehicle simulation.
- Native rendered captures at 1280×720, 720×1280, 768×1024 and 1024×768 inspected.
- Single-threaded web export loaded and started in Chrome through a local HTTP server. Console/page errors: none. Portrait 720×1280 and tablet 1024×768 captures inspected. Tablet canvas and DOM rectangle both exactly 1024×768 after rotation, without letterboxing or distortion.

Browser QA uses desktop Chrome with touch emulation and software WebGL. This verifies startup, resources, touch path and layout; it is not an iPhone/Android hardware benchmark. Real-device thermal/performance, Safari audio and long sessions remain to be tested.

Export size approximately 50 MB including loading-page art and fonts. Godot 4.5.1 Compatibility / WebGL 2, official `web_nothreads_release.zip`; no cross-origin isolation headers required. GitHub Actions builds from source and publishes the artifact through Pages. Local `build/web` is generated and excluded from Git.

Rendering correction: normalized OSM footprint winding, repaired reversed window faces and flat-surface normals, and moved city surfaces into vertex-colored spatial batches. Training foliage is spatially batched with distance ranges. Disabled headlights no longer rewrite hundreds of material uniforms each frame. Full-resolution UI remains independent of the 3D pixel budget. Same gateway view on Intel UHD 620, 1280×720 native: baseline 665 draw calls / 735,079 primitives; revised 482 / 221,827, approximately 70% fewer primitives. Revised 120-frame sample after warmup: 60 FPS, p95 17.81 ms. This is a short native measurement, not a mobile performance guarantee.
