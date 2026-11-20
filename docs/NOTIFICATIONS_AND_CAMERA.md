# Gameplay prompts and driving camera

## Delivery Mayhem fixed view (current)

The compact arcade mode uses one fixed world angle for driving and walking: zero-degree bearing aligned with the streets, at 60-degree elevation. C / VIEW changes Play / Overview distance; desktop G restores Play distance. Touch VIEW cycles on release after either a tap or hold, with no hold-reset gesture. Camera swipes, mouse drags, wheel zoom and on-foot Q/E rotation are disabled here. The camera follows position without turning with the truck, rolling with impacts or changing the screen-relative movement basis. Entering/exiting the truck keeps the same bearing. Desktop, portrait, landscape and tablet share this behavior.

WASD / arrows or the single MOVE thumbstick point toward the desired screen travel direction. The truck automatically turns and accelerates toward it, slows for sharp turns and brakes on release. Opposite input makes a forward U-turn; there are no separate arcade gas, brake, gear or drift controls. The 10 m/s speed cap (about 22 mph) suits the compact streets. Walking uses the same screen directions. The exploration simulator's reverse and pedal instructions do not apply here.

The fixed view uses foreground building/tree cutaways to reveal the player and nearby pickup ground, retaining visible raised building footprints and all physical collision. A parked truck hiding the worker shows a low outline while staying solid. The compact map batches each facade as one vertex-colored mesh so individual cutaways do not require dozens of material submissions. Direction markers point toward route gates, loose packages, the truck or the final stop. The arcade suite covers heading stability, gestures, driving/walking directions, cutaways, HUD framing and a continuous input-driven lap. The browser suite covers the same directional driving/lap behavior plus pickup/replay in four layouts. Separate checkpoint teleports test state branches; automated coverage does not establish human usability.

The orbit controls described below apply to the separate Public Square and motorway exploration maps.

## Exploration cameras and shared notices

The recovery panel previously used the historical flip count to stay visible after the truck was upright. Its auto-sized container also retained a large empty background when the buttons disappeared. Recovery now follows the current overturned/settled state, uses explicit bounded dimensions, and hides immediately when no longer needed. On touch layouts it occupies the compact instrument area; the existing recovery control remains the action. Desktop uses a compact comic strip with a recovery button. Route completion keeps a small replay strip in that same reserved area.

Delivery, damage, pickup/recovery and navigation notices share one existing HUD line. They expire after 2.6 gameplay seconds, fade at the end and yield to the objective. Repeating a notice cannot keep renewing it. The newest message wins; exact missing-package counts remain visible. Timers continue during on-foot, overturned and disabled states. The separate mission popup, duplicate vehicle notice box and permanent desktop on-foot help panel are removed. Manual settings and expanded GPS remain open until the player closes them.

Strips use the established purple/ink/gold palette, condensed lettering, comic edge details and state icons, without new bitmap assets. Recovery/replay strips stay below ten percent of the viewport and outside steering/pedal regions.

While driving or walking, drag clear world space to orbit and tilt. Driving supports full horizontal orbit and clamped vertical adjustment, preserving collision-aware placement. Dragging from cockpit opens the external chase view. PC: either mouse button drags, wheel zooms, G recenters, C cycles presets. Touch: swipe world space, tap VIEW to cycle, hold VIEW to recenter without cycling. Steering/pedal fingers stay independent. GPS/control areas do not start camera gestures.

The delivery suite includes ui_camera_tests.gd: recovered-but-previously-flipped state, sizing across desktop/phone/tablet/landscape, notice expiry/deduplication, touch/mouse gestures, pedal preservation, cycling/recentering. --delivery-test --ui-only --ui-capture records rendered states. Browser controls checks use real inputs before reverse and full-load collection checks.

