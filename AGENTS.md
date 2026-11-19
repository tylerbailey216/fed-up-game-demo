# FedUp project guidance

The established delivery driver is the master style reference for every human and extraterrestrial pedestrian. Read `docs/CHARACTER_STANDARD.md` before designing character assets, NPC animation or pedestrian collision behavior, and follow `docs/ART_DIRECTION.md` for the wider presentation. Preserve the user's original character identity and the documented provenance of its expanded artwork.

Keep the same character assets and gameplay behavior across PC, phone and tablet. Vary character bodies and frame sizes through metadata and world scale, without per-frame stretching or replacing drawn animation with whole-sprite movement. All pedestrian NPC collisions are comical, nonlethal and recoverable, with the same rules across species. The user's current damage rule supersedes the earlier three-crash cap: impact severity drains truck energy; disable and the single fixed-quota cargo spill occur only at zero energy. Crash count is diagnostic only.

The user has requested that each saved version mirror to `D:\FedUp Driver` and the GitHub Pages demo. Use the existing verified `tools/save_state.py` workflow and confirm its matching build IDs before reporting that local, external and online versions are synchronized. Distinguish documented future requirements from implemented runtime features.

Delivery Mayhem uses one fixed elevated world bearing for truck and worker. C / VIEW changes viewing distance only; free orbit, camera tilt and recenter-to-character-facing are disabled in this mode. Preserve screen-relative walking, obstacle cutaways with intact solid footprints, and route/package/truck direction markers. The separate exploration maps retain their cockpit and orbit cameras.
