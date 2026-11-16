# Cleveland and Independence map data

The Cleveland extract (`cleveland_osm.xml`) and modified database (`cleveland.json`) are also © OpenStreetMap contributors, ODbL 1.0. Downloaded November 16, 2026 from the OSM map API for bbox -81.705,41.492,-81.680,41.508. Rebuild: `python tools/build_cleveland.py`.

Modifications: local meter projection centered at 41.4995,-81.6944; 1.3 km square crop, estimated street widths, building footprints/heights, park polygons and directed traffic loop. Runtime puts downtown east of the training ring via a fictional connector. Street heights are flat; tunnels, current access restrictions and public transit routing are simplified. Terminal Tower is an original procedural landmark. No Google imagery or models were extracted. Original databases and transformation scripts are supplied under ODbL.

## Independence

Contains information from OpenStreetMap, © OpenStreetMap contributors.
https://www.openstreetmap.org/copyright

The raw database extract (`independence_osm.xml`) and modified geographic database
(`independence.json`) are available under the Open Database License 1.0:
https://opendatacommons.org/licenses/odbl/1-0/

Downloaded from the OSM map API for bbox -81.668,41.395,-81.636,41.422.
The embedded OSM metadata records its retrieval timestamp. Offline play requires
no API or tiles. No Google imagery, models, tiles, or Street View data were used.

Rebuild using `python tools/build_independence.py` from the project root.
Modifications: local meter projection around 41.4072,-81.6470; cropped road
polylines, 10m samples, estimated width from lane counts, estimated 8m per bridge
layer (Brecksville Road adjusted to 16m for crossing clearance), graph-smoothed approach heights, building footprints and estimated heights.
The playable extract is approximately 2.2km east-west by 2.25km north-south.
These are estimated game elevations, not surveyed or navigation-grade measurements.

This license applies to the geographic database; original game code, truck,
materials, audio, and artwork retain their existing project provenance.

The additional independence_safety.json geographic database is also ODbL 1.0. Rebuild it after the main map using python tools/build_road_safety.py (Shapely). It contains external-edge barrier locations and a grade-crossing clearance audit. Granger Road underpass heights are constrained to 0m in the updated estimated-height model.
