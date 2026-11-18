# Tire terrain spray

PC, phone and tablet share the same wheel-contact emitter. Driving onto grass throws small olive cuttings, brown soil fragments and restrained dust from the tires actually touching the grass. Reversing and sliding use the real direction of movement. Returning to pavement stops new spray; airborne, parked, disabled, overturned and on-foot states do not emit it. Existing pieces finish a short arc and fade. Tire skid tracks remain independent, including their seven-second lifetime, and can appear alongside terrain spray during an off-road drift.

No image-generation service, neural model, new bitmap artwork or third-party particle texture is used for this effect. Its shard silhouettes, outlines, stepped color shading and dust lobes are code-defined meshes/shaders in the existing comic palette. This statement applies to this effect; it does not change the documented provenance of the game's existing artwork.

## Terrain contract

`terrain_surface.gd` resolves each actual static wheel-ray hit. Downtown visual roads over the shared grass floor use the indexed road footprint rather than the truck-center approximation. Raised concrete and green island tops have separate collider metadata. Motorway deck queries use cached width and height geometry, so grass below an elevated road cannot leak through. Unknown building roofs and props remain solid surfaces rather than being assumed to be grass.

A discrete future ground collider can set `terrain_kind` to `grass`, `vegetation` (grass alias), `dirt`, `sand`, `water`, `snow`, `asphalt` or `sidewalk`. Explicit metadata is authoritative: do not mark the downtown shared base as explicit grass where visual roads overlap it. Keep its existing `surface_kind=grass` fallback. Other unknown kinds emit nothing.

Current maps supply grass and paved terrain. Dirt clods/dust, finer sand, blue-white splash flecks/foam and snow/powder have selectable effect profiles and integration-test surfaces. This update does not add desert, water or snow areas to the shipping maps, or implement fluid depth, buoyancy, snow deformation or new terrain handling.

## Budget and lifecycle

The emitter reuses the four existing 20 Hz surface probes; it adds no per-particle collision queries or physics bodies. Two world-space MultiMeshes hold 384 opaque clipped shards and 96 small translucent puffs. Shards use shader-driven spin, drag and gravity, land at their sampled surface height and disappear within 0.85 seconds; puffs expire within one second. This is a visual approximation, not collision simulation of individual blades of grass. No per-fragment nodes or newly generated images accumulate.

Distance, speed and surface profile control density and throw, capped at five new shards per tire per sample. A fixed random seed supplies conventional procedural variation. Pause freezes emission and shader clocks. Reset and boundary recovery clear old pieces, while lost contact and large position jumps break the emission trail. New map scenes have new pools and a weak-reference terrain cache. CPU initialization of motorway geometry is done during map loading, rather than on its first fast off-road encounter.

## Verification

`godot --headless --fixed-fps 60 -- --terrain-test` drives actual contacts across asphalt, two grass tires, four grass tires and back to asphalt, then checks all future profiles, reverse, simultaneous skid tracks/spray, stationary expiry, pause, airborne suppression, reset and bounded pool reuse. It also audits the shipping downtown road/sidewalk/grass and green island surfaces. Add `--outerbelt` to audit elevated motorway contacts, or `--terrain-capture` to a rendered run for screenshots. Save validation and GitHub Actions run this suite; delivery, curb-jump and handling suites guard the surrounding mechanics.

`node tools/browser_terrain.cjs <local-demo-url>` tests real touch/keyboard acceleration on shipping grass and asphalt in phone portrait, phone landscape and PC layouts. It checks emission counters, profile selection, pool limits, reset cleanup and browser/shader errors, and records screenshots. Browser emulation does not establish physical iPhone/Android performance. The two small batches are bounded by design; final frame rate still depends on the full scene and device.
