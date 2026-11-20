# Zen Drive

Zen Drive is one relaxed driving mode with connected **City Streets** and **Open Road** scenery. The larger downtown and motorway environments are preserved. Main menus expose Delivery Mayhem and Zen Drive; geographic names remain in road signs and map attribution where useful.

## Drive between areas

Follow the cyan dot on GPS and the gold/purple overhead gateway signs. In City Streets, follow Ontario Street southeast to **OPEN ROAD**. In Open Road, follow northbound I-77 to **CITY STREETS**. Drive forward through the signed gateway on its own carriageway. Wrong-way crossings, other elevations, adjacent terrain and fixture teleports cannot activate it.

The gateway briefly displays a branded loading screen and replaces the current scenery. Only one large environment is loaded at a time. Receiving locations use the correct inbound carriageway, facing away from the exit trigger. Fuel, mileage, lighting/indicator settings, ignition/parking state and cockpit/orbit settings carry across; arrival speed is limited for its receiving road. This is connected zone travel, not a physically merged Cleveland-to-Independence road reconstruction.

City starts and manual resets use a real downtown street, bypassing the training-barrel requirement. The old training geometry remains intact.

## Relaxed rules, shared world

- No delivery timer, route quota, cargo spill, collection bay or permanent truck damage.
- Physical traffic, solid obstacles, nonlethal pedestrian reactions, curb suspension/jumps, terrain spray and fading tire tracks remain.
- The city retains its existing thirty-car and forty-eight-citizen pools. Zen reduces car/strolling pace, adds headway and yielding, and suppresses automatic stuck-car honking. Player horns and collision audio remain.
- Open Road has twelve physical reference vehicles following the four existing one-way mainlines. Cars do not reverse to loop at extract boundaries: endpoint recycling is allowed only away from the player with clear receiving space. Pedestrians remain on city routes.
- Settled rollovers receive help after a short wait. Empty fuel or unexpected disable does not end a drive. Intentional ignition-off and parking-brake choices are respected. Settings include a roadside-service action; it waits for airborne/tumbling motion to settle.

## Controls

Zen retains simulator driving, separate gas/brake, true reverse, handbrake, ignition, lights, indicators, cruise and fuel. Desktop WASD/arrows drive; S brakes and then reverses. Touch uses steering and pedals with independent fingers; D/R or vertical stick intent selects direction, and GAS drives it. The brake pedal also stops then reverses.

C / VIEW cycles cockpit, chase and raised views. Drag clear road space to orbit/tilt; wheel zooms; G / hold VIEW recenters. X / WALK exits while stopped; stand beside the solid truck and press X / ENTER to drive again. No package recovery is required in Zen. M / GPS expands the map; N shows connecting-road guidance; Tab / SETUP opens settings; Esc pauses.

Delivery Mayhem keeps its screen-relative directional controls, fixed street-aligned camera, energy bar, single fixed-quota spill and route/finish rules. The old city/motorway delivery validation fixtures intentionally retain their original missions; these are not normal Zen gameplay.

## Verification

`--zen-test` and `--outerbelt --zen-test` exercise live population, real gas/coasting/reverse, physical wall contact, mission guards, service, a settled physical rollover, walking and X re-entry. `--zen-switch-test` / `--location-switch-test` set up on each approach once, then drive both gateways with normal gas input and verify road support, lane-correct arrivals and carried vehicle/camera state. Wrong-way, wrong-height and off-road gate rejection are separate checks.

`node tools/browser_zen.cjs http://127.0.0.1:8766/` uses the opt-in `?qa=zen` fixture for actual menu, keyboard/touch, reverse, camera, walking and both drive-through transitions at phone portrait/landscape, tablet and desktop sizes. Emulated layouts do not replace physical phone performance/playtesting. The stable save workflow validates both modes and mirrors the same build ID to D: and GitHub Pages.

On November 20, native city/open-road policy tests and both input-driven gateway crossings passed. Browser gameplay checks completed at 360x640, 844x390, 768x1024 and 1280x720, including actual menu start, gas/reverse, orbit, walking/re-entry and city ? open road ? city travel without browser errors. The UI retains the existing illustrated cabin assets and reflow behavior.
