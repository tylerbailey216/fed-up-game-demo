# City ambience replacement

The active environmental bed is `assets/audio/city_ambience.wav`, copied unchanged
from the user's `D:\mixkit-city-traffic-background-ambience-2930.wav`.
SHA256: `ae0d4c7c6a1a2d40361ae345348c5106931cdf3fceb8f23e3b6c2b93eaea2b24`.
It is 67.1946 seconds, stereo 44100 Hz PCM WAV. Original source remains untouched.
The filename identifies the supplied recording; no licensing terms are inferred.

One looping player replaces the old synthesized bird/nature and ambient-wind
players across Delivery Mayhem and both Zen zones, including on-foot gameplay.
There was no separate music player in the current runtime. Old source recordings
and their procedural build script are retained, but their ambient loops are no
longer loaded by `game_audio.gd`.

Playback stays at original pitch, with `.55 * ambience volume * master volume`
gain. The Audio tab now labels its existing persisted ambience control "City
ambience"; the settings key remains unchanged so saved preferences carry forward.
Inactive/menu play stops, pause follows the game, and mute/ambience volume remain
functional. Engine, rolling tires, skid, collision, horn, indicator, delivery-zone
and package-pickup effects retain their current behavior and recordings.

`--feedback-test` verifies loop length, old-layer removal, playback, mute and
ambience-only volume. Existing native gameplay checks and shared browser export
remain part of the normal verified save/mirror/publish workflow.
