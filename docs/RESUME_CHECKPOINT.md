# Terrain spray handoff

Work resumed on November 18, 2026. The previous pause is no longer active.

The implementation and terrain contract are documented in `docs/TERRAIN_SPRAY.md`. Grass cuttings, soil chips and restrained dust use individual wheel contacts and bounded procedural mesh/shader pools. Future dirt, sand, water and snow profiles are available without adding those terrain areas to the current maps. Existing skid tracks remain independent and retain their seven-second fade. No new bitmap or AI-generated artwork was used for this effect.

Verification completed before release preparation:

- Downtown terrain integration: PASS, including road/sidewalk/grass and raised islands, split-wheel contact, all profiles, reverse, simultaneous skid tracks/spray, pause, airborne suppression, reset, pool reuse and expiry.
- Motorway terrain integration: PASS, including twelve actual elevated road contacts.
- Existing handling/tire-mark suite: PASS.
- Rendered terrain captures inspected after correcting fragment sizing.
- Final effect code tested in exported WebAssembly at 360x640 touch portrait, 844x390 touch landscape and 1280x720 desktop: PASS, no browser/shader errors. Expired dust quads collapse before rasterization.

Timing samples vary substantially and are diagnostic, not a physical-phone performance guarantee. The optional browser `--profile` diagnostic is not required for the completed functional acceptance checks.

For release or subsequent changes, use the verified `tools/save_state.py` workflow as required by `AGENTS.md`. `docs/save-state-status.json` records its current phase and verified live build; `docs/external-sync-status.json` records the D: mirror result. Confirm those records against `data/build_version.json` and the live `version.json` before claiming release parity. The earlier `d40a7ee071f5` stamp identifies the curb-jump release, not proof of a published terrain-spray update.
