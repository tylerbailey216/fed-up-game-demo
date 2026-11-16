# First playable test report

Automated on this machine with portable Godot 4.5.1, headless. Scene loads with no GDScript parser/runtime errors. Smoke output: `SMOKE PASS: empty config, road contact, movement, cockpit, pause, reset`. A system certificate-store warning occurred in the restricted environment; no runtime network calls are used. Rendered capture also ran successfully through OpenGL Compatibility on Intel UHD Graphics 620; `first-playable.png` shows the chase view at 1280x720. An oversized rear tagline found during inspection was removed. These checks do not replace keyboard, GPU performance or five-minute playtesting.

| ID | Result | Evidence / manual procedure |
|---|---|---|
| T01 | Partial | Headless local launch passed. Disconnect network and launch via CMD for human/offline check. |
| T02 | Pass | Empty config asserts traffic/hazards false; no population systems exist. |
| T03 | Partial | Named throttle, brake, reverse and handbrake actions passed accelerated regression. Physical keyboard mapping still needs hands-on playtesting. |
| T04 | Partial | 300 simulated seconds / 10,215.3 m, max radial error 0.105 m, min body Y -0.002 m, zero resets. Outer barrier contains and stops van in regression. Manual barrier approaches and keyboard drive remain. |
| T05 | Partial | Cockpit state switches and hides van exterior in test. Rendered new vector cockpit at 1280x720; manually alternate C around curves. |
| T06 | Partial | Vehicle emits live speed/gear/distance. Visually verify HUD while accelerating, braking and reversing. |
| T07 | Pass | Reset position, zero speed asserted. Manually press R while driving. |
| T08 | Partial | Position remains identical while physics paused. Manually Esc/resume while holding throttle and test buttons. |
| T09 | Deferred | No traffic mode until first-playable gates pass. |
| T10 | Deferred | No construction mode. |
| T11 | Partial | Captured and inspected menu/cockpit at 1280x720. 1920x1080 and fullscreen still need hands-on checks. |
| T12 | Pending | Local portable-engine launcher provided; standalone export and outside-editor distribution QA remain. |

Not presentation-ready until manual T01–T08 and five-minute drive are recorded. No measured FPS, gamepad support, polished cockpit, or standalone Windows export claimed.

## Handling / cockpit iteration

Corrected collider bottom from 0.25 m above the model origin to the ground plane, so the wheels no longer settle into the road. Brake now wins over throttle, stops at zero, and requires a 0.45-second standstill hold before reverse. Original vector dashboard adds live analog speed, estimated RPM, moving steering wheel and position on the ring route. Main-menu return stops and resets the drive.

Regression command: `tools\Godot_v4.5.1-stable_win64_console.exe --headless --path . --fixed-fps 60 -- --driving-test`.

Result: `DRIVING TEST PASS: throttle, brake, reverse, 300s circuit, speed cap, handbrake, barrier, menu`. Original smoke suite also passes. Fixed-FPS mode accelerates simulation; the five minutes are simulated time and do not establish GPU FPS or human driving quality. Capture files: `cockpit.png` and `menu.png`.

## Blender van / highway scenery iteration

Generated editable `.blend` source and a 167 KB GLB with installed Blender 5.2.3 LTS; Godot imported the GLB successfully. Rendered and inspected chase, rear three-quarter, and cockpit approach to an overpass on Intel UHD Graphics 620. Screenshots: `first-playable.png`, `van-detail.png`, `overpass-cockpit.png`. The van has doors, hinges, steps, bumpers, mirrors, grille, lamp lenses and hubs. Mirrors do not render live rear views, wheels do not rotate yet, and headlights are not functional lighting.

Three overhead crossings have 7.125 m minimum underside height above the deck; their supports remain outside the drivable road barriers. Added batched trees, clouds, window bands, and a landmark tower. Adjusted window-band separation and camera near plane to reduce distant depth artifacts. No traffic, pedestrians, or hazards added.

Resized simplified van collision to fit the exterior. Final regression after resizing: **PASS**, 300 simulated seconds, **10,215.4 m**, maximum radial error **0.109 m**, minimum body Y **-0.001 m**, **zero resets**; speed cap, brake/reverse, handbrake, outer barrier and menu checks passed. Original smoke suite also passed after model integration (before the final collider size change). Human five-minute driving, both display sizes, performance profiling and standalone export remain outstanding. Screenshots establish rendering, not a measured FPS target.

## Comic graphics overhaul (latest)

Compared supplied concept sheets against runtime. Added original stepped-shading/ink materials, gradient sky, facade grids/cornices, clustered shaded foliage, road wear and concrete joints/reflectors, twin illustrated freeway signs, van contact shadow and purple/orange lettering. Rebuilt cockpit/HUD/menu in scalable vector graphics, including a real rear-facing camera feed. Enabled 2x MSAA. New drives start in cockpit; C retains chase view.

World box visuals now batch by shared material; original collision transforms are retained. **300-second simulated driving regression PASS:** 10,215.4 m, max radial error 0.106 m, minimum body Y -0.001 m, zero resets. Throttle/brake/reverse, speed cap, handbrake, barrier and menu checks pass. Smoke suite passes after old HUD removal. No new traffic, pedestrians or hazards.

Rendered and inspected cockpit, van exterior, overpass approach and menu at 1280x720; inspected `polished-1080.png` at 1920x1080. No shader compiler errors on Intel UHD 620 Compatibility. `RENDER_SAMPLE.txt` contains the latest 120-frame stationary cockpit sample with live mirror and 2x MSAA. This provides a short renderer observation, not sustained driving performance. Human keyboard playtesting, fullscreen behavior and standalone export remain pending.

Manual graphics checks: launch; start Free Drive (cockpit); drive and confirm mirror movement/route marker/speed; press C twice; pause/resume; reset; test both resolution buttons; inspect signs/road seams during multiple laps. Current known visual limits: simple cloud/tree geometry, static exterior wheels and lights, no dynamic cast-shadow simulation, vector cab rather than a fully modeled interior. Estimated RPM and unsimulated fuel/condition stay labeled.

## Illustrated asset pass v2 (latest)

New transparent cockpit artwork integrated with live mirror, analog/digital instruments, gear and steering wheel. Added a detailed illustrated distant skyline around the 3D world. Refined tree clusters/shrubs, architectural podiums/crowns/glass bays and van windshield/wiper/hub/arch details. Batched exported van into eight meshes; source remains editable. Fixed the skyline texture's wrap-edge seam by clamping its sampler.

**Final automated results:** smoke PASS; 300-second driving regression PASS, 10,215.4 m, 0.106 m maximum radial error, minimum body Y -0.001 m, zero resets. Rendered and inspected cockpit/overpass at 720p and 1080p and the revised front three-quarter van. Captures updated in this directory. No shader compilation errors observed. Latest stationary 120-frame sample: 59.5 average FPS, 19.76 ms p95, 226 draw calls in final sample (Intel UHD 620, 720p, Compatibility, 2x MSAA, reduced-cadence live mirror). This is not a sustained driving benchmark.

Visual limits remain: foreground geometry is simpler than the authored illustrations; the background panorama repeats and cannot be explored; cab is a fixed-view illustration; exterior wheels/lamps stay static. Manual keyboard driving, fullscreen and standalone export acceptance remain pending. No traffic/hazards added.

## Functional dashboard / sound / steering update

Implemented mph/miles, gallons/Fahrenheit, actual simplified fuel burn/refuel/empty-tank shutdown, coolant warmup, RPM/gears, ignition, signals/hazards, parking brake, cruise, headlights/high beam and brake lamps. Added GPS destinations, along-loop distance/ETA/arrival, expanded map, visibility options and locally saved preferences. Three paused control tabs expose HUD/GPS, Vehicle and Audio. Four wheel assemblies now rotate from actual traveled distance and front pivots steer. Added original synthesized engine/load/tire/wind/bird/horn/indicator/starter/brake-air/impact audio plus foliage sway.

Final expanded driving suite **PASS**: 300 simulated seconds / 10,214.5 m, 0.073 m max radial error, minimum body Y 0.000 m, zero fall-through resets. Additional barrier cases cover both inner/outer walls, left/right steering, and forward/reverse recovery. Forward cases moved 7.98–9.24 m after impact while staying between the barriers at ground height; reverse response was checked before reaching the opposite barrier. Hull now has vertical sides with rounded ends, not a climbable horizontal capsule.

Dashboard checks **PASS**: mph conversion, fuel consumption, stopped-only refuel, empty-fuel shutdown, engine-off throttle lockout, cruise set/hold/brake cancellation, parking brake, Q/E/H state changes, L/K lighting, GPS along-road distance/arrival, all four rolling wheels, paused fuel/blink timers, live HUD checkbox and audio-slider bindings. Ten audio files load and engine/nature players enter playback. PCM checks pass for all ten files (mono, 16-bit, 22,050 Hz, maximum absolute peak 0.480; no source clipping).

Smoke suite **PASS**. Audio teardown was changed to retire active mixer voices before quitting; the final smoke/driving runs exited without the earlier playback-resource leak warning. The restricted environment still logs its existing certificate-store warning, unrelated to offline game logic.

Rendered previews: `dashboard-functions.png`, `gps-map.png`, `dashboard-options.png`, `audio-options.png`, plus refreshed cockpit/1080p/van images. Screenshots verify layout; they do not establish audio timbre or human keyboard feel. Last static renderer sample is in `RENDER_SAMPLE.txt` (around 60 FPS on Intel UHD 620 at 720p with 2x MSAA/live mirror). Human audio audition, repeated shallow-angle barrier approaches, fullscreen, sustained driving performance and standalone export remain pending.

## Drift and chase camera update (current)

Expanded driving regression PASS: 300 simulated seconds, 10,014.1 m, maximum radial error 1.689 m, minimum Y 0.000 m, zero resets. Both walls and both steering directions retain forward/reverse recovery; forward escape distance 8.13-9.79 m. Mirrored steering pulses produce lateral slip and suspension roll; handbrake increases slip, release restores grip, reset clears momentum, and barrier impact emits a directional suspension event. Dashboard/audio checks and smoke PASS. Turning screenshot drift-turn.png inspected; final camera tuning increases heading lag and adds a shoulder offset. Manual feel and sustained driving performance still need human playtesting. Empty Highway remains free of traffic/hazards.


## Tire squeal / rollover damage update (current)

Full driving suite PASS including the five-minute circuit (10,014.1 m; maximum radial error 1.689 m; zero resets), prior dashboard/audio and barrier checks, and the new crash suite. After final recovery placement/layout changes, focused --crash-test PASS again: actual 30 m/s impacts against both barriers; exactly one count per rollover; 1.2-second settling gate; upside-down final orientation; recovery button callback; recovery within 2.1 m of crash site; damage retained; third-flip smoke; ignition/refuel/reset/throttle lockout; new-truck button clears damage. Turn and hard-stop squeal enter playback and stop at rest. Original tire-squeal WAV generator reports peak 0.355 (below clipping). Rollover is an arcade visual tumble over an upright collision hull, not rigid-body dynamics. Captures rollover-totalled.png and hood-smoke.png verify roof landing, recovery controls and smoke. Human audio audition, manual collision feel and sustained smoke-enabled performance remain to be checked.


## Speed-sensitive contacts / exhaust (current)

Full driving regression PASS: unchanged 300-second circuit, dashboard/audio, steering and recovery checks; expanded contacts/crash checks PASS. Actual 8 and 18 m/s wall hits selected bump playback and did not climb, roll or add damage. Actual 30 m/s angled approaches against both walls climbed to max Y 0.750 m, banked 26.9-27.4 degrees and landed below Y 0.15 m with radii 254.47/265.49 m. Scrape audio entered playback. Hard 30 m/s impacts selected crash playback and retained three-rollover totalled behavior. Throttle acceleration emitted exhaust; release and engine shutdown stopped emission. After final particle sizing/reset changes, focused crash/contact regression PASS again.

Original collision WAV generator peaks: bump 0.319, scrape 0.336, crash 0.539; no source clipping. Captures acceleration-exhaust.png and barrier-climb.png were rendered for visual verification. This is an arcade impulse/bank model with a 0.75 m climb ceiling; no rigid-body or unrestricted vertical wall driving is claimed. Human audio timbre and manual handling acceptance remain pending.


## Connected city traffic update (current)

Traffic regression PASS: 12 cars move before entry; actual truck drive through the opening displaced a barrel 2.18 m and triggered the signal; driving back to the loop preserves state. Red queue settled at x319.59 with zero speed; green released the same car beyond the intersection. Opposing greens are excluded and the entry call includes amber/all-red clearance. Player red crossing is recorded without an invisible barrier. A parked truck queues traffic. Truck pushing moved an unpowered car from x310 to x318.53; car-to-car collision transfers momentum. Actual high-speed truck/car contact triggers rollover. Pause freezes car poses/signal phase; menu freezes traffic without resetting the entry latch. Ten of twelve cars were still moving at the final disrupted-world sample.

Original full driving suite PASS after adding the district: 300 simulated seconds, 10,214.5 m, max radial error 1.689 m, zero resets; original barrier recovery, drift, dashboard/audio, wall climbs, exhaust and crash/damage checks all pass. Smoke suite PASS. Rendered and inspected gate/intersection previews; short live intersection sample near 60 FPS on Intel UHD 620 at 1280x720, approximately 398 draw calls. See TRAFFIC_RENDER_SAMPLE.txt for the final sample. This is not sustained driving performance or manual playtest acceptance. AI is local circuit/sensing behavior and can form queues/gridlock; finite district and other limits are documented in LIVE_TRAFFIC.md.


## Off-road correction (current)

Reproduced before the fix: driving beyond the city slab caused a fall/reset (x260 instead of remaining off-road); entering the road from the plaza stopped at z-84.70, Y -0.099, speed 0.20 against the 0.1 m lip. Added continuous road-height collision and flush plaza collision with separate visual offsets. After fix: x476.05, Y 0.001, zero resets; street return reaches z-75.95, Y 0.001, speed 10.00. Focused off-road suite PASS for forward/reverse street entry, both side approaches, safe-position tracking, far boundary, below-world/bad velocity, rolled/totalled recovery, retained fuel/ignition/damage/trip and an occupied fallback location.

Full five-minute driving suite PASS: 10,214.5 m, max radial error 1.689 m, zero resets; barrier recovery, drift, dashboard/audio, wall climb, exhaust and rollover suites PASS. Live traffic suite PASS after terrain changes, including pushing, red queues, green release, lane blockage and truck/car rollover; 11 of 12 cars moving at final sample. Rendered and inspected offroad-terrain.png and offroad-recovery.png; corrected plaza/highway visual overlap. The skyline remains decorative beyond a finite 500 m demo radius. Manual driving acceptance remains pending.


Final rerun PASS: complete driving suite explicitly checks zero off-road safety recoveries during the 300-second road circuit. Focused terrain suite also drives out onto grass to x476.05, turns around, and returns into the district at x450.48 / Y 0.001 without a reset. Final screenshots show solid off-road terrain and the boundary recovery message.


## Lighter steering / tire trails / physical crash update (current)

Handling suite PASS: mirrored steering at 3/12/25 m/s reaches full input within 0.2 s, counters direction promptly and centers on release. Hard braking produces marks on ring asphalt/city pavement/grass; sharp turns and drift also emit. Ordinary acceleration and airborne tires do not paint trails; all marks expire after seven gameplay seconds, and fade time pauses. Captured and inspected tire-marks.png versus tire-marks-faded.png; 136 strips emitted in the visual maneuver, zero live strips afterward.

Physical crash probes: frontal 34 m/s settles upright with zero flips, peak tilt about 1 degree; mirrored 34 m/s angled trips physically settle on their sides around 90.4/90.5 degrees, one counted rollover each, peak hull-center Y 2.07/2.05 m. No scripted airborne lift/rotation curve. Crash pause freezes pose; menu resume retains momentum and counts no duplicate flips. Three physical oblique trips preserve recovery, third-roll totalled lockout and smoke. Traffic suite PASS with revised frontal-crash expectation; off-road suite PASS with physical totalled-body boundary recovery.

Full driving suite PASS: 300 simulated seconds, 10,214.6 m, max radial error 1.670 m, zero resets/safety recoveries. Both-wall forward/reverse recovery, mirrored drift, dashboard/audio, wall climb, exhaust and physical damage suites pass. Normal driving remains arcade handling; manual keyboard/collision feel and sustained marks/crash performance still need user playtesting.



## Independence geographic prototype

`--outerbelt-test` PASS: 521 mapped surface rays including 75 elevated bridge rays; continuous input-driven eastbound I-480 traversal 1582m over 172 connected samples with zero collisions, flips or safety recoveries; max road elevation gap 0.41m; 8542m of additional sampled freeway deck positions; throttle, reset and boundary recovery. The sampled distances are not continuous driving distances. `--location-switch-test` with `--outerbelt` PASS: reload both directions and override launch flag. Original `--smoke-test` and `--offroad-test` PASS. Rendered overview, chase, cockpit/map checked on Intel UHD 620 in Compatibility mode; no sustained FPS benchmark performed. Restricted headless runs retain the existing root-certificate-store warning. Limits and source licenses: INDEPENDENCE.md and assets/maps/README.md.


Map selection fix: both maps now have named Drive buttons. The alternate button starts the selected location immediately after reload and disables duplicate clicks during loading. --location-switch-test now emits the actual menu button signals and verifies location, automatic driving and menu visibility in both directions, including override of --outerbelt launch arguments. Existing running demo windows need reopening to load these script changes.


## Independence GPS stutter fix

Measured at 1280x720 on Intel UHD 620, OpenGL Compatibility. Original chase/GPS-on: 2.66 FPS, p95 406.21ms, ~1942 draw calls. GPS-off: 59.54 FPS, p95 19.09ms. Baseline was stopped after these two conditions identified the bottleneck; see independence-performance-baseline.json. After caching the static geographic map as a texture, spatially indexing road queries, throttling failed safety samples and chunking/culling distant scenery: chase/GPS-on 60.05 FPS, p95 17.49ms, ~276 calls; cockpit/GPS-on 59.80 FPS, p95 18.07ms, ~373 calls. All four conditions (chase/cockpit, GPS on/off; 240 measured frames each following warmup) had zero frames over 33.34ms. Nearby nearest-road query averaged 0.023ms across 64 probes. These are short accelerating approach samples, not a sustained full-map performance guarantee. See independence-performance-optimized.json; reproduce with --outerbelt-capture --profile. Both map sizes now prepare during loading so the first expanded-map opening does not rasterize geography during play.

Final --outerbelt-test PASS includes 36 indexed-vs-exhaustive nearest-road/safety comparisons, 521 road/bridge rays, continuous 1582m freeway drive with zero collisions/flips/recoveries and 8542m of additional sampled deck coverage. Original --offroad-test and --smoke-test PASS after cooldown changes. Render captures checked for cockpit GPS and chase appearance.


## Motorway edge containment and impact physics

Safety builder: 8,365 sections / 40,549m protected external edges; 47 audited grade
crossings, minimum deck underside clearance 6.01m. --outerbelt-test --safety PASS:
1,195 barrier collision rays; steel and concrete containment at 4, 12 and 20m/s;
two 18m/s glancing/sliding contacts remain on their original level; 34m/s steel
impact yields a section, dissipates energy, crosses the rail with no upward boost;
severe concrete impact activates rigid collision without removing concrete;
elevated manual recovery stays on the bridge. Rendered safety run also PASS;
images motorway-guardrails.png and guardrail-breach.png inspected. --outerbelt-test
PASS: full 1,582m input-driven drive, zero collisions/flips/recoveries, 521 road
rays and sampled deck support. Original --offroad-test and --handling-test PASS.

Post-barrier render sample, Intel UHD620 / 1280x720 / Compatibility, four conditions
240 frames each: chase GPS-on 60.06 FPS / p95 17.94ms, cockpit GPS-on 59.81 FPS /
p95 18.73ms. No sampled frame exceeded 33.34ms. Full report in
independence-performance-optimized.json. This remains a short approach test,
not a sustained every-road performance guarantee or real-world crash validation.

Final breakaway energy regression also PASS: the impulse includes the loose beam rotational inertia and off-center contact lever. Combined outgoing truck translation plus loose-section translation/rotation does not exceed incoming truck kinetic energy minus the 450kJ anchor-yield work. This test verifies the energy bookkeeping of the game model, not material crashworthiness.
