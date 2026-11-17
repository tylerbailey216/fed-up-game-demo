# Populated approach and automatic recovery

The downtown entrance was visually empty because all eight cars followed a long mapped circuit hundreds of meters beyond the orange barrels, and pedestrians did not exist. The current build adds a connected local street loop along the approach with six cars, crossing stripes, sidewalks, a signal and six movable barrels. Eight cars continue on the mapped downtown route. Twelve citizens populate the approach and four use the mapped Public Square footway. Pedestrians are visible near the entrance rather than only deep in the city.

## Character artwork

The built-in ImageGen tool created two finished citizen atlases using `assets/art/presentation/worker-walk-front.png` as the reference for the user's established driver style. These are AI-assisted additions to that supplied character aesthetic, not artwork claimed to have been drawn by the user.

- `assets/art/presentation/citizen-commuter.png`: a Black woman with curly bun, teal commuter jacket, cream shirt, indigo jeans and white/orange sneakers; intended world height 1.85 m.
- `assets/art/presentation/citizen-office-alien.png`: a short mint-green extraterrestrial office commuter with antennae, navy suit, coral tie and brown shoes; intended world height 1.55 m.

The PNGs have real alpha transparency and remain unedited. Both are 793 x 1983 pixels. Each citizen uses 48 separately drawn walking poses: twelve each front/back/left/right, plus twelve directional surprise, tucked tumble and recovery drawings. The alien source also contains an extra right-walk row which the runtime does not select. `tools/register_citizens.py` inspects alpha and records regions, shared row ground lines and clip reference heights in `data/citizens.json`; it does not edit pixels. It preserves complete silhouettes and uses fixed world height per character rather than stretching every frame. The exact final built-in prompts are in [CITIZEN_ART_PROMPTS.json](CITIZEN_ART_PROMPTS.json).

This first slice uses two citizen designs in repeated instances. A broader cast with more outfits, ages and body types remains future work under [CHARACTER_STANDARD.md](CHARACTER_STANDARD.md).

## Movement and reactions

`scripts/citizen.gd` implements lightweight CharacterBody movement on a known foot route. Walking phase follows real travel through the twelve drawings; waiting uses a resting pose. Citizens choose front/back/left/right relative to the active camera. No whole-sprite rocking supplies normal walking motion.

Citizens wait for the signal before beginning long crossing segments. Civilian vehicle forward sensing can see their collision bodies. Vehicle and moving-barrel contact can trigger a capped cartoon launch, a tucked reaction drawing, one bounce, a recovery pose and a return to the interrupted route. Nearby truck impacts can cause a surprise reaction. Cooldowns prevent repeated launches during recovery. Blocked or out-of-bounds citizens rejoin a known route point. Humans and aliens have identical reaction/recovery rules, no health/death states and no collision score rewards. The delivery truck retains its third-distinct-crash damage/cargo rule.

Citizens within 220 m of the truck update normally; distant normal activity is hidden and paused. A distant active reaction is allowed to finish. These are provisional performance choices, not a physical-phone performance guarantee. The current population is deliberately bounded at 16 citizens and 14 cars; it is not a complete city population simulation. Dedicated run/turn/carry/interaction animation clips and more varied civilian vehicle behaviors remain future work.

## Pickup and reverse fixes

Walk-over collection increments the collected count immediately and hides the original box. Its stars fly to the truck and stow that same box; flight completion awards no second credit. No hand-held parcel or rear-of-truck deposit is involved. A short swept foot-contact check also handles movement between physics steps. All twelve collected boxes restore the truck while presentation effects finish.

Mobile direction selection is explicit: pull the stick down or tap GEAR: R, then GAS/REVERSE drives backward after stopping forward travel. Up or GEAR: D selects forward. Selection persists while the stick recenters, so an already-held gas finger cannot override reverse. The existing BRAKE / REV hold also works. Hidden RIGHT TRUCK controls no longer intercept the gear selector.

## Validation

The delivery suite covers immediate pickup credit, no double credit, truck repair and completion, mobile reverse with gas already held, reverse after releasing only steering, the direction selector, multitouch forward steering and citizen contact/cooldown/recovery. It checks that the entrance has citizens and that the bounded population exists. Both motorway and map switching retain their existing checks.

`--presentation-check --city-life-review` captures native PC/portrait/landscape city views, a driver/citizen art comparison and bounce/recovery states. `tools/browser_controls.cjs` uses real Chrome touch/keyboard events in 360x640 (DPR 2), 844x390 (DPR 2), 768x1024 and 1280x720 layouts. The opt-in `?qa=controls` fixture places a known spill in a straight test lane, publishes engine telemetry, and verifies all twelve pickups while the worker remains more than 20 m away from the truck. It also checks held-gas reverse and matching loader/engine build IDs. It does not substitute fixture setup for the actual input assertions. Ordinary play does not expose the fixture.

Browser game files and both audio worklets now have build-specific names. The loader shows its embedded build ID rather than fetching and displaying a newer version unrelated to its running engine. This prevents mixed export files after caching; a running tab still needs reloading to enter a newly published build.

JavaScript test telemetry uses Godot's official [JavaScriptBridge](https://docs.godotengine.org/en/4.5/classes/class_javascriptbridge.html) only in the opt-in Web fixture. It is not a gameplay dependency on native PC.
