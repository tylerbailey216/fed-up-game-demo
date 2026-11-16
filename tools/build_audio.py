"""Original procedural demo sound design; stdlib only, no downloaded recordings."""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050
TAU = math.tau
rng = random.Random(7126)

def write(name, seconds, sample, loop=False):
    data = bytearray()
    state = 0.0
    peak = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        state = state * .92 + rng.uniform(-1, 1) * .08
        value = sample(t, state)
        if not loop:
            value *= min(1, t / .008, (seconds - t) / .015)
        peak = max(peak, abs(value))
        data.extend(struct.pack('<h', round(max(-.98, min(.98, value)) * 32767)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(data)
    print(name, 'peak', round(peak, 3), 'frames', len(data) // 2)

write('engine_idle', 4, lambda t,n: (.32*math.sin(TAU*35*t)+.15*math.sin(TAU*70*t)+.09*math.sin(TAU*105*t))*(.8+.2*math.sin(TAU*18*t))+.09*n, True)
write('engine_load', 4, lambda t,n: .22*math.sin(TAU*55*t+.12*math.sin(TAU*5*t))+.15*math.sin(TAU*110*t)+.07*math.sin(TAU*165*t)+.18*n, True)
write('road', 4, lambda t,n: n*.9*(.9+.1*math.sin(TAU*12*t)), True)
write('wind', 12, lambda t,n: n*.6*(.6+.25*math.sin(TAU*t/6))+.016*math.sin(TAU*47*t), True)

def birds(t, n):
    local = (t % 3.0) - .5
    if 0 < local < .4:
        pulse = local % .2
        return .28*math.sin(TAU*(2200*pulse+1500*pulse*pulse))*math.sin(math.pi*pulse/.2)**2
    return n * .015

write('nature', 24, birds, True)
write('horn', 1, lambda t,n: .25*math.sin(TAU*400*t)+.20*math.sin(TAU*500*t)+.04*math.sin(TAU*800*t), True)
write('indicator', .08, lambda t,n: (.4*math.sin(TAU*1300*t)+.5*n)*math.exp(-t*70))
write('impact', .35, lambda t,n: (.38*math.sin(TAU*60*t)+n*.8)*math.exp(-t*17))
write('brake_air', .6, lambda t,n: .65*n*math.exp(-t*6))
write('starter', 1.0, lambda t,n: (.20*math.sin(TAU*(40*t+55*t*t))+.35*n)*(.6+.4*math.sin(TAU*11*t)))
write('tire_squeal', 3, lambda t,n: (.19*math.sin(TAU*730*t+2.1*math.sin(TAU*13*t))+.10*math.sin(TAU*1460*t+1.3*math.sin(TAU*19*t))+.22*n)*(.8+.2*math.sin(TAU*7*t)), True)
write('bump', .24, lambda t,n: (.35*math.sin(TAU*85*t)+.45*n)*math.exp(-t*22))
write('scrape', .8, lambda t,n: (.8*n+.08*math.sin(TAU*910*t+.9*math.sin(TAU*37*t)))*(.65+.35*math.sin(TAU*23*t))*math.exp(-t*2))
write('crash', 1.1, lambda t,n: (.45*math.sin(TAU*(42*t+12*t*t))+.65*n+.09*math.sin(TAU*1800*t)*math.exp(-t*9))*math.exp(-t*5))
