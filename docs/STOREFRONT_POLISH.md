# Mayhem storefront finish

November 22, 2026. A focused follow-up to the Phase 2 visual audit.

The existing Mayhem buildings now alternate Parcel & Post, Orbit Coffee,
Corner Market and Quick Fix fronts. Cream-striped colored awnings, framed
glass bays, entrance trim, handles and inset sign panels replace the repeated
unbroken glass strip. The lettering uses the existing bundled Barlow font.

[Previous view](storefront-review/before.png) · [Current view](storefront-review/after.png) · [Detail inspection](storefront-review/detail.png)

These are authored GDScript geometry and live lettering, not new raster art or
conversions of the user's reference sheets. Original citizen, driver, cockpit
and vehicle artwork is unchanged. NPC line cleanup and dedicated action
drawings remain source-art work described in VISUAL_AUDIT_PHASE_2.md.

Decorative geometry joins the existing per-building vertex-color mesh. Sign
labels belong to that same building root, so storefronts cut away with the
wall while its original solid footprint remains. No new colliders or building
interiors are added. These are visual shops, not interactive destinations.
The change applies to Delivery Mayhem on every platform; Zen's mapped
buildings are unchanged.

Matched native desktop capture: 190 draw calls and 49,365 primitives versus
188 and about 45,200 in Phase 2. New text has a modest rendering cost; this
is not a sustained performance benchmark or a physical-phone guarantee.
The normal capture tool now also records a posed storefront close-up;
it does not change gameplay cameras.

Publication uses the existing 14-check save gate and matching source, local
web, D: and GitHub Pages identities. Browser layout results are recorded in
the local tools/storefront-browser.log verification log.
