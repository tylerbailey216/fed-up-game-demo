# Delivery Mayhem

The default demo is now one compact, fictional Cleveland-inspired delivery block. It reuses the current truck, driver, supplied citizen cast, traffic fleet, illustrated dashboards, sound, collision and package effects. No new image-generation pass or replacement character art was introduced. This is an initial playable arcade route, not a claim that the final game direction or visual polish is finished.

## Round

1. Start with the twelve-box manifest secured and a full truck energy bar.
2. Drive four purple route markers in order around the roughly 400 m block. GPS marks only the next one. Walking through a marker or visiting it out of order cannot advance the driving route.
3. Drive into the gold collection bay and hold a full stop for 1.2 seconds. The bay cannot skip the route. A clean delivery is allowed.
4. If energy empties, the existing one-time twelve-box spill interrupts the route. Walk over the boxes; the existing star-return effect credits them immediately. Safety audits preserve package IDs, quota and reachability after traffic interactions.
5. Recovering the full manifest restores the truck. Walk beside it and press X on PC / tap ENTER on touchscreens. Finish the remaining markers and collection stop.
6. Dispatch reports the manifest, elapsed active play time, energy used and recovered packages, with a short humorous assessment. No score rewards collisions with citizens. ONE MORE DELIVERY clears the run and starts fresh.

There is no deadline, forced opening collision, tap-to-move system, progression beyond this round, or completed Zen mode. Those would be separate design decisions. Pause and menus stop the run timer. One recovery incident is supported per run; repairing the truck does not start an endless stream of new packages.

## World and presentation

The compact world creates only its own ground, six connecting street segments, raised sidewalks, a pocket park, modest storefronts and surrounding buildings. It does not instantiate the training ring or the full OSM downtown map. Asphalt and grass colliders carry explicit terrain identities, so tire tracks and bounded grass/dirt spray retain their existing behavior. Raised sidewalks reuse the same visible/collision bevels as downtown and remain compatible with curb jumps.

Ten physical traffic vehicles and sixteen human/alien citizens populate the block. They use the existing force-driven traffic and common nonlethal citizen reactions. This bounded population is intentionally smaller than the exploration map's thirty vehicles and forty-eight citizen pool. More density or moving obstacles should follow playtesting, not increase city scale automatically.

Arcade driving and walking share a fixed elevated map view: 45-degree world bearing and 60-degree elevation. VIEW / C switches between Play and a wider Overview with the same angle; G / hold VIEW restores Play. Movement, steering, collisions and world swipes cannot spin or tilt the camera. Walking controls remain screen-relative after truck exit or re-entry. Translations follow the player smoothly, with immediate placement on transfers and route resets. The camera centers the subject in the HUD's clear scene area, adapting distance for narrow screens without stretching the game.

Foreground buildings and tree crowns cut away when they cover the subject or nearby ground. Building facades remain merged into one draw each; collision bodies remain active and a dark raised footprint stays visible. Short visibility hysteresis reduces edge flicker. Obstruction audits use cached native bounding boxes at a bounded cadence, with immediate updates on transfers and teleports; translation still follows every frame. The parked truck similarly reveals its low outline when it covers the worker, while retaining solid collision. The camera does not lurch closer to a wall or orbit around it. These cutaways are specific to the compact arcade map; the exploration worlds keep their existing cameras and geometry.

GPS uses the compact street plan, a purple next marker, blue collection square and gold loose boxes. A matching direction marker at the gameplay edge points toward an off-screen route gate, package, truck or stop. The fictional block does not display OSM attribution as though its geometry were surveyed downtown data. The end report appears only once the truck has finished and stopped; normal gameplay retains brief notices rather than a large persistent overlay.

Public Square / Tower City and the Independence motorway remain named, selectable exploration maps. They retain their existing geometry and delivery behavior. --city selects downtown directly; --outerbelt selects the motorway. With no location argument, native and browser builds start at the Delivery Mayhem menu.

## Verification

- `--arcade-test`: fixed-camera heading/rollover stability, actual mouse/touch controls, two distance presets, screen-relative walking, responsive framing, corner/truck cutaways and intact physical collision; clean completion; early-bay, gate-order, on-foot and rolling-stop rejection; light impacts versus depleted energy; fixed one-time spill; actual contact pickup; repair/re-entry; recovered completion; replay resets.
- `--arcade-capture`: same checks plus desktop, phone portrait/landscape and tablet captures.
- `node tools/browser_arcade.cjs http://127.0.0.1:8766/`: opt-in WebAssembly fixture with real keyboard/touch acceleration, held-gas reverse, walking over the entire load, dispatch replay buttons, and screenshots at 360x640, 844x390, 768x1024 and 1280x720. Route teleports isolate gate/finish conditions; these are not an autonomous full-route driving test.
- The existing city delivery, motorway delivery, stunt, terrain and map-switch checks remain part of the stable save pipeline; arcade checks are now included too.

Browser emulation does not replace physical iPhone/Android playtesting. Frame samples describe the development PC and tested viewports, not a universal mobile performance guarantee. The same source and assets export to every layout; verified stable saves mirror through `tools/save_state.py`.

The initial arcade release's November 19 Chrome run passed all four layouts with no browser errors; its short start-view samples measured about 48-59 FPS on the Intel UHD 620 development PC at that time. Later same-machine fixed-camera comparisons showed lower frame rates in both the published chase-view build and the fixed-view build. Those measurements do not establish a new camera-specific regression or a sustained performance guarantee. `tools/browser_camera_profile.cjs` compares the same view with camera updates enabled/disabled and with population simulation paused; optimized cutaway audits measured about 0.1-0.3 ms. Native checks also sample physical ground along all six streets, verify raised sidewalk/grass identities and drive the truck with actual acceleration input. Menu-button checks traverse arcade -> city -> motorway -> arcade.
