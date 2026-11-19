# Gameplay prompts and driving camera

## Delivery Mayhem fixed view (current)

The compact arcade mode uses one fixed world angle for driving and walking. C / VIEW changes Play / Overview distance; G / hold VIEW restores Play. Camera swipes, mouse drags, wheel zoom and on-foot Q/E rotation are disabled here. The camera follows position without turning with the truck, rolling with impacts or changing the worker's screen-relative movement basis. Entering/exiting the truck keeps the same bearing. Desktop, portrait, landscape and tablet share this behavior.

The fixed view uses foreground building/tree cutaways to reveal the player and nearby pickup ground, retaining visible raised building footprints and all physical collision. A parked truck hiding the worker shows a low outline while staying solid. The compact map batches each facade as one vertex-colored mesh so individual cutaways do not require dozens of material submissions. Direction markers point toward route gates, loose packages, the truck or the final stop. The arcade suite checks heading stability, gestures, real walking directions, cutaways and HUD framing; the browser suite repeats controls and pickup/replay in four layouts.

The orbit controls described below apply to the separate Public Square and motorway exploration maps.

## Exploration cameras and shared notices

The recovery panel previously used the historical flip count to stay visible after the truck was upright. Its auto-sized container also retained a large empty background when the buttons disappeared. Recovery now follows the current overturned/settled state, uses explicit bounded dimensions, and hides immediately when no longer needed. On touch layouts it occupies the compact instrument area; the existing recovery control remains the action. Desktop uses a compact comic strip with a recovery button. Route completion keeps a small replay strip in that same reserved area.

Delivery, damage, pickup/recovery and navigation notices share one existing HUD line. They expire after 2.6 gameplay seconds, fade at the end and yield to the objective. Repeating a notice cannot keep renewing it. The newest message wins; exact missing-package counts remain visible. Timers continue during on-foot, overturned and disabled states. The separate mission popup, duplicate vehicle notice box and permanent desktop on-foot help panel are removed. Manual settings and expanded GPS remain open until the player closes them.

Strips use the established purple/ink/gold palette, condensed lettering, comic edge details and state icons, without new bitmap assets. Recovery/replay strips stay below ten percent of the viewport and outside steering/pedal regions.

While driving or walking, drag clear world space to orbit and tilt. Driving supports full horizontal orbit and clamped vertical adjustment, preserving collision-aware placement. Dragging from cockpit opens the external chase view. PC: either mouse button drags, wheel zooms, G recenters, C cycles presets. Touch: swipe world space, tap VIEW to cycle, hold VIEW to recenter without cycling. Steering/pedal fingers stay independent. GPS/control areas do not start camera gestures.

The delivery suite includes ui_camera_tests.gd: recovered-but-previously-flipped state, sizing across desktop/phone/tablet/landscape, notice expiry/deduplication, touch/mouse gestures, pedal preservation, cycling/recentering. --delivery-test --ui-only --ui-capture records rendered states. Browser controls checks use real inputs before reverse and full-load collection checks.

