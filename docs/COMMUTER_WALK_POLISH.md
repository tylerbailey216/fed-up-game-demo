# Commuter directional walking polish

November 23, 2026. Follow-up to the rejected whole-atlas cleanup in
[COMMUTER_ART_REVIEW.md](COMMUTER_ART_REVIEW.md). This pass changes the business
commuter's walking artwork only. The other seven citizens and driver are intact.

Four separate 1536 x 1024 transparent source sheets contain twelve drawings
each: `assets/art/presentation/commuter-walk-{front,back,left,right}.png`.
Built-in ImageGen extended the existing commuter and driver references, one
direction at a time. This is AI-assisted adaptation of the user's design,
not newly hand-drawn user artwork. Exact prompts: [COMMUTER_WALK_PROMPTS.json](COMMUTER_WALK_PROMPTS.json).
No Python pixel modification, sharpening or per-frame resizing was used.

## Visual review

- [Previous cast comparison](commuter-walk-review/before.png)
- [Current comparison beside the driver](commuter-walk-review/after.png)
- [All 48 imported walking drawings](commuter-walk-review/all-walk-frames.png)
- [Left profile](commuter-walk-review/left.png), [right profile](commuter-walk-review/right.png), [back](commuter-walk-review/back.png)

The larger drawings sharpen the face, suit and silhouette at the same world
height. Source reference heights are front 433, back 429, left 443 and right
428 pixels, instead of the earlier atlas's much smaller profile drawings.
Each directional sheet uses one fixed pixels-to-world scale and common row
ground pivots; drawings are not stretched individually. The 1.83 m intended
world height, collision capsule, stride and movement cadence remain unchanged.
The briefcase remains in the anatomical right hand, with occlusion changing
between profiles. Normal gait comes from separate articulated drawings, not
whole-sprite rocking or rotation. This is cartoon walking rather than a
motion-captured biomechanical cycle; dedicated idle/run/turn artwork remains
future work. Waiting still uses a resting walk pose.

The existing twelve reaction drawings remain in the original atlas and retain
their earlier softer finish. This pass does not claim to clean those frames
or the entire cast. Retaining original source files makes rollback possible.

## Integration and cost

`walk_textures` in `data/citizen_lineup_catalog.json` selects the four sheets.
The alpha-only registration tool writes per-clip texture/region/pivot/height
metadata. `citizen.gd` loads a clip's texture with the original atlas as its
fallback, preserving all existing citizens and reaction clips. Both Mayhem
and City Streets use this same definition on PC, phone and tablet.

All four new images have mipmaps enabled, matching existing sprite filtering.
They add roughly 32 MiB of uncompressed RGBA texture/mipmap storage when all
directions are loaded, plus about 8 MB in this local web package. This is a
single-character quality pass; do not extrapolate it to all eight citizens
without memory/device profiling. Matched native scene draw counts remain 190
desktop, 212 portrait and 200 touch landscape. These are scene samples, not
a physical-phone performance guarantee.

Reproduce native review with
`python tools/capture_art_review.py --zone arcade --commuter-review`.
The opt-in review advances all 48 frame selections and asserts that each
uses a new directional texture. Its gallery/sheet are inspection fixtures,
not changes to gameplay cameras. Existing 14 native regression checks and
four responsive browser gameplay checks gate the verified save and D:/Pages
mirror. Native metadata comparison also confirms that the seven other
citizens, commuter reaction clips, identity, height and stride are unchanged.
