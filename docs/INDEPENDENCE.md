# Independence, Ohio: first drivable geographic prototype

Open **Launch Independence.cmd**, or choose **Drive Independence, Ohio / I-480**
from the existing demo menu. Selecting the map starts driving automatically.
Both maps have clearly named Drive buttons; the alternate location shows a loading
message while it builds. The menu also switches back to Metro Loop. Controls, dashboard, truck sounds, tire marks,
rollover damage and recovery carry over. R resets to the eastbound I-480 approach;
M expands the geographic map, N reports the nearest mapped road, G toggles GPS.

The map covers I-480 / Outerbelt South Freeway and I-77 / Willow Freeway around
41.4072,-81.6470, including nearby Brecksville Road and local streets. One world
unit is one meter. The cropped bounds are X -1250..950m and Z -1150..1100m.
593 road sections, 9166 road samples and 137 building footprints come from OSM.
Those are sections of ways, not 593 distinct streets. Brecksville Road bridge height is adjusted to 16m to clear the elevated freeway approach.
The map and map credit
are embedded for offline use; the menu credit links to the data license.

This is the geographic and driving foundation. Roads have physical triangle
surfaces; bridge decks have estimated stacked elevations and supports that avoid
lower roadways. The later containment pass below supersedes the initial barriers. Approaches interpolate
through the connected road graph. Building footprints have solid massing. Trees,
colors and signs are original stylized additions. Off-road grass is traversable;
leaving the finite map recovers to the last clear road and preserves damage.

Limitations: terrain is a flat placeholder beneath estimated road grades, not
LiDAR or surveyed terrain. Bridge layers use an assumed 8m spacing. Widths and
building heights are inferred where tags are missing. No detailed landmark
facades, accurate vegetation survey, current construction staging, local signal
logic, highway traffic AI, delivery missions or turn-by-turn routing are included
in this location yet. Existing fictional city traffic stays in Metro Loop.
Surface streets and ramps end at the extract boundary. Styling remains a first
pass; the former illustrated city skyline is excluded from this real location.

Source and rebuild instructions: `assets/maps/README.md`, `tools/build_independence.py`.
Data: © OpenStreetMap contributors, ODbL 1.0; https://www.openstreetmap.org/copyright.

Verification: `--outerbelt-test` checks mapped road and bridge contact, initial
spawn, continuous input-driven I-480 traversal, sampled freeway deck support,
acceleration, reset and geographic boundary recovery. `--outerbelt-capture` checks spawn and mapped road/bridge contact and saves overview, chase and cockpit/map captures under docs.


Performance update: static GPS geography is rasterized once for each map size during loading and drawn as one texture; the player marker remains live. Road recovery uses a 32m spatial grid and attempts at most once per 0.75s, including unsuccessful off-road samples. Original full-resolution collision stays loaded; road rendering is divided into 128m chunks with a 900m cutoff, foliage into 128m groups with a 600m cutoff and building visuals use an 800m cutoff. No roads or buildings were removed from the geographic database. Restart existing demo windows to load these script changes. Short before/after profiling and limits are in TEST_REPORT.md.


## Motorway containment and physical impacts

All external motorway/ramp edges now have protection, including elevated
approaches that were not tagged as bridges. Mainline and ramp shoulders are
widened by 1m per side. The safety builder checks neighboring road segments in
3D at 1m spacing. Only actual pavement at the same level opens a merge; a road
underneath cannot suppress a bridge barrier. 8,365 collision sections protect
about 40.5km of edges. Joints overlap 10cm. Geometry and visuals are batched in
128m areas; distant render culling does not remove collision.

Bridge edges use fixed 1.15m concrete parapets. Other motorway edges use 1.2m-tall
steel rail assemblies. Steel sections can yield when a severe inward impact
exceeds the game-tuned 800kJ threshold for a 3,200kg truck. Anchor yielding removes
450kJ from normal kinetic energy; remaining normal momentum is shared with a
250kg physical loose section. Speed parallel to the rail does not count as
inward impact energy. Released sections remain open for that map session, with
up to 24 physical debris pieces retained. These are game parameters, not certified
barrier crash ratings or a structural deformation simulation.

Severe mapped-world impacts transfer the truck's existing velocity to its rigid
crash body. Gravity is 9.81m/s?. No upward kick, prescribed flip, recoil velocity,
or speed-triggered concrete disappearance is applied. Contact geometry, friction
and momentum determine whether the truck stops, tips or clears the edge. Normal
controlled driving still uses the existing CharacterBody handling model; it is
not a full suspension/tire simulation. Concrete is cleared only if the physical
body actually goes over it. A real tip still counts toward the three-flip limit.

Elevated non-bridge approaches get supporting sloped embankments where those
would not bury another road. Granger Road underpass elevations are constrained
to ground level. The offline audit checks 47 separate grade crossings and reports
at least 6.01m of clear space beneath their decks. Elevations remain estimated
rather than surveyed. Recovery samples an unobstructed nearby surface at the
current level, skips barrier tops, and no longer sets bridge recovery to Y=0.
An upright crash that genuinely lands off road can resume on that surface.

Rebuild sequence: `python tools/build_independence.py`, then
`python tools/build_road_safety.py` (uses the installed Shapely package).
Run `--outerbelt-test --safety` for barrier/contact tests; add `--safety-capture`
to a rendered `--outerbelt-capture --safety` run for screenshots. See TEST_REPORT.md.
