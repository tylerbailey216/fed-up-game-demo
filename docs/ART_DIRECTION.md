# Comic highway art direction

## Locked character direction

[CHARACTER_STANDARD.md](CHARACTER_STANDARD.md) governs every human and extraterrestrial pedestrian. The established FedUp delivery driver is the master reference for proportions, black outlines, cel shading, faces, hands, clothing and footwear. Characters may vary in body, age, ethnicity, species, outfit and personality while sharing that illustration quality, animation conventions and comical nonlethal recovery rules. Frame sizes may vary; world scale and ground alignment must remain consistent. This standard takes precedence over older character brainstorming or placeholder treatments.

This pass uses the supplied Comic Truck Driving Simulator HUD, Driving Simulator Asset Sheet, UI Asset Sheet and van turnaround as visual references. They remain reference files, not cropped shipping textures. Runtime art is original.

## Shared style

The November 17 user-supplied `FedUp Vehicle Look Sheet.png` is preserved unchanged at `assets/source/style/vehicle-look-sheet.png`. Fourteen original Blender models now adapt its rounded silhouettes, trim and palette for downtown traffic. The companion pedestrian lineup supplies eight current animated citizen identities under [CHARACTER_STANDARD.md](CHARACTER_STANDARD.md). Both original sheets remain source references excluded from the browser runtime export. See [CITY_LIFE.md](CITY_LIFE.md) for current runtime scope and provenance.

- Ink: nearly black violet `#10121e`, thin architectural edges, heavier cockpit silhouettes.
- Brand: purple `#6a39a0`, orange `#f78c2f`, gold `#ffd044`, warm white `#f3ebd8`.
- World: slate asphalt, warm concrete, stepped blue-gray shadows, olive foliage with bright leaf planes, muted brick/cream/glass facades, saturated blue sky and cream clouds.
- Shapes: simple readable planes, architectural window grids/cornices, grouped tree crowns, restrained atmospheric distance. No photorealistic PBR glare, motion blur, or mandatory expensive screen-space effects.

## Implementation and tuning

`assets/shaders/toon.gdshader` supplies three stepped light bands from a fixed world-space art direction, cool shadow tint, optional road grain/wheel wear and distance haze. This is an art-directed lighting model; it does not receive dynamic cast shadows. The van has a soft illustrative contact shadow. Cloud shading is deliberately gentler than foliage.

`assets/shaders/ink.gdshader` is a front-culled inverted-hull pass with projected pixel-width expansion and distance taper. Used for the van and main foliage. Architecture and highway details use explicit dark geometry for edges. `sky.gdshader` supplies the gradient sky. API references: [Godot spatial shaders](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/spatial_shader.html), [Godot sky shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html).

`scripts/art_style.gd` caches materials and applies them to the Blender van without altering the GLB source. `scripts/city_art.gd` creates original facade/crown/window variations and the inner city cluster. `scripts/highway.gd` batches static box visuals by material while preserving independent collision bodies. Detailed scenery remains separate from the continuous drivable surface.

`scripts/cockpit.gd` draws at a 1280x720 design scale and scales to the window. The windshield frame, shaded dashboard, live dials, steering wheel, brand tabs, route diagram and hints are vector primitives and live text. The diagram's grid is decorative; the ring and position marker represent the actual loop. Fonts resolve installed Arial/Liberation Sans through SystemFont with Godot fallback; no commercial font files are bundled.

`scripts/rear_mirror.gd` renders a real rear-facing camera into a 224x320 SubViewport every fourth rendered frame in cockpit view. It shares the main world. It is a rear camera feed rather than an optically calibrated mirror. The exterior model's mirror faces remain static geometry. Physics pauses normally; cockpit art owns no vehicle physics.

`scripts/menu_art.gd` and the menu theme use the same palette, angled composition, outlined typography and vehicle backdrop. New drives start in cockpit view; C switches to chase. Menus preview the van exterior.

## Verification / remaining art limits

Latest captures: `cockpit.png` (720p), `polished-1080.png` (1080p), `van-detail.png`, `first-playable.png`, `menu.png`. Capture via `tools\Godot_v4.5.1-stable_win64_console.exe --path . -- --capture --visual-pass`. This developer mode briefly changes the window size and records a stationary render sample, then exits.

The reference illustrations contain richer hand-drawn detail than this real-time pass. Remaining work includes detailed leaf contours, a fully modeled 3D cab, functional exterior lamps, rotating exterior wheels, more varied city modules and artist-authored textures. Current shading/foliage stays deliberately simple for integrated graphics. No traffic or obstacles are introduced by the art pass.

## Illustrated asset pass v2 (current)

The earlier all-vector cabin remains as a missing-texture fallback. The current cabin uses `assets/art/cockpit_illustrated_v2.png`, generated with ImageGen under project art direction using the supplied cockpit image as a style reference. It is a new transparent illustration, not a crop of the concept sheet. Hatching, vents, fasteners, seams, sunlit molding and mirror housing are artwork. The windshield stays transparent; a live rear feed draws beneath the mirror's translucent glass, and live speed/RPM needles, numbers and gear draw over the empty instrument recess. Steering rim/spokes remain runtime drawing with leather bevels and stitching.

The distant city uses `assets/art/skyline_illustrated_v2.png`, a second original ImageGen asset. `scripts/skyline_art.gd` maps it around a 520 m radius cylindrical backdrop, repeated in eight sectors with transparency cutout and a small atmospheric tint. It is a distant illustrated impostor layer, not explorable buildings. Nearby buildings, foliage, roadway, barriers, overpasses and the van remain 3D. Repetition and limited depth in the distant artwork are known limitations. The skyline sampler clamps its texture edges to avoid a thin upper-edge wrap seam.

Nearby procedural towers now have podiums, stepped crowns, parapets and glass bays. Trees use smaller irregular leaf-cluster arrangements plus a shrub row; larger spherical placeholder crowns were removed. The Blender source now includes a raked windshield, wipers, arch lips and hub lugs. The editable `.blend` retains individual pieces; the exported GLB merges static parts by material into eight meshes (4,928 triangles) for lower draw overhead. Exterior wheels remain static. The 3D foreground retains simpler shading/detail than the authored cockpit and distant artwork.

The later functional dashboard update supersedes the static-wheel/lamp limits above: four exported wheel pivots now roll/steer, exterior signals and brake lenses change state, and headlight/high beam controls add an art-directed road pool. The van export now has 12 meshes with the same triangle count. The illustrated cab recess now includes live fuel/temperature gauges, mph speed, turn arrows and warnings. The GPS is an actual local waypoint display rather than the earlier decorative ring panel. See `DASHBOARD_AND_AUDIO.md` for controls and simplified-system limits.
