# FedUp Driver — Cleveland browser demo

One Godot 4.5.1 project for desktop, phone and tablet browsers. The world renders at the screen's aspect ratio and the HUD reflows; portrait play does not stretch the original cockpit artwork.

**Play:** https://tylerbailey216.github.io/fed-up-game-demo/

The link becomes available after GitHub Pages is enabled and the first **Build and publish browser demo** workflow succeeds. The repository contains source; the Pages link runs the exported game. A WebGL 2 / WebAssembly browser is required. First load downloads approximately 43 MB. Physical iPhone/Android performance still needs device testing.

## Play

Choose **Train / Public Square, Cleveland**. Follow the training ring, take the right exit about 75 meters ahead of spawn, and push past orange barrels into downtown. Public Square and a stylized Terminal Tower/Tower City are included. Independence's I-480/I-77 motorway remains a separate menu option. Older fictional city maps are no longer offered in the menu.

After the first collision outside training, rear doors open and packages spill out. Six boxes eject immediately; the remaining loose cargo drops along your route. Drive slowly near boxes to recover them. Stop and exit to collect on foot. Repeated impacts or three rollovers disable the truck, forcing foot collection. Carry one box at a time back to the truck or purple Cleveland depot. Recover all twelve to finish; route reset cannot bypass recovery.

Phone/tablet: left stick steers; GAS/BRAKE on the right; HANDBRAKE drifts. Steering and pedals support separate simultaneous fingers. On foot the stick moves and RUN sprints. CAMERA, GPS MAP, OPTIONS and EXIT/ENTER are touch controls. Vehicle functions and audio levels are under OPTIONS. Rotation/resizing reflows the UI.

Desktop: WASD/arrows drive/walk; Space handbrake; C camera; X exit/enter; Shift run; U right a settled truck; R reset before spilling cargo; Esc pause; Tab dashboard/audio; M map. Q/E indicators, H hazards, L lights, K high beam, I ignition, P parking brake, T cruise, B horn, F refuel while stopped. Speed is mph, distance miles, fuel US gallons.

## Develop locally

Open `project.godot` in **Godot 4.5.1 Standard** (GDScript, Compatibility renderer). The original development PC also has `Launch Demo.cmd`, `Launch Independence.cmd` and `Open Editor.cmd`; its portable engine is excluded from Git.

Browser export:

```sh
python tools/download_web_templates.py
godot --headless --editor --import --quit
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

The delivery test exercises the barrel gateway, first physical collision, opening doors, recovery, damage-triggered foot mode, walking, completion, responsive menu bounds and simultaneous touch actions. `--delivery-capture` saves desktop/portrait/tablet screenshots. `tools/browser_smoke.cjs` tests the exported game in Chrome with Playwright under `tools/webqa`.

Cleveland is a stylized flat street/building blockout derived from OpenStreetMap, with simplified access and traffic rules. Motorway elevations are estimates. Maps are © OpenStreetMap contributors, ODbL 1.0; see `assets/maps/README.md`. Engine and asset notices: `web/THIRD_PARTY_NOTICES.md`, `docs/ASSETS_AND_LICENSES.md`.

On the original PC, `python tools/sync_external.py --watch` maintains the verified, versioned mirror at `D:\FedUp Driver`. Previous changed files are preserved in `.history`; deletions are not propagated. This local backup tool is separate from the browser game. Status: `docs/external-sync-status.json`.
