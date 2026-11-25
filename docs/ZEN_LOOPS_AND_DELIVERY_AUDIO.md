# Zen loops and delivery sounds — November 25

Follow-up trigger correction: route markers now use their painted 11 m by 5 m
footprint, replacing the old 14 m proximity radius. The truck centre must cross
the marker's halfway plane before sound and route credit fire. The final bay
uses the same midpoint rule before sound and its full-stop timer can start;
the existing package/route requirements remain. Swept physics-step checks handle
fast crossings from either end; side passes, approaches and first-half stops do
not count. Each bay visit latches once until exit. On-foot missing-package notices
remain available, without granting delivery credit or sounding the driving cue.

The user's two recordings are copied byte-for-byte into the shared game assets:

| Event | Source | Runtime asset | SHA256 |
| --- | --- | --- | --- |
| Active route marker / final collection-bay entry | `D:\34.mp3` | `assets/audio/delivery_zone.mp3` | `20f5f6f334ef60c8a5a00779773ca28c849d16de695d968212a49b618a91fdaf` |
| Immediate loose-package recovery credit | `D:\S0000003.NSF_00054.wav` | `assets/audio/loose_package.wav` | `40366fec9b4e635e96c16f0025f70e779a9f462886ec29799e327b1edebacdb8` |

These are user-supplied recordings, not generated or resynthesized audio. Their
source authorship/licensing is not established by this integration. Both are mono
11025 Hz; durations are approximately .47 and .27 seconds. Original files remain
untouched. Playback uses original pitch, master volume/mute, pausable players and
an eight-voice cap. Duplicate package credits cannot repeat sounds. Bay entry is
latched until exit; standing inside does not loop the sound. Inactive final bays,
on-foot bay visits and normal Zen do not announce delivery-zone entry. The normal
completion fanfare and vehicle/environment audio remain separate.

Open Road adds four fictional scenic returns beyond the offline map's cut edges:
7,244.6 metres total. These are stylized game roads, not additional surveyed Ohio
geography. Each return shares the original incoming/outgoing node IDs, matches
their endpoint tangents and elevations, and has a physical deck, lane markings,
embankment support where raised, breakaway guardrails, roadside trees and a signed
slow bend. The GPS and recovery boundary cover the expanded area. The existing
bounded twelve-car mainline population remains; the new returns do not spawn a
second large traffic pool. Only Zen receives this expansion.

At the north gateway, **right lane enters City Streets; left lane continues onto
the scenic return**. This prevents the automatic zone transfer from cutting off
the new north loop. The city still connects back to Open Road on its signed road.
Only one large zone is loaded, and vehicle state carries between them as before.

City Streets' existing mapped roads total about 35 km including service streets.
Offline geometric intersection QA finds the city spawn and gateway in the same
main component with 115 independent graph cycles. Seven smaller components and
private/service cul-de-sacs remain; this is not a claim that every driveway loops
or that every street is a continuous race circuit. No existing buildings or
pedestrian areas were removed to force an artificial city loop.

Validation:

- `python tools/audit_city_loops.py`: geometric city connectivity/cycle audit;
  Shapely is a development-only QA dependency, not part of the game or build.
- `python tools/check_zen_update.py`: four full return drives with normal simulator
  throttle and steering at about 8 m/s, no mid-drive repositioning, resets or
  rollovers; deck ray checks at centre and both lanes for every new segment.
- `--zen-roads-test --zen --outerbelt`: faster endpoint, boundary and deck checks,
  included in `tools/save_state.py`. Add `--zen-road-drive-test` for full drives.
- `--feedback-test`: supplied stream identity, real package credit, active bay
  entry, no repeat while inside, master mute, pause and reset behavior.
- Existing native Zen/gateway, damage, terrain, fleet and Mayhem checks remain in
  the save workflow; browser checks cover the same shared runtime on touch/PC.

These checks establish ordinary driveability, not safe cornering at every speed.
The simulator's momentum, collisions, curb jumps and rollover physics still apply.
