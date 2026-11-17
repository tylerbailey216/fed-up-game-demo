# Street contact and truck energy

The visible damage tally is replaced by a classic framed energy meter. Full energy is green, middle energy gold, and low energy pulses red. Three distinct qualifying crashes still disable the delivery truck and spill the fixed twelve-package load once. The meter reaches empty at that point and restores after package recovery. Ordinary curb bumps do not spend energy.

Downtown sidewalks and walking paths now have matching visible/collision geometry: 16 cm tops, chamfered curb sides and end ramps, clipped where car roads cross. The entrance includes a raised grass island. Four wheel-contact probes supply pitch/roll and suspension/audio bumps. Grass adds rolling resistance and roughness; bushes bend near the truck and add drag. Training/downtown tree trunks, sign poles and signal poles are solid. Leaves and soft bushes remain traversable; poles/trees do not yet break or fall.

The street meshes are grouped in spatial cells, with visual distance culling. Contact probes run at 20 Hz rather than issuing terrain queries for every drawing frame. Bush contact uses a spatial index rather than hundreds of overlapping physics areas. Sidewalks are traversable by both the truck and worker.

The downtown entrance was moved to West Lakeside Avenue to avoid an existing building footprint. The geographic world remains a stylized OSM-derived blockout; these contacts do not establish survey-grade curb placement.
