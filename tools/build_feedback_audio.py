"""Deterministic FedUp event chimes: stdlib additive synthesis, no source audio/AI.

All three platforms use these same mono WAV files. Re-running writes identical
bytes. These are original mathematical tones, not derived from character artwork.
"""
from pathlib import Path
import math
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050


def bell(t: float, frequency: float, duration: float, gain: float = 1.0) -> float:
    if not 0 <= t < duration:
        return 0.0
    attack = min(1.0, t / .006)
    release = min(1.0, (duration - t) / .025)
    envelope = attack * release * math.exp(-t * 8.0 / duration)
    phase = math.tau * frequency * t
    return gain * envelope * (math.sin(phase) + .18 * math.sin(phase * 2) + .05 * math.sin(phase * 3))


def write(name: str, seconds: float, notes: list[tuple[float, float, float, float]]) -> None:
    data = bytearray()
    peak = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        value = sum(bell(t - start, pitch, length, gain) for start, pitch, length, gain in notes)
        peak = max(peak, abs(value))
        data.extend(struct.pack("<h", round(max(-.95, min(.95, value)) * 32767)))
    with wave.open(str(OUT / (name + ".wav")), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(data)
    print(f"{name}: {seconds:.2f}s, {len(data) // 2} samples, peak {peak:.3f}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Warm pentatonic notes. Soft attacks avoid sharp clicks on phone speakers.
    write("package_pickup", .20, [(0, 659.255, .14, .38), (.052, 987.767, .148, .31)])
    write("route_clear", .34, [(0, 523.251, .20, .34), (.08, 659.255, .22, .32), (.16, 783.991, .18, .30)])
    write("delivery_complete", .84, [(0, 523.251, .28, .31), (.12, 659.255, .28, .31), (.24, 783.991, .28, .31), (.39, 1046.502, .45, .34), (.39, 659.255, .40, .14)])


if __name__ == "__main__":
    main()
