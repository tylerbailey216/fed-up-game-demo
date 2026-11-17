# High-speed curb jumps

The same curb-jump system runs on PC, phone and tablet. Approach a raised sidewalk at about **50 mph or faster** with a substantial crossing angle. A shallow brush along its edge stays a curb bump. Slow and moderate crossings keep the existing suspension feedback.

Takeoff requires at least 22 m/s total forward speed and 16 m/s perpendicular to the curb. Two short front-wheel sweeps find the actual raised sidewalk bevel, followed by a top-height check. Only tagged raised street surfaces qualify, with a rise between 5.5 and 38 cm; vertical walls, motorway guardrails, flat road seams and curb descents do not become launch ramps.

The grounded vehicle still uses the game's existing arcade controller. At a qualifying curb, a suspension/tire launch assist redirects part of its horizontal momentum upward, capped at 5.8 m/s, and accounts for the small initial height change. It does not add translational energy. This is a playable curb approximation rather than a full tire and suspension simulation.

After takeoff, the existing truck collision hull becomes a continuous-collision rigid body. Gravity, its low center of mass, angular momentum and contact friction determine the landing. A nearly level approach normally lands roughly and keeps moving; a nose-first or obstructed landing can trip into a forward tumble or full rotation. These outcomes are not randomized or forced flip animations. The controlled nose-first test setups demonstrate what the contact system supports, rather than promising a flip on an ordinary flat curb crossing. The implementation uses Godot's [RigidBody3D physics](https://docs.godotengine.org/en/4.5/classes/class_rigidbody3d.html).

Acceleration and steering do not propel the truck through the air. A fresh brake press supplies a small bounded nose-down wheel-braking impulse. A stable upright landing hands the actual remaining velocity back to normal driving. A tip or a truck resting tilted against an obstacle enters the existing settled recovery flow; press **U** / tap **RECOVER** once offered. Recovery is unavailable during ordinary airtime.

Hard landing damage uses contact-point closing speed and the existing truck energy system. Delivery cargo stays secured until the life bar is empty; the fixed package quota then releases once. A disabled truck finishes landing before the driver exits. Pause freezes flight. Reset disposes of the temporary rigid body. The chase/orbit camera follows the physical truck, tire marks and road noise stop in flight, and the contact shadow stays on the ground.

## Verification

`godot --headless --fixed-fps 60 -- --stunt-test` checks actual 16 cm sidewalk geometry at 5, 18, 24 and 34 m/s, a shallow glancing pass, the shipping Cleveland entrance curb, bounded takeoff energy, no repeated launch on one edge, pause, safe exit, airborne skid suppression, upright/forward-tumble/full-rotation landings and life-bar depletion with a single cargo spill. It runs in both the save workflow and GitHub Actions. Add `--stunt-capture` to a rendered run for local screenshots.

Native reference results on the development PC: 24 m/s produced about 0.85 m peak height and 0.75 seconds airborne; 34 m/s produced about 1.59 m and 1.03 seconds. These are fixture results, not guarantees for every curb, entry angle or obstacle.

`node tools/browser_stunts.cjs http://127.0.0.1:8766/` checks the exported WebAssembly build at 360×640 touch portrait, 844×390 touch landscape and 1280×720 desktop. Its opt-in `?qa=controls` fixture sets the approach speed, then crosses the real Cleveland sidewalk through the production physics. It checks airborne/landing telemetry, continued driving and absence of a rollover prompt during a normal jump, and saves screenshots. This browser emulation does not replace physical iPhone/Android testing. The native delivery, map-switch and motorway safety suites cover the surrounding gameplay.
