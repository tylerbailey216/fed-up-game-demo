# Runtime ownership

`scenes/main.tscn` starts `scripts/main.gd`: world setup, original van geometry, menus, camera commands and HUD subscription. Root processes during pause so Resume remains usable.

`scripts/highway.gd` builds 240 overlapping collidable road segments on a 260 m radius ring. Each has three lanes, shoulders and barrier collision. Seeded skyline meshes are decorative. Segments align local -Z along the forward tangent. `block()` shares flat materials and optionally supplies a box collider.

`scripts/van.gd` owns CharacterBody3D physics: signed longitudinal speed, smoothed steering, gravity and slide collisions. Physics pauses through PROCESS_MODE_PAUSABLE. The telemetry signal feeds HUD state; camera is a child rig. Cockpit hides exterior proxy geometry to avoid windshield clipping.

`data/empty_day.json` retains the quiet-loop scenario contract checked by smoke tests. `traffic_district.gd` separately instantiates the connected live city. It is not controlled by the old empty-scenario traffic flag. No generalized scenario loader exists yet.

Scale: meters; truck approximately 2.3 m wide and 5.1 m long; lanes 3.6 m wide; road deck 15.5 m wide. Forward is local -Z, Y is up. Replace visual children with Blender-exported GLB meshes while retaining controller and simple collider.

The current van visual is loaded from `assets/models/fedup_van.glb` with runtime Label3D wordmarks. The old procedural van remains the missing-model fallback. Its simplified body collider is now 2.5 m wide × 3.15 m tall × 5.3 m long; mirrors extend beyond it. Detailed mesh parts do not create individual collision shapes.

World details remain independent of road collision: three decorative elevated crossings have undersides at 7.125 m, with supports outside the barriers. Trees, clouds and window bands use batches. The 240-module road ring now has a signed opening in its outer rail at modules 228-230, connected to the live district. The loop lanes retain their quiet baseline; traffic and construction barrels occupy the optional city area. Cloud and tree meshes are scenery.

`scripts/cockpit.gd` draws the scalable first-person dashboard and route diagram. Telemetry supplies actual speed/gear/distance, smoothed steering and route angle. RPM is explicitly an estimate from road speed. This is a vector overlay, not an authored 3D cab. Exterior geometry remains hidden in cockpit view. Blender is the asset authoring path. Unreal is an alternative runtime, not a dependency. Lens Studio and Effect House are outside this desktop scope.

Driving uses named InputMap actions configured at startup with physical WASD/arrows/Space events. `scripts/driving_tests.gd` exercises those same actions, feeding analog steering through a test-only circle-following controller. It never teleports the van or forces speed during the five-minute circuit. This controller is not active in normal play. The van counts reset invocations so a fall-through cannot silently pass the circuit test.

## Comic renderer update

World box visuals now consolidate into MultiMesh instances by shared material after generation. Collision bodies are reparented with their global transforms preserved before their old visual nodes are freed. The 300-second road regression covers this changed collision ownership. New facade generation is isolated in `city_art.gd`; rendering rules live in `art_style.gd` and `assets/shaders/`.

HUD now consists of one original vector canvas (`cockpit.gd`); the earlier hidden prototype panels were removed. A low-resolution shared-world SubViewport (`rear_mirror.gd`) supplies the actual rear camera image at reduced cadence. Menu art is a separate canvas shown during menu/pause. New drives default to cockpit, while resumes preserve the selected view. `ART_DIRECTION.md` documents palette, shader tuning and limitations.

The v2 cabin renderer optionally loads `assets/art/cockpit_illustrated_v2.png` and layers it between the live mirror feed and live instrumentation/steering. If missing, the original vector cab draws instead. `skyline_art.gd` adds one static textured cylindrical mesh for the distant city; it has no collider or gameplay state. The foreground city and vegetation retain batched geometry. Generated art paths are explicit dynamic export dependencies.

## Functional dashboard / audio update

Turning now retains world-space planar momentum and dissipates its lateral component with speed-dependent limits and normal/handbrake grip. `van.gd` exposes slip, yaw rate, acceleration and directional impact events. Its render update follows an independent smoothed chase heading/position; `camera_manual` preserves authored capture cameras. `vehicle_visuals.gd` integrates a damped, bounded body suspension spring independently of the collision hull. Reset clears transients. The input regression covers mirrored turn slip, grip restoration, camera separation and impact events.

`van.gd` owns gallons, coolant warmup, estimated RPM/gears, ignition, indicators, hazards, parking brake and cruise. Telemetry keeps its internal km/h signal for compatibility; `cockpit.gd` converts to mph and miles for display. Distance and wheel roll derive from actual displacement, not commanded speed. Collision uses a central box and two vertical cylinders, preserving vertical wall contact with a rounded plan. Solver separation/low-speed steering handles wall recovery.

`navigation.gd` owns fictional ring destinations, remaining centerline distance, ETA and arrival state. `dashboard_options.gd` provides three paused tabs and bindings to real controls. `main.gd` routes global Tab/Esc input before GUI focus traversal, saves local HUD/audio options, and coordinates graceful shutdown. `vehicle_visuals.gd` finds four exported wheel pivots, rolls/steers them, updates lamps, and supplies world-headlight shader uniforms. The Blender exporter merges static parts separately from rolling wheel assemblies.

`game_audio.gd` owns streamed loop/effect players. Original WAV assets come from `tools/build_audio.py`. The controller follows vehicle state and uses pausable processing. Audio voices are stopped/detached, then the mixer drains before quitting to avoid WAV playback-resource leaks. Dynamic audio paths must be included in exports. See `DASHBOARD_AND_AUDIO.md` for the simulation's practical limits and controls.

Rollover state lives in van.gd: qualifying collision entry increments flip_count once, blocks driving, forces chase and exposes a timed upright recovery. Third flip latches wrecked; only new_truck clears damage. Upright/reset/refuel/ignition preserve that latch. vehicle_visuals.gd animates a visual-center roof landing independently of the upright collision hull and anchors world-space CPU smoke puffs at the hood. main.gd supplies responsive recovery/new-truck buttons and U. game_audio.gd loops the original tire squeal according to turn/brake stress. --crash-test exercises actual barrier contacts and real UI callbacks; the full driving regression includes those cases.


Speed-sensitive contact update: van.gd registers collision serial/kind/level from inward impact speed. Fast angled hits apply an upward velocity and bounded 0.9-second wall-ride state; body bank is independent of the upright collider. Hard high-speed impacts retain the rollover path. game_audio.gd consumes collision serials for bump/scrape/crash one-shots rather than polling the decaying impact amplitude. vehicle_visuals.gd emits short rear-left exhaust bursts while throttle produces acceleration; emissions stop on release/disabled states. Both particle systems clear on an undamaged/new-truck reset.


## Connected live traffic district

traffic_district.gd owns the connected city decks, barrel bodies, signal cycle, entry latch, red-light crossing observations and twelve traffic cars. highway.gd reserves the outer-rail opening and clears vegetation at the connector; city_art.gd keeps the new district clear of old decorative facades. Static district geometry joins the existing per-material world batches. Each car's static panels are merged per material while its wheel pivots remain independent.

traffic_car.gd uses a RigidBody3D with horizontal force steering, low contact friction, yaw rotation, obstacle rays and signal-limited target speed. Dynamic bodies remain pushable; van.gd handles truck-to-car/barrel impulse and force transfer separately from static-wall response. Lightweight barrels cannot initiate rollover. The traffic controller/signal pause together, and menu transitions freeze the physical bodies without resetting district state. Positional audio is shut down before the root mixer drain. cockpit.gd switches to a live district map when the truck enters the city footprint.


## Off-road terrain and recovery

The 2200 m ground now supplies solid collision at road elevation. Terrain/plaza visuals are slightly lower than their colliders to avoid asphalt overlap flicker. The plaza collider is flush with road decks, removing the former 0.1 m entry lip. Nearby generated tower cores/podiums have collision. van.gd samples clear positions on known roads and checks a 500 m demo radius plus invalid/fallen motion before any rolled/disabled early return. Recovery validates clearance, falls back to a clear ring position if necessary, clears motion/camera transients and preserves vehicle damage/fuel/ignition/trip and the traffic world. Normal off-road driving stays physical; this guard only handles demo boundaries/faults. offroad_tests.gd covers forward/reverse road return, both side approaches, far-city terrain, boundary/fault recovery and retained damage.


## Current steering / tire marks / crash physics

Steering now uses faster input/recenter/countersteer rates and a revised speed taper. tire_marks.gd owns a fixed-size world-space MultiMesh with per-instance age/intensity and contact rays; its shader fades strips over seven gameplay seconds. Crash response now creates a 3,200 kg compound rigid body, disables the driving collider, and has vehicle_visuals.gd follow the simulated body transform. The old timed half-roll and artificial lift arc are removed. Flip count is based on actual tilt, once per crash; recovery waits for settled motion. Frontal contact can settle upright without consuming a flip. Menu freeze/resume stores physical momentum. See HANDLING_AND_TRACKS.md for model scope and tests; this supersedes older animation-based rollover notes above.



## Geographic location mode

main.gd selects independence.gd as an alternative Highway implementation via the menu or --outerbelt. Switching persists the selected mode on SceneTree metadata, stops audio/traffic, disposes any crash proxy and reloads the scene. Metadata overrides launch flags so both directions work. The original live district is disabled only in this location. independence.gd creates batched road/marking meshes and a shared concave surface/bridge collision mesh from offline OSM-derived data, footprint building meshes, signs and batched scenery. Nearby same-level roads suppress obstructing guardrails; lower roads suppress obstructing piers. van.gd uses location-specific spawn and bounds, and samples clear mapped roads for recovery. The HUD caches geographic map polylines at each map size. See INDEPENDENCE.md for geographic/elevation limits and data licensing.


Motorway safety now uses tools/build_road_safety.py and the ODbL-derived independence_safety.json for continuous external edge coverage. The former guard_clear suppression is removed. road_barriers.gd batches visible steel/concrete sections and creates independent collision; severe steel impacts release the matching section and apply energy-limited linear/angular momentum exchange. Mapped-world crash takeover preserves incoming motion and lets the rigid solver generate rotation. Existing Metro Loop crash tuning stays separate. See INDEPENDENCE.md for parameters, clearance audits and current simulation limits.
