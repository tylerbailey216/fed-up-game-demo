# Populated approach and automatic recovery

The downtown entrance now connects to a clear West Lakeside Avenue entry instead of cutting through a mapped building. Six reference vehicles use the entrance block; 24 others occupy three connected mapped street circuits. Sixteen citizens populate the approach and 32 use sixteen mapped footway corridors around downtown. The pool is 48 citizens and 30 cars, with nearby simulation rather than all of them active everywhere.

## Character artwork

The business commuter's normal walking now uses four higher-resolution
`commuter-walk-{front,back,left,right}.png` sheets, with twelve drawings per
direction. Her surprise/tumble/recovery clips now use `commuter-reactions.png`;
see [COMMUTER_REACTION_POLISH.md](COMMUTER_REACTION_POLISH.md). Original source
atlases remain preserved. See
[COMMUTER_WALK_POLISH.md](COMMUTER_WALK_POLISH.md) for exact provenance, native
comparisons, registration and memory cost. Other citizens retain their
existing single atlases; this is not a cast-wide replacement.

The built-in ImageGen tool extended the user-supplied pedestrian lineup and established delivery driver into eight finished production atlases. These are AI-assisted adaptations of the supplied designs, not artwork claimed to have been drawn by the user. The purple business commuter, floral-shirt tourist, safety-vest construction worker, elderly woman and aliens A-D retain their lineup identities, clothes and palettes. Their individual heights and textures are registered in `data/citizen_lineup_catalog.json`.

Each current design uses 48 drawn walk poses and 12 directional reaction drawings. The fixed character reference height applies across every direction, preserving body proportions. Exact production prompts are in [LINEUP_ART_PROMPTS.json](LINEUP_ART_PROMPTS.json), with the final alien-A canvas correction in [LINEUP_ALIEN_A_V3_CORRECTION.txt](LINEUP_ALIEN_A_V3_CORRECTION.txt). No Python image editing was used; registration reads alpha bounds and writes metadata only.

## Movement and reactions

`scripts/citizen.gd` implements lightweight CharacterBody movement on a known foot route, using cached floor/wall probes during normal walking and the full collision solver during reactions. Walking phase follows real travel through the twelve drawings; waiting uses a resting pose. Citizens choose front/back/left/right relative to the active camera. No whole-sprite rocking supplies normal walking motion.

Citizens walk on sidewalk/footway corridors. The previous broad signal-direction test could leave an entire long route waiting forever; it has been removed from these walking routes. Civilian vehicle sensing can see nearby citizens. Vehicle and moving-barrel contact can trigger a capped cartoon launch, tucked drawing, bounce, recovery pose and return to the route. Nearby truck impacts cause surprise reactions. Cooldowns prevent repeated launches. Humans and aliens use identical nonlethal rules. More complex pedestrian crossings, running and social interactions remain future work.

Up to 24 citizens within 190 m of the player update normally; active reactions always finish. This follows the on-foot player as well as the truck. Distant normal citizens pause. Cars beyond 250 m freeze and hide, preserving their positions and collision state when they return. This is bounded local simulation, not a full city simulation or a physical-phone performance guarantee.

## Pickup and reverse fixes

Walk-over collection increments the collected count immediately and hides the original box. Its stars fly to the truck and stow that same box; flight completion awards no second credit. No hand-held parcel or rear-of-truck deposit is involved. A short swept foot-contact check also handles movement between physics steps. All twelve collected boxes restore the truck while presentation effects finish.

Mobile direction selection is explicit: pull the stick down or tap GEAR: R, then GAS/REVERSE drives backward after stopping forward travel. Up or GEAR: D selects forward. Selection persists while the stick recenters, so an already-held gas finger cannot override reverse. The existing BRAKE / REV hold also works. Hidden RIGHT TRUCK controls no longer intercept the gear selector.

## Validation

All fourteen supplied vehicle types have original editable Blender models under `assets/source/traffic/`, with runtime GLBs under `assets/models/traffic/`. The fleet includes the compact, sedan, taxi, pickup, SUV, delivery van, box truck, school bus, city bus, police car, ambulance, tow truck, dump truck and scooter. Bodies use one cached vertex-colored mesh plus live brakes; color and ink share wheel articulation. Axle metadata supports four wheels, the six-wheel dump truck and two-wheel scooter. Each type has its own dimensions, wheel radius and physical mass. Emergency lights, towing and bus passenger systems are visual designs rather than implemented special services. See [PERFORMANCE_BUDGETS.md](PERFORMANCE_BUDGETS.md) for measured limits.

The delivery suite covers immediate pickup credit, no double credit, truck repair and completion, mobile reverse with gas already held, reverse after releasing only steering, the direction selector, multitouch forward steering and citizen contact/cooldown/recovery. It checks that the entrance has citizens and that the bounded population exists. Both motorway and map switching retain their existing checks.

`--presentation-check --city-life-review` captures native PC/portrait/landscape city views, a driver/citizen art comparison and bounce/recovery states. `tools/browser_controls.cjs` uses real Chrome touch/keyboard events in 360x640 (DPR 2), 844x390 (DPR 2), 768x1024 and 1280x720 layouts. The opt-in `?qa=controls` fixture places a known spill in a straight test lane, publishes engine telemetry, and verifies all twelve pickups while the worker remains more than 20 m away from the truck. It also checks held-gas reverse and matching loader/engine build IDs. It does not substitute fixture setup for the actual input assertions. Ordinary play does not expose the fixture.

Browser game files and both audio worklets now have build-specific names. The loader shows its embedded build ID rather than fetching and displaying a newer version unrelated to its running engine. This prevents mixed export files after caching; a running tab still needs reloading to enter a newly published build.

JavaScript test telemetry uses Godot's official [JavaScriptBridge](https://docs.godotengine.org/en/4.5/classes/class_javascriptbridge.html) only in the opt-in Web fixture. It is not a gameplay dependency on native PC.
