# Demo polish — Phase 1 review

November 20, 2026. Scope: gameplay feedback and presentation, plus the reported grass-to-street return defect. Phase 2 art auditing and further content expansion are deferred for review.

- Working branch: `polish/demo-feedback-curbs-20261120`.
- Preserved baseline: commit `4e916f4bf5c289102381d3ae12d2ad80b8a5de2d`, build `ae9c5b219f24`.
- Build identity: the saved update is recorded in [data/build_version.json](../data/build_version.json). The baseline ID above is the rollback version. `tools/save_state.py` produces local/D:/online verification evidence in `docs/save-state-status.json`; publication is not considered complete until all IDs match.

## Player-visible changes

Delivery Mayhem now gives physical truck contacts a small inked gold/purple spark burst. Existing truck reactions and bump/scrape/crash audio still handle the collision; the new presentation does not duplicate those sounds or award progress for pedestrian contact.

Walking over a loose box retains immediate credit and the existing star flight back to the truck. A short pickup chime and larger secured-package counter confirm that credit. The counter briefly highlights gold; clustered pickups share the existing effect and rate-limited sound rather than opening repeated dialogs.

Each cleared purple route gate gives one brief burst and chime. A finished delivery adds a short completion cue and a 0.62-second dispatch-report reveal with animated manifest, time, energy-used and recovery statistics. Phone portrait stacks the result rows for readability. Replay remains available from the first frame, and pause/settings freeze the reveal.

The curb fix addresses a five-centimeter gap between arcade grass support and the sidewalk bevel toe, planar faces split across collision bodies, and an exposed ground-level triangle edge that could register as a wall at certain approach speeds. Grass support now meets the bevel, both triangles share a body, and the same collision slope continues two centimeters below grade. Visible curb geometry and its above-ground slope remain intact. Surface classification still distinguishes asphalt, raised concrete and grass, preserving tire feedback and terrain spray. Buildings retain solid footprints.

The directional driving controller, fixed arcade camera, simulator controls, damage calculations, fixed cargo quota and package-recovery rules were retained. Zen keeps its connected environments and existing controls; the new event-feedback module is instantiated only for Delivery Mayhem. The shared sidewalk-face correction also applies to city scenery.

## Source map

| Files | Responsibility |
| --- | --- |
| `scripts/gameplay_feedback.gd` | Bounded truck-impact/gate/completion bursts, event deduplication, shared-volume audio and QA counters. |
| `scripts/cargo_gameplay.gd`, `scripts/arcade_run.gd`, `scripts/main.gd` | Existing gameplay event hooks, replay reset, module setup and opt-in validation entry points. |
| `scripts/cockpit.gd`, `scripts/compact_dashboard.gd` | Shared secured-package text, pickup highlight and readable desktop/touch counter placement. |
| `scripts/delivery_report.gd` | Responsive dispatch layout, short reveal, exact settled statistics and immediately usable replay. |
| `scripts/arcade_world.gd`, `scripts/street_surfaces.gd`, `scripts/terrain_surface.gd` | Aligned grass support, intact planar sidewalk contacts and correct road/grass identities. |
| `tools/build_feedback_audio.py`, `assets/audio/{package_pickup,route_clear,delivery_complete}.wav` | Reproducible original event tones and shared runtime audio. Godot import sidecars accompany the WAVs. |
| `scripts/feedback_tests.gd`, `scripts/curb_return_tests.gd` | Event, pause/mute/dedup/reset/report checks and actual bidirectional curb driving. |
| `tools/browser_polish.cjs`, `scripts/arcade_browser_qa.gd` | Opt-in browser fixtures, actual touch/keyboard curb returns and walk-over collection, screenshots and frame samples. |
| `tools/browser_arcade.cjs` | Existing uninterrupted-lap acceptance; optional `FEDUP_SHADER_DIAGNOSTICS=1` captures failing WebGL shader sources without changing normal rendering. |
| `tools/save_state.py`, `.github/workflows/pages.yml` | Include the new native feedback and curb checks in the verified save/CI workflow. |

## Provenance and performance budget

No original character artwork, animation frames or illustrated cockpit textures were replaced or regenerated. Existing artwork retains its documented provenance in [ART_DIRECTION.md](ART_DIRECTION.md), [CHARACTER_STANDARD.md](CHARACTER_STANDARD.md) and [ASSETS_AND_LICENSES.md](ASSETS_AND_LICENSES.md).

The new stars use deterministic mesh geometry and the established ink/gold/purple/cream palette. New audio uses Python standard-library sine-wave/additive synthesis: no recordings, generative service, model dependency or neural backend. Re-running the builder produced identical SHA-256 hashes; all three WAVs were checked for unclipped samples and clean endpoints. They are mono, 22,050 Hz, 16-bit files totaling about 61 KB, with durations of 0.20, 0.34 and 0.84 seconds.

The burst renderer uses one opaque `MultiMesh`, at most 128 reused slots and actual lifetimes of 0.32–0.42 seconds. A normal event emits at most 20 pieces. It adds no physical debris, collision bodies, screen shake, post-processing, lights or custom shader variants. Pickup chimes are limited to one per 80 ms; the existing star-return effect remains the only package-flight effect. Live/peak counts and event/audio counters are exposed by `stats()` for validation.

Initial 90-frame Chrome RAF samples on this PC measured 58.7 FPS / 17.0 ms p95 at 360×640, 60.0 / 17.0 at 844×390, 31.6 / 49.9 at 768×1024, and 58.7 / 16.9 at 1280×720. Baseline samples measured 49.6 / 33.4 at 360×640 and 53.0 / 33.3 at 1280×720. These short startup samples varied between runs and are not controlled benchmarks or proof of a speed increase. Tablet frame pacing and sustained physical-device performance need further measurement; the bounded effect budget alone is not a performance guarantee.

## Review images

| View | Baseline | Phase 1 |
| --- | --- | --- |
| Dispatch report, phone portrait | [360×640 before](polish-review/report-before-360x640.png) | [360×640 after](polish-review/report-after-360x640.png) |
| Dispatch report, desktop | [1280×720 before](polish-review/report-before-1280x720.png) | [1280×720 after](polish-review/report-after-1280x720.png) |
| Walk-over package credit, phone portrait | [360×640 before](polish-review/pickup-before-360x640.png) | [360×640 after](polish-review/pickup-after-360x640.png) |
| Return from grass across the same sidewalk | — | [360×640 after](polish-review/curb-after-360x640.png) |
| Brief impact sparks, with the road visible | — | [360×640 after](polish-review/impact-after-360x640.png) |

## Validation record

Chrome touch/keyboard presentation checks passed at 360×640, 844×390, 768×1024 and 1280×720 with no browser/graphics errors reported. All 13 native save-pipeline checks passed on Godot 4.5.1, including both environments, mode switching, connected roads, delivery, stunts and terrain. Coverage:

- `--curb-return-test`: seven actual directional-input round trips, including a full grass stop, both screen axes, an oblique approach, the exact moderate-speed failure and full digital input; supported surfaces, retained suspension/spray, no ordinary-crossing damage/reset, and an intact solid building footprint.
- `--city-curb-return-test`: actual City Streets simulator gas-to-grass, full stop and true-reverse return across the same sidewalk, retaining bumps and four-wheel surface identities without a false crash or recovery.
- `--feedback-test`: real wall-contact, package-credit, ordered-route and stopped-finish hooks; bounded lifetimes, duplicates, reset, mute/pause, exact report totals and usable replay/layout geometry at 360×640, 844×390, 768×1024 and 1280×720.
- Existing arcade, city/motorway delivery, Zen, stunt, terrain and mode/connection tests through `tools/save_state.py`.
- `node tools/browser_polish.cjs http://127.0.0.1:8766/`: Chrome touch/keyboard controls, curb return, package collection, feedback and report checks in all four layouts. Its report/gate fixtures isolate presentation and do not substitute for the existing arcade suite's continuous input-driven lap.
- `node tools/browser_arcade.cjs http://127.0.0.1:8766/ --layout=1280x720`: uninterrupted four-corner lap, fixed-view gestures, release/U-turn, all twelve walk-over pickups, truck re-entry and both replay paths passed.
- `node tools/browser_zen.cjs http://127.0.0.1:8766/ --layout=360x640`: actual menu, touch gas/reverse, orbit camera, walking/re-entry and city-to-motorway-to-city driving passed.
- Before/after screenshots, frame samples and browser/graphics error review, followed by the verified save/export/mirror/publish process and matching build IDs.

Browser viewport/touch emulation runs on the development PC. It does not establish physical iPhone, Android or tablet testing, sustained device frame rate, or final subjective sound balance on phone speakers. New impact sparks currently use actual horizontal truck contacts; existing stunt landing feedback is retained. Phase 2 art changes remain outside this pass.

One earlier uninterrupted-lap run completed its gameplay assertions but reported unspecified WebGL vertex-shader compilation failures. Both a diagnostic run and an uninstrumented repeat then passed with unchanged game shaders. The cause was not isolated; startup graphics reliability remains a physical-device/driver QA item rather than a claimed rendering fix.
