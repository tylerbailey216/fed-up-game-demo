# FedUp universal character standard

Locked creative direction, November 17, 2026. Applies to all pedestrian characters, human and extraterrestrial, across the native PC demo and phone/tablet browser versions.

## Master reference

The user's established FedUp delivery driver defines the cast's illustration style. Use the original supplied `FedUp Delivery Worker Sprite Sheet.png` when available and the shipping artwork in `assets/art/presentation/worker-animations.png`, `worker-front-back.png`, and `worker-walk-{front,back,left,right}.png`. The current walk registration is `data/worker_walk.json`; artwork provenance is documented in [WORKER_WALK_ART.md](WORKER_WALK_ART.md).

Every new character must look as though the same artist created it for this game. The existing references are sufficient to guide production artwork; generic stock characters and placeholder silhouettes do not satisfy this standard. Preserve attribution: the original character design is supplied by the user, and the existing expanded animation atlases are AI-assisted extensions of that artwork.

## Shared visual language

The November 17 user-supplied `FedUp Pedestrian Character Lineup.png` is preserved without pixel changes at `assets/source/style/pedestrian-character-lineup.png`. It is the cast design reference for new citizens: retain each selected character's identity, outfit, colors and proportions while extending the established driver animation conventions. The current two citizen atlases predate this lineup and are not conversions of those designs. Use the supplied lineup for the next cast expansion; do not represent recolored existing citizens as newly authored designs from it.

- Exaggerated, compact cartoon proportions with a strong, readable silhouette.
- Bold, clean black outlines; match their visual weight to the driver at the same on-screen scale.
- Flat color areas and consistent cel shading, with the driver's treatment of highlights and shadows.
- Expressive eyes, simplified noses and restrained facial detail.
- Consistent construction of hands, footwear, clothing folds and accessories.
- The same finish and illustration quality for every citizen, including background NPCs.

Vary species, age, ethnicity, skin tone, height, weight, build, clothes, accessories and personality. Include children, adults and seniors, and slender, stocky, muscular and heavyset characters. Casual clothing, business attire, workwear, uniforms and costumes all belong in this world. Identity should read through shape, clothing and behavior as well as color.

Extraterrestrials may have different head shapes, ears, eyes, limbs, antennae and skin colors while keeping the same outline, shading and cartoon visual language. They are ordinary citizens: commuters, shoppers, workers and neighbors. Species does not automatically assign an enemy role or special encounter, and does not change collision or recovery rules.

## Shared animation framework

All future NPCs use these semantic states, with personality-specific drawings and timing:

| State names | Required behavior |
| --- | --- |
| `idle`, `walk`, `run`, `turn`, `wait` | Rest, travel, face a new direction and wait at crossings or queues. |
| `surprise`, `hit` | Readable interruption and a comical reaction to nearby chaos or contact. |
| `tumble`, `bounce`, `land` | Nonlethal cartoon motion with a clear landing. |
| `recover` | Stand up, dust off or react, then return to normal activity. |
| `carry`, `interact` | Hold ordinary belongings and interact with props or the environment. |

Directional names are `front`, `back`, `left`, `right`, relative to the camera: front faces the viewer, back faces away. Clip keys follow the existing `walk_front` convention, using `<state>_<direction>` where directional artwork is needed. Turning must select the corresponding drawing, rather than rotating a flat character to fake another viewing direction. Do not mirror readable text, asymmetric outfits or accessories.

Walking needs a complete articulated gait: contact, weight transfer, passing and opposite-foot contact, with both legs and arms exchanging roles. The driver's twelve separately drawn poses per direction are the quality baseline. Whole-sprite repositioning, rocking, stretching or changing viewing angles cannot substitute for drawn animation frames. Run, reactions and recovery must communicate their own action clearly; an animation state name alone does not make that artwork complete. Drive locomotion cadence from actual travel so blocked characters stop marching in place.

## Asset integration and scale

Frame and atlas dimensions may differ between characters. A tall alien, short senior and stocky worker must retain their intended proportions and relative world heights.

Each character's animation metadata must identify the texture, clip/state and direction, ordered frame regions, frame pivots/ground baseline, reference drawing height, intended world height, timing/stride and loop behavior. Use a consistent ground contact origin and a fixed scale for that character across its clips. Transparent padding can vary; body scale cannot pulse between frames. Do not stretch each pose independently to fill a uniform rectangle. Preserve complete silhouettes, including boots, hats, antennae and accessories.

Collision dimensions follow the intended body size, separately from transparent image bounds. Use shared animation naming, directional selection and recovery logic rather than platform-specific character variants. PC, phone and tablet use the same character assets and behavior; camera/HUD reflow and measured rendering optimizations may differ without degrading the art.

## Cartoon collision and recovery rules

Human and extraterrestrial NPCs follow the same indestructible cartoon rules. Contact can cause surprise, a safe launch, tumble, bounce or slide, followed by landing, recovery and a return to their routine. No blood, visible injury, death or permanent incapacitation. Age, species and appearance do not change these rules. Pedestrian contact does not award points, kills or mission progress; deliveries and package recovery remain the objective.

The common behavior sequence is normal activity -> collision reaction -> cartoon motion -> landing -> recovery -> resume activity. Use a brief recovery cooldown so repeated contacts cannot trap a citizen in a reaction loop. Remember the interrupted destination/activity, rejoin a reachable sidewalk or crossing, and safely relocate near the route if recovery becomes blocked. Civilian vehicles should similarly recover and resume traffic after comic spins or skids. Props can scatter and cause further reactions, within measured performance budgets.

The player's delivery truck uses the current life-bar rule: distinct impacts drain energy according to severity; zero energy disables it and releases the fixed load once. Collecting every required package restores it. This supersedes the earlier three-distinct-crash rule and first-collision spill example. Package recovery must preserve IDs and quota and remain possible after traffic interactions.

## Review before adding a citizen to the game

- Compare the full character alongside the driver at the intended gameplay scale, in the same lighting and camera view. Match line weight, shading, proportions and detail quality.
- Review all four directions, a complete walk/run cycle, and collision-to-recovery transitions for readable poses, ground alignment and frame continuity.
- Check tall, short and wide silhouettes for clipping and correct collision dimensions, without normalizing their heights to the driver.
- Verify phone portrait, phone landscape, tablet and PC readability using the same artwork and behavior.
- Check interrupted crossings, repeated contact, blocked recovery, vehicle displacement and package completion; tune active population/reaction budgets from actual performance measurements.

## Implementation status and next gameplay slice

This document locks the character design and behavior requirements. The current slice ships eight illustrated lineup identities with four-direction twelve-frame walking, surprise, safe physical tumbling/bouncing, recovery and route resumption. Forty-eight citizens occupy approach and mapped downtown walking routes, with a nearby simulation budget. See [CITY_LIFE.md](CITY_LIFE.md) for assets, prompts, testing and limits. The complete future framework, including dedicated running/turning, signal-controlled crossings and item interaction/carrying animations for citizens, remains unfinished; neither citizen nor driver runtime implements every future state listed above.

The entrance now has the initial busy local block, civilian cars, citizens, crossing signals and movable construction barrels. Continue reviewing the full recovery loop and measured performance before spreading dense crowds across the full mapped downtown. Population budgets are tuning choices, not guaranteed device limits. Incident reports and additional chain reactions remain optional later features.

## Version parity

Maintain one source project and one set of character assets. Use `tools/save_state.py` to validate, commit, export, mirror `D:\FedUp Driver`, publish GitHub Pages and verify the same source build ID online. Imported Godot caches and platform executables may differ; shipped character artwork, rules and saved source state must match. Reopen a running game or reload the browser to load a newly published version.
