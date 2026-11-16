# Browser and delivery update — November 16, 2026

Default location: training ring connected to a 1.3 km OpenStreetMap-derived downtown Cleveland street blockout. 1,238 road/path sections, 227 building footprints, Public Square park paths, an original procedural Terminal Tower landmark and eight physical traffic cars. Independence remains the second map. Street access and traffic rules are simplified for the game.

The truck GLB now has a hollow cargo bay and two rear-door pivots. The first registered collision after training opens the doors and ejects six physical boxes. Six remaining packages spill along the route. Slow truck proximity collects boxes; on foot the worker carries one to the truck or purple depot. Repeated impact damage or three rollovers disables the vehicle, with automatic safe exit once settled. Position reset cannot bypass a spilled load.

The playable worker is an original procedural 3D interpretation of the supplied character and animation sheet, with walk/run cycles, carrying pose and rotating follow camera. The supplied raster reference sheets remain local references.

Responsive layouts include portrait phone, portrait/landscape tablet and desktop. The illustrated desktop cockpit retains uniform scaling. Smaller screens use a separate live instrument layout. The actual 3D camera projection follows viewport aspect; multi-finger controls track steering and pedals independently. Menus scroll on short screens. The rear mirror does not render in compact mode to reduce work.

## Validation performed

- `--delivery-test`: passed actual barrel crossing, first physical collision, door animation, package spawning, city bounds, forced foot exit, movement, all 12 packages recovered, closed doors, responsive menu bounds, simultaneous steering/pedal and independent release.
- Packaged `.pck` delivery test: passed, verifying shipped maps/resources are available.
- `--outerbelt --delivery-test`: passed motorway cargo spill and safe foot exit.
- `--location-switch-test`: passed actual named map-button signals, both directions and automatic drive start.
- `--outerbelt-test --safety`: passed 1,195 barrier rays, normal/moderate containment, energy-limited steel breach, physical concrete impact, elevated recovery and 47 crossing audits. This pre-existing geometry test disables the cargo mission so repeated test collisions do not end its vehicle simulation.
- Native rendered captures at 1280×720, 720×1280, 768×1024 and 1024×768 inspected.
- Single-threaded web export loaded and started in Chrome through a local HTTP server. Console/page errors: none. Portrait 720×1280 and tablet 1024×768 captures inspected. Tablet canvas and DOM rectangle both exactly 1024×768 after rotation, without letterboxing or distortion.

Browser QA uses desktop Chrome with touch emulation and software WebGL. This verifies startup, resources, touch path and layout; it is not an iPhone/Android hardware benchmark. Real-device thermal/performance, Safari audio and long sessions remain to be tested.

Export size approximately 43 MB. Godot 4.5.1 Compatibility / WebGL 2, official `web_nothreads_release.zip`; no cross-origin isolation headers required. GitHub Actions builds from source and publishes the artifact through Pages. Local `build/web` is generated and excluded from Git.
