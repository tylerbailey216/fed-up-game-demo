# Business commuter artwork review

November 23, 2026. **Cleanup candidate rejected for runtime use.**

Three built-in ImageGen edits attempted cleaner contours, flatter suit shading
and consistent four-direction drawing scale. The identity, suit, bun, earrings
and briefcase broadly survived. Each output retained the expected 60 complete
silhouettes. The cleanup did not meet the full production standard. No
candidate is used by the game, and no cast-wide replacement was made.

[Retained review candidate](commuter-review/commuter-candidate-not-shipping.png)
and [exact prompts](commuter-review/prompts.json). These are AI-assisted edits
based on the user's design and existing expanded atlas, not hand-drawn user
artwork. `.gdignore` excludes this review folder from resource import/export.

## Scale and finish findings

Read-only alpha measurements of the 12 walk frames in each direction:

| Atlas | Front mean height | Back | Left | Right |
| --- | ---: | ---: | ---: | ---: |
| Shipping | 165.00 px | 151.25 | 138.00 | 134.42 |
| Final candidate | 169.33 px | 164.17 | 144.42 | 141.33 |

Side views remain about 15-17% shorter than the candidate's front view.
Gait and silhouette shape affect these measurements; they are a screening
signal rather than a full anatomy test. Visual inspection also found smaller
side-view bodies/heads. Line cleanup was modest rather than a substantial
match to the driver's finish. Rescaling directions/frames would hide the
symptom while violating the fixed character-scale standard.

Shipping artwork has a related pre-existing scale issue. This review records
it rather than claiming it is fixed. Reproduce measurements with
`python docs/commuter-review/measure.py`; it reads alpha and writes JSON only.

## Next source-drawing task

Use the original business commuter identity and the driver as the ink/style
reference. Establish one head/torso/leg proportion guide, then redraw four
twelve-frame walk cycles with a common upright reference height and ground
origin. Preserve contact, passing and weight-transfer poses, face, outfit and
anatomical briefcase hand. Clean contours and small facial details in the
drawings. Dedicated idle and other future actions are not implemented here.

Review a complete animated gait/turn beside the driver at fixed world scale,
then phone/tablet/desktop gameplay views, before replacing shipping art or
extending the treatment to the cast. No sharpen filter, whole-sprite motion
or per-frame stretching should substitute for that work. A manual source-art
pass is the dependable next route after these automated edits missed the gate.

## Project integrity

Runtime catalog, registered metadata, original artwork and gameplay are
retained exactly. The capture helper now imports new assets before launching
and rejects missing-resource errors; the restored shipping art was captured
successfully. The usual 14 native checks and verified save workflow gate
publication and D: mirroring of this review record.
