# Commuter reaction artwork polish

November 23, 2026. The business commuter's surprise, tucked tumble and recovery
drawings now match the cleaner walking artwork. Twelve poses cover the four
camera-relative directions. The driver and other seven citizens are intact.

Asset: `assets/art/presentation/commuter-reactions.png`, 1536 x 1024 transparent
RGBA with mipmaps. Built-in ImageGen adapted the user's character identity and
existing expanded walking art. These are AI-assisted project drawings, not
hand-drawn user production files. [Exact prompts](COMMUTER_REACTION_PROMPTS.json)
record the initial generation and correction of the rear surprise briefcase
hand/trouser seam. Original reference and previous production atlases remain
preserved. No Python pixel editing or per-frame stretching was used.

## Review evidence

- [All twelve imported poses](commuter-reaction-review/all-reaction-poses.png)
- [Surprise beside the driver](commuter-reaction-review/surprise.png)
- [Tucked tumble pose](commuter-reaction-review/tumble.png)
- [Recovery pose](commuter-reaction-review/recovery.png)

The reaction atlas uses one common 441-pixel standing reference, fixed scale
for all twelve poses and common row ground pivots. Crouches are naturally
shorter drawings, not enlarged to standing height. The briefcase remains on
the original hand with appropriate rear-view placement. World height,
collision capsule, stride, walking frames and all other citizen definitions
are unchanged; metadata comparison verifies these invariants.

`reaction_texture` in the source catalog registers the replacement poses into
the existing `surprise_*`, `tumble_*` and `recover_*` clips. This is a visual
replacement of their single state drawings, not new multi-frame reaction
animation or a redesign of physical tumbling. Nonlethal launch, bounce,
landing, recovery duration, cooldown and return to route are unchanged. New
idle/run/turn/carry/interact animation remains future work.

## Verification and budget

The native opt-in review checks all 48 walking and 12 reaction texture
selections and exercises the real tumble -> recover -> walk controller on
flat inspection ground. It passed. Posed captures check all four directions;
they do not change gameplay cameras. Reproduce with
`python tools/capture_art_review.py --zone arcade --commuter-review`.

The replacement adds about 2 MB to this local web package. Its raw RGBA plus
mipmap footprint is approximately 8 MiB, similar to the previous atlas used
for reactions. All commuter clips now select newer sheets, so `citizen.gd`
does not load the legacy atlas even though the preserved file remains in the
project/package. This is an estimate, not measured peak device memory.
Matched native draw counts remain 190 desktop, 212 portrait and 200 touch
landscape. Physical-phone performance remains separate device QA.

Four browser layout/gameplay checks and the required 14 native regression
checks gate publication through `tools/save_state.py`. One runtime artwork
set and metadata are shared by PC, phone and tablet in Mayhem and City Streets;
the workflow verifies matching local, D: and GitHub Pages build identities.
