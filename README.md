# FedUp Driver — Cleveland browser demo

One Godot 4.5.1 project for desktop, phone and tablet browsers. The world renders at the screen's aspect ratio and the HUD reflows; portrait play does not stretch the original cockpit artwork.

**Play:** https://tylerbailey216.github.io/fed-up-game-demo/

The repository contains source; the Pages link runs the exported game. A WebGL 2 / WebAssembly browser is required. First load downloads approximately 50 MB, including the illustrated loading artwork. Physical iPhone/Android performance still needs device testing.

## Play

Choose **Train / Public Square, Cleveland**. Follow the training ring, take the right exit about 75 meters ahead of spawn, and push past orange barrels into downtown. Public Square and a stylized Terminal Tower/Tower City are included. Independence's I-480/I-77 motorway remains a separate menu option. Older fictional city maps are no longer offered in the menu.

The first two registered collisions outside training keep the load secured. The third disables the truck, opens its rear doors and ejects the fixed load of **12 packages** once. Packages never continue leaking. Walk over a lost box to collect it automatically: it bursts into shimmering comic stars that arc into the truck, where the original box is stowed. No carry or return button is needed. Collecting the whole load restores the truck in place. Approach it and press **X** / tap **ENTER**, then drive to the signed gold collection bay on the downtown access road (blue square on GPS). Hold a full stop in the bay for 1.2 seconds to complete the demo. An incomplete visit displays the exact number of packages still needed; rolling through cannot finish. **PLAY DEMO AGAIN** resets this route. Larger quotas remain in the stage data for future development; this demo ends at the first collection point. Route reset cannot bypass recovery.

Repeated scraping, holding gas against a wall, or pushing against the same obstacle counts as one crash. Separate from the obstacle and move clear before the next crash can count. A heavy impact can still tip the truck; settle it and press U to recover after either of the first two crashes. In delivery stages, permanent disable and cargo release use the three-crash mission counter. The older isolated driving tests retain their three-rollover damage rule.

Phone/tablet: left stick steers and supports forward/reverse; GAS and BRAKE / REV on the right (hold brake at a standstill to reverse); HANDBRAKE drifts. Steering and pedals support separate simultaneous fingers. On foot the stick moves and RUN sprints. CAMERA, GPS MAP, OPTIONS and EXIT/ENTER are touch controls. Vehicle functions and audio levels are under OPTIONS. Rotation/resizing reflows the UI.

Desktop: WASD/arrows drive/walk; Space handbrake; C camera; X exit/enter; Shift run; walk-over automatic package pickup; U right a settled truck; R reset before spilling cargo; Esc pause; Tab dashboard/audio; M map. Q/E indicators, H hazards, L lights, K high beam, I ignition, P parking brake, T cruise, B horn, F refuel while stopped in the truck. Speed is mph, distance miles, fuel US gallons.

Camera: C cycles cockpit/chase/raised chase while driving and close/raised/overhead on foot. Right-drag orbits outside views; the mouse wheel zooms. Q/E orbit on foot. On touchscreens, tap the view button to cycle height and swipe unobstructed world space to orbit on foot. Cameras avoid solid walls; the foot camera raises automatically if the truck blocks the worker. The character artwork stays camera-facing and readable from high angles.

The worker's normal locomotion uses 48 drawn poses: twelve each for front, back, left and right. Playback follows walking speed (about 18 pose changes/sec at normal speed). The head pivot and floor line are registered without stretching individual frames; no whole-body bob/tilt or crossfade supplies the walk motion. Desktop and mobile use these same atlases. `--presentation-check --walk-review` records real-input footage for both layouts; see `docs/WORKER_WALK_ART.md` for source assets and prompts.

## Develop locally

Open `project.godot` in **Godot 4.5.1 Standard** (GDScript, Compatibility renderer). The original development PC also has `Launch Demo.cmd`, `Launch Independence.cmd` and `Open Editor.cmd`; its portable engine is excluded from Git.

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
godot --headless --fixed-fps 60 -- --location-switch-test
godot --headless --fixed-fps 60 -- --outerbelt-test --safety
```

The delivery test exercises the barrel gateway, three separate physical impacts, secured cargo on impacts 1–2, one fixed spill on impact 3, no later spawning, automatic sparkle pickups without duplicate counts, exact remaining-package checkpoint messages, repaired truck re-entry, a stopped delivery finish, solid pedestrian/truck contact, responsive menu bounds and simultaneous touch actions including actual reverse motion. `--outerbelt --delivery-test` checks the motorway mission too. `--presentation-check` captures the finished menus, city and worker and records native render timings. `tools/browser_smoke.cjs --hardware` checks the exported game, illustrated loader, responsive layouts and simultaneous touch controls in Chrome with Playwright under `tools/webqa`.

Cleveland is a stylized flat street/building blockout derived from OpenStreetMap, with simplified access and traffic rules. Motorway elevations are estimates. Maps are © OpenStreetMap contributors, ODbL 1.0; see `assets/maps/README.md`. Engine and asset notices: `web/THIRD_PARTY_NOTICES.md`, `docs/ASSETS_AND_LICENSES.md`.

On the original PC, `python tools/sync_external.py --watch` maintains the verified, versioned mirror at `D:\FedUp Driver`. Previous changed files are preserved in `.history`; deletions are not propagated. This local backup tool is separate from the browser game. Status: `docs/external-sync-status.json`.

`python tools/save_state.py --message "Describe the change"` imports and checks both missions and map switching, stamps a source build ID, commits, exports the local browser version, verifies the D: mirror, pushes GitHub, and waits for the live Pages build to match. `--watch` performs that workflow after source files have stopped changing for 20 seconds. Failed checks leave the previous online build available. Check `docs/save-state-status.json` for the exact phase and build ID. The online `version.json` identifies the deployed source state and Git commit. The watcher runs while its process remains open; start it again after restarting the PC.
