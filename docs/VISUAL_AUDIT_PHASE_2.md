# Phase 2 visual consistency audit

November 22, 2026. Baseline: build `cf6104148265`, commit `fde023c3a85bc3b8cf23a3397ec8a8e313688265`. Work branch: `polish/visual-consistency-20261122`. This is a presentation pass; map layout, driving, cameras, cargo rules and population remain intact.

## References and findings

Reviewed the original Driving Simulator Asset/UI sheets, cockpit reference, vehicle look sheet and pedestrian lineup against actual game captures. The driver remains the cast's master reference. Original designs, atlases, models and their documented provenance were preserved. No new image generation or bitmap processing was used.

| Area | Finding | This pass |
| --- | --- | --- |
| Mayhem architecture | Ribbon windows and uninked corners looked unfinished next to illustrated vehicles. | Warm vertical mullions and narrow dark corner edges, merged into each existing cutaway facade batch. |
| City Streets architecture | Long glass stripes lacked the reference's separated planes and window grids. | Window bays, corner ink and roofline accents in existing vertex-color chunks. |
| Open Road buildings | Mixed visual face orientation exposed the inverted-hull ink pass as filled black walls. | Correct outward visual winding/normals, warm roofs, inset window bays and restrained trim. Original collision faces are retained separately. |
| Sidewalks | Large unbroken slabs lacked surface scale and readable curb edges. | Expansion seams and light curb caps, in existing sidewalk visual batches. Paint adds no collision faces. |
| Vegetation | Repeated smooth rugby-ball crowns contrasted with the illustrated cast. | Deterministically irregular, faceted crowns using the original triangle and instance counts. No trunk collision, vegetation sensing or LOD changes. |
| HUD and signs | Installed system fonts differed between machines and from touch/menu typography. Arcade still said “Driving Simulator.” | Existing bundled Barlow and Bangers faces throughout the desktop HUD and Barlow on road signs; Delivery Mayhem branding matches its mode. Touch layout and illustrated cockpit assets retained. |
| Characters and vehicles | Selected identities, outfits and proportions broadly follow the supplied lineups. Enlarged NPC ink/detail is softer than the driver. | Source artwork and scale left intact; specific artist work recorded below. |

## Before and after

These use the same capture tool and camera positions at 1280×720. Population is frozen for inspection after initial settling; they are visual fixtures, not evidence of driving a route.

| Environment | Before | After |
| --- | --- | --- |
| Delivery Mayhem | [Before](phase2-review/before-arcade-1280x720.png) | [After](phase2-review/after-arcade-1280x720.png) |
| City Streets cockpit | [Before](phase2-review/before-city-1280x720.png) | [After](phase2-review/after-city-1280x720.png) |
| Open Road chase | [Before](phase2-review/before-open-road-1280x720.png) | [After](phase2-review/after-open-road-1280x720.png) |

Additional inspection: [current cast beside the driver](phase2-review/cast-comparison.png), [repaired industrial facades](phase2-review/open-road-facade-inspection.png), [Mayhem portrait](phase2-review/arcade-portrait.png), [City Streets portrait](phase2-review/city-portrait.png).

[The earlier browser capture showing black facades](phase2-review/initial-black-facades.png) identifies the defect. Its camera differs from the repaired close-up; those two are not a matched before/after pair. The character gallery uses a posed inspection camera and existing resting walk frames, without changing normal gameplay cameras or character proportions.

## Work requiring source artwork

1. **Citizen line cleanup.** In the [cast comparison](phase2-review/cast-comparison.png), preserve the commuter, senior and alien identities while bringing ink sharpness, outline weight, faces and small outfit details to the driver's standard. Both renderer paths already use the same linear/mipmap filtering; changing filtering cannot restore missing drawn detail. An approved cleanup of source frames is preferable to a blanket sharpening or outline effect.
2. **Foliage and ground detail.** [City Streets](phase2-review/after-city-1280x720.png) still uses abstract 3D crowns and broad flat grass areas. Artist-authored leaf clusters, branch contours and a restrained ground-detail sheet would bring these closer to the hand-drawn reference. Current geometry is a lightweight stylized representation, not finished leaf illustration.
3. **Distinctive building surfaces.** [Industrial facades](phase2-review/open-road-facade-inspection.png) are clearer but remain simple geometric forms. Authored storefronts, roof treatments and selected wall/door artwork would add identity without adding more city geometry. Keep the current solid footprints and cutaway conventions.
4. **Dedicated character action drawings.** Resting walk frames are still used while stopped. Dedicated idle, run, carry/interact and some turning states remain future artwork/runtime work under `CHARACTER_STANDARD.md`; this pass does not claim to implement that framework.

Do not replace original character art or alter established body proportions to address these items. Review artist work against the driver at gameplay scale before integrating it across all platforms.

## Rendering budget and validation

Native Compatibility captures on Intel UHD 620 retained the same draw counts at matched views: Mayhem 188, City Streets 281 and Open Road 363 calls at 1280×720. Visible primitives changed from 44,083 to about 45,200; 120,082 to 136,544; and 178,780 to 179,004 respectively. Extra facade/sidewalk triangles reuse existing batches. These are scene samples, not an FPS or device-performance guarantee. Flat crown normals duplicate some vertices although crown triangle counts stay constant; sustained GPU/frame-pacing checks remain part of device QA.

`--scenery-test` passes outward-winding checks on all 137 Open Road facades and verifies that their base visual faces still match the original collision triangle set, independent of the physics engine's face ordering. It is included in the verified save workflow and CI alongside existing driving, curb, cargo, terrain and Zen checks.

Chrome's four Mayhem layout checks passed at 360×640, 844×390, 768×1024 and 1280×720: actual touch/keyboard curb returns, automatic package credit, checkpoint/completion feedback, responsive report and replay, with no graphics/page errors reported. Short initial RAF samples measured approximately 52.5, 60.0, 60.0 and 56.3 FPS respectively. These samples are not controlled before/after benchmarks or sustained device measurements.

Zen's 360×640 browser check also passed actual menu input, gas/true reverse, orbit camera, walking/re-entry and City Streets → Open Road → City Streets driving, with no browser/graphics errors reported.

Publication is gated by all 14 native checks in `tools/save_state.py`, including the new facade regression, seven arcade curb round trips, the City Streets reverse return, cargo recovery, terrain/tracks, stunts, both Zen environments and zone/mode transfers. The saved identity is recorded in [data/build_version.json](../data/build_version.json); the workflow records matching local, D: and live Pages IDs in `docs/save-state-status.json` before synchronization is reported. Physical iPhone/Android testing and the previously documented intermittent WebGL startup issue remain separate QA items.

## Implementation map

- `scripts/arcade_world.gd`, `scripts/downtown.gd`, `scripts/independence.gd`: batched architectural finish and Open Road visual correction.
- `scripts/street_surfaces.gd`: visual-only seam/cap paint over unchanged physical sidewalks.
- `scripts/foliage_mesh.gd`, `scripts/highway.gd`: shared deterministic crown contour/flat shading; existing instances and colliders retained.
- `scripts/cockpit.gd`: bundled desktop typography and mode branding.
- `scripts/art_review.gd`, `tools/capture_art_review.py`: reproducible opt-in scene/gallery captures, one game instance at a time.
- `scripts/scenery_checks.gd`, `scripts/main.gd`, `tools/save_state.py`, `.github/workflows/pages.yml`: facade regression entry point and required verification.

Reproduce captures with `python tools/capture_art_review.py` (or `--zone arcade`, `city`, `open-road`). Use `--before` only when running the preserved baseline source; the flag labels captures and does not undo art changes.
