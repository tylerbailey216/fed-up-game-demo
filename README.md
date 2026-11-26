# FedUp Driver — Cleveland browser demo

After loading, choose a vehicle in the illustrated garage. The original truck and Thanksgiving **Gobble Express** turkey mount start unlocked; completed Delivery Mayhem deliveries unlock the semi at **1**, tank at **3**, and Santa sleigh at **5**. Locked rides show silhouettes and padlocks. The completion report includes **Vehicle Garage** alongside replay. Career progress saves on this device/browser; it does not sync between devices.

The sleigh drives on the ground or flies at low altitude: **V** on desktop or **FLY / LAND** on touchscreens. Land before exiting or delivering. Both modes use the same fleet. See [fleet and delivery foundations](docs/FLEET_AND_DELIVERIES.md) for current behavior, artwork provenance and planned extensions.

One Godot 4.5.1 project for desktop, phone and tablet browsers. The world renders at the screen's aspect ratio and the HUD reflows; portrait play does not stretch the original cockpit artwork.

**Play:** https://tylerbailey216.github.io/fed-up-game-demo/

The repository contains source; the Pages link runs the exported game. A WebGL 2 / WebAssembly browser is required. First load downloads approximately 50 MB, including the illustrated loading artwork. Physical iPhone/Android performance still needs device testing.

## Play

Choose **Start Delivery Mayhem** for the compact arcade demo. Use **WASD / arrows** or the single **MOVE** thumbstick to point where you want the truck to travel on screen. It turns toward that direction and accelerates automatically, slows for sharp turns, and brakes when you release movement. Down means travel down the screen; opposite input makes a forward U-turn. There are no separate gas, brake, gear or drift controls in this mode. Speed is capped at about 22 mph.

[Phase 1 demo polish](docs/DEMO_POLISH_PHASE_1.md) adds brief comic impact sparks, pickup/route/completion sounds, a pulsing recovery counter, and a readable animated dispatch report. The current curb-return fix keeps the raised sidewalks and bumps while removing a hidden grass lip and false collision seam. Original artwork, driving controls and damage rules are preserved.

[Phase 2 visual audit](docs/VISUAL_AUDIT_PHASE_2.md) records the architectural finish, sidewalk seams, crown contours and shared HUD typography, with before/after captures and remaining artist-authored work.

Drive through four purple route markers in order, then stop in the gold collection bay for 1.2 seconds to deliver the twelve-box manifest. The GPS and edge direction marker show the next route gate or collection bay. There is no deadline: the dispatch report records your time, truck energy used, and recovered packages. A clean delivery counts; a crash is never forced. Driving and walking share a fixed elevated view aligned with the streets; **C / VIEW** switches between Play and a wider Overview without spinning the world. Desktop **G** restores Play distance. On touchscreens, releasing VIEW after either a tap or hold cycles the distance. **ONE MORE DELIVERY** starts a fresh round.

The compact block is a fictional Cleveland-inspired route. Choose **Zen Drive / Explore at your pace** for one relaxed mode connecting **City Streets** and **Open Road**. Follow the cyan GPS marker and gold roadside signs: outbound Ontario Street leads to the motorway; northbound I-77 leads back to town. Crossing the marked road gateway briefly loads the next area, keeping one large environment in memory at a time. Fuel, mileage, lights and camera settings carry across. These are connected zones, not a newly merged continuous road mesh. You can return to Delivery Mayhem from the pause menu. See [Zen Drive](docs/ZEN_DRIVE.md) and [Delivery Mayhem](docs/DELIVERY_MAYHEM.md).

Zen keeps the original simulator controls, cockpit, orbit cameras, physical collisions, curbs, jumps, skids and terrain spray. Its city retains the supplied human/alien pedestrian cast and traffic with quieter pace, more headway and less automatic honking. Open Road now has twelve physical cars on the actual mainline carriageways. Pedestrians stay in the city. Zen has no timed delivery, mandatory package quota, collection bay, permanent damage or forced cargo recovery. Settled rollovers and empty tanks receive roadside help; deliberate ignition and parking-brake controls remain yours. **X / ENTER** returns to the truck when beside it.
In **Delivery Mayhem**, distinct impacts drain the truck life bar according to impact severity. Only an empty life bar disables the truck, opens its rear doors and ejects the fixed load of **12 packages** once. There is no three-hit cap. Packages never continue leaking. Walk over a lost box to collect it automatically: it bursts into shimmering comic stars that arc into the truck, where the original box is stowed. No carry or return button is needed. Collecting the whole load restores the truck in place. Approach it and press **X** / tap **ENTER**, finish any remaining purple markers in arcade mode, then stop at the signed gold collection bay (blue square on GPS). An incomplete visit displays the exact packages still needed; rolling through cannot finish. Replay resets the route. Larger quotas remain in the stage data for future development; this demo ends after one delivery. Route reset cannot bypass recovery. Legacy delivery regression fixtures retain their original collection rules, but normal Zen play does not run that mission.

Repeated scraping or pushing against the same obstacle counts as one crash. Separate from the obstacle and move clear before the next crash can count. A heavy impact can still tip the truck; settle it and press U / tap RECOVER to recover while energy remains. In delivery stages, permanent disable and cargo release use depleted energy. The older isolated driving tests retain their three-rollover damage rule.

In the exploration maps, high-speed curb strikes can launch the truck: cross a raised sidewalk at about **50 mph or more**, with a substantial crossing angle. Delivery Mayhem's lower speed cap keeps ordinary curb crossings as suspension bumps. Both modes retain shared terrain and physical collisions; energy depletion is specific to Delivery Mayhem. Landings follow momentum and contact physics, ranging from upright impacts to forward tumbles or flips; hard landings drain the life bar in Delivery Mayhem. See [curb-jump behavior and tests](docs/CURB_JUMPS.md).

Off-road tires kick up procedural grass cuttings, soil chips and small dust puffs; pavement and airborne tires stop new spray. Skid tracks remain separate and fade after seven seconds. Dirt, sand, splash and snow profiles are ready for future tagged terrain; those new terrain areas are not added to the current maps. See [terrain spray](docs/TERRAIN_SPRAY.md).

**Delivery Mayhem controls:** MOVE / WASD / arrows guide the truck and worker in screen directions. Releasing movement stops the truck. X / WALK exits; stand beside the repaired truck and use X / ENTER to get back in. VIEW / C changes distance, GPS / M opens the map, SETUP / Tab opens settings, and Esc pauses. Shift / RUN sprints on foot; U / RECOVER rights a settled truck, B sounds the horn, and F refuels while stopped. Ignition, parking brake and cruise are automatic or unavailable in this mode. Rotation/resizing reflows the UI.

**Zen phone/tablet controls:** the left stick steers; pulling down selects reverse and pushing up selects forward. The visible GEAR: D / GEAR: R button also switches direction. GAS drives the selected direction and changes its label to REVERSE in R. Reverse intent overrides a gas finger already held, brakes forward motion first, then reverses; recentering/releasing the stick keeps the selected gear. BRAKE / REV still stops and reverses when held at a standstill. HANDBRAKE drifts. Steering and pedals support separate simultaneous fingers. On foot the stick moves and RUN sprints. CAMERA, GPS MAP, OPTIONS and EXIT/ENTER are touch controls. Vehicle functions and audio levels are under OPTIONS.

Re-entering the truck: on desktop/browser, walk beside the truck (within 5 m of its center) and press **X**. On phone/tablet, stand beside it and tap **ENTER**. In Delivery Mayhem, a disabled truck stays locked until every dropped package is collected. Once repaired, the HUD shows the entry control persistently; a small **[X] ENTER TRUCK** badge appears on desktop only while entry is available nearby. Walking away changes the objective to the truck distance and entry instructions. No package deposit at the truck is required.

**Zen desktop controls:** WASD/arrows drive/walk; Space handbrake; C camera; X exit/enter; Shift run; walk-over automatic package pickup; U right a settled truck; R reset; Esc pause; Tab dashboard/audio; M map. Q/E indicators, H hazards, L lights, K high beam, I ignition, P parking brake, T cruise, B horn, F refuel while stopped in the truck. Speed is mph, distance miles, fuel US gallons.

In **Delivery Mayhem**, swipes, mouse drags, mouse wheel and Q/E cannot rotate or tilt the street-aligned view. Driving and walking up/down/left/right stay aligned with the screen, including after leaving or re-entering a turned truck. Foreground buildings and tree crowns cut away when they cover the player or nearby pickup ground; low building footprints and collisions stay intact. A truck that hides the worker temporarily shows its low outline while remaining solid. Direction markers lead to the next route gate, loose package, repaired truck or collection stop.

In **Zen Drive**, driving and on-foot cameras retain orbit and tilt: drag clear world space with either mouse button, wheel to zoom, G to recenter. On touchscreens, swipe world space, tap CAMERA to cycle presets or hold to recenter. Dragging from cockpit switches to external chase. Q/E also orbit on foot. The worker starts in Travel view with forward look-ahead. Cameras avoid solid walls; exit placement rejects barrier tops and vehicle roofs. See [camera behavior](docs/NOTIFICATIONS_AND_CAMERA.md).

On foot, the nearest loose package has a numbered gold marker and distance; a directional arrow points toward it outside the view. The GPS also marks the remaining load. Traffic can still bump the physical boxes, but sustained rides on cars, distant boxes and stranded boxes are audited and returned to clear, walkable ground near the original spill, on the same road level. The original package and ID are preserved: recovery never creates extra cargo or changes the quota. A short notice announces each relocation. The audits are staggered to limit physics query cost.

The worker's normal locomotion uses 48 drawn poses: twelve each for front, back, left and right. Playback follows walking speed (about 18 pose changes/sec at normal speed). The head pivot and floor line are registered without stretching individual frames; no whole-body bob/tilt or crossfade supplies the walk motion. Desktop and mobile use these same atlases. `--presentation-check --walk-review` records real-input footage for both layouts; see `docs/WORKER_WALK_ART.md` for source assets and prompts.

Downtown has a route pool of 48 pedestrians using eight supplied lineup designs, and 30 vehicles using fourteen modeled reference types. Sixteen citizens and six cars populate the approach; others occupy mapped downtown routes. Nearby simulation is bounded by distance. Citizens react to impacts, tumble/bounce safely, recover and resume. See [docs/CITY_LIFE.md](docs/CITY_LIFE.md) for scope, art provenance and limits. Walk-over pickup credits a box immediately; approaching the truck rear is never required. Gameplay notices use a brief HUD line. Recovery appears only while currently needed, without a large modal over the road.

## Develop locally

Character art direction is locked in [docs/CHARACTER_STANDARD.md](docs/CHARACTER_STANDARD.md): the existing driver defines the shared illustration style for every human and extraterrestrial citizen, with varied bodies/outfits, consistent animation and scale conventions, and nonlethal cartoon recovery. The document also separates the future pedestrian system from the currently implemented driver and vehicle traffic.

Open `project.godot` in **Godot 4.5.1 Standard** (GDScript, Compatibility renderer). The original development PC also has `Launch Demo.cmd`, `Launch Zen Drive.cmd`, the legacy `Launch Independence.cmd`, and `Open Editor.cmd`; its portable engine is excluded from Git.

The two game launchers prepare changed assets before opening the game. This also rebuilds imports when launching a source mirror from D: or another folder; the machine-specific `.godot` cache is not backed up. Startup import logs are under `tools/startup-import*.log`. Reopen an already-running game after an update.

Browser export:

```sh
python tools/download_web_templates.py
godot --headless --editor --import --quit
godot --headless --script tools/export_licenses.gd
godot --headless --export-release Web build/web/index.html
python tools/package_web.py
python -m http.server 8765 --directory build/web
```

Visit http://localhost:8765. Serve the entire export folder; opening `index.html` directly from disk will not work. The official **web_nothreads_release.zip** avoids cross-origin isolation headers on Pages. Reference sheets, source `.blend`, raw XML map extracts and tools are excluded from the game export.

## GitHub Pages

Repository **Settings → Pages → Build and deployment → Source: GitHub Actions**. `.github/workflows/pages.yml` imports assets, runs the delivery test, exports the browser game, and deploys Pages on pushes to `main`. It downloads pinned Godot 4.5.1 and the single-thread template. The deployment job reports the playable URL.

## Validation

```sh
godot --headless --fixed-fps 60 -- --delivery-test
godot --headless --fixed-fps 60 -- --arcade-test
godot --headless --fixed-fps 60 -- --stunt-test
godot --headless --fixed-fps 60 -- --zen-test
godot --headless --fixed-fps 60 -- --outerbelt --zen-test
godot --headless --fixed-fps 60 -- --zen-switch-test
godot --headless --fixed-fps 60 -- --outerbelt-test --safety
```

The exploration delivery test exercises the barrel gateway, separate physical impacts, secured cargo while energy remains, one fixed spill when the life bar empties, no later spawning, automatic sparkle pickups without duplicate counts, exact remaining-package checkpoint messages, repaired truck re-entry, a stopped delivery finish, solid pedestrian/truck contact, responsive menu bounds and simultaneous touch actions including actual reverse motion. It also checks PC/phone camera visibility and recenter controls, safe exit height, and recovery of packages carried by traffic or stranded far away, above or below the road without changing IDs or quota. `--outerbelt --delivery-test` checks the motorway mission too. `--arcade-test` adds screen-direction driving, release braking, U-turns, fixed-camera framing and a continuous input-driven route lap; separate checkpoint fixtures isolate rejection, cargo and replay states. These checks cover control behavior rather than proving human usability. `--presentation-check --foot-access-review` captures exploration Travel/Wide/Survey and package guidance in desktop, portrait and landscape layouts. `--presentation-check` captures the finished menus, city and worker and records native render timings. `tools/browser_smoke.cjs --hardware` checks the exported game, illustrated loader, responsive layouts and simultaneous touch controls in Chrome with Playwright under `tools/webqa`.

Cleveland is a stylized flat street/building blockout derived from OpenStreetMap, with simplified access and traffic rules. Motorway elevations are estimates. Maps are © OpenStreetMap contributors, ODbL 1.0; see `assets/maps/README.md`. Engine and asset notices: `web/THIRD_PARTY_NOTICES.md`, `docs/ASSETS_AND_LICENSES.md`.

On the original PC, `python tools/sync_external.py --watch` maintains the verified, versioned mirror at `D:\FedUp Driver`. Previous changed files are preserved in `.history`; deletions are not propagated. This local backup tool is separate from the browser game. Status: `docs/external-sync-status.json`.

`python tools/save_state.py --message "Describe the change"` imports and checks both missions and map switching, stamps a source build ID, commits, exports the local browser version, verifies the D: mirror, pushes GitHub, and waits for the live Pages build to match. `--watch` performs that workflow after source files have stopped changing for 20 seconds. Failed checks leave the previous online build available. Check `docs/save-state-status.json` for the exact phase and build ID. The online `version.json` identifies the deployed source state and Git commit. The watcher runs while its process remains open; start it again after restarting the PC.

Browser exports use build-specific engine, game-pack and audio-worklet filenames to avoid mixing old cached game code with a new loader. `node tools/browser_controls.cjs <demo-url>` exercises the exploration held-gas reverse and all twelve walk-over pickups away from the truck through actual browser touch/keyboard input in portrait, landscape, tablet and PC layouts. Its `?qa=controls` fixture is opt-in and absent from ordinary play. `node tools/browser_arcade.cjs <demo-url>` covers Delivery Mayhem's directional driving and continuous route lap in the same four layouts, plus pickup and replay states. Automated emulation is not physical-phone or human playtesting.

The exploration mobile interface uses a dedicated illustrated dashboard with live mph/RPM/fuel instruments, warning lights, a steering wheel and ribbed pedals. Delivery Mayhem keeps the FedUp trim and palette with a single MOVE stick and its compact mission controls. Landscape is recommended; portrait remains fully supported without forced rotation. See [mobile dashboard details](docs/MOBILE_DASHBOARD.md).
