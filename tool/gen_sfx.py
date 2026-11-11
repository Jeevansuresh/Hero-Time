# Synthesises the app's sound effects into small WAV files (same recipes as the web app).
import math, random, struct, sys, wave
SR = 22050
def blank(sec): return [0.0] * int(SR * sec)
def tone(buf, f, at, dur, typ='sine', gain=.16, to=None, attack=.01):
    s0 = int(at * SR); n = int(dur * SR); ph = 0.0
    for i in range(n):
        tt = i / SR
        freq = f * ((to / f) ** (tt / dur)) if to else f
        ph += 2 * math.pi * freq / SR
        x = ph % (2 * math.pi) / (2 * math.pi)
        v = {'sine': math.sin(ph), 'triangle': 4 * abs(x - .5) - 1, 'square': 1 if x < .5 else -1, 'sawtooth': 2 * x - 1}[typ]
        env = (tt / attack) if tt < attack else math.exp(-6.9 * (tt - attack) / max(1e-3, dur - attack))
        j = s0 + i
        if j < len(buf): buf[j] += v * gain * env
def noise(buf, at, dur, gain=.12, f0=500, f1=4000):
    s0 = int(at * SR); n = int(dur * SR); lp = 0.0; hp_prev = 0.0; lp2 = 0.0
    for i in range(n):
        tt = i / SR; fc = f0 * (f1 / f0) ** (tt / dur)
        a = 1 - math.exp(-2 * math.pi * fc / SR)
        x = random.uniform(-1, 1); lp += a * (x - lp); lp2 += a * .3 * (lp - lp2)
        v = lp - lp2
        env = math.sin(math.pi * tt / dur) ** 2
        j = s0 + i
        if j < len(buf): buf[j] += v * gain * 3 * env
def notes(buf, lst, step, **kw):
    for i, f in enumerate(lst): tone(buf, f, i * step, kw.pop('dur', .22) if False else kw.get('dur', .22), **{k: v for k, v in kw.items() if k != 'dur'})
S = {}
b = blank(.3); tone(b, 784, 0, .1, 'triangle', .14); tone(b, 1175, .055, .16, 'triangle', .12); S['check'] = b
b = blank(.2); tone(b, 660, 0, .12, 'sine', .1, to=420); S['undo'] = b
b = blank(.15); tone(b, 520, 0, .09, 'sine', .14, to=900); S['pop'] = b
b = blank(.35); tone(b, 220, 0, .22, 'sine', .16, to=140); tone(b, 165, .05, .25, 'triangle', .06, to=110); S['slip'] = b
b = blank(.75); notes(b, [659, 784, 988], .07, typ='triangle', gain=.11, dur=.3); tone(b, 1319, .22, .45, 'sine', .07); S['goal'] = b
b = blank(1.1); notes(b, [523, 659, 784, 1047], .09, typ='square', gain=.05, dur=.2); notes(b, [523, 659, 784, 1047], .09, typ='triangle', gain=.1, dur=.28); tone(b, 1568, .4, .6, 'sine', .06); S['levelup'] = b
b = blank(1.7); noise(b, 0, .5, .07, 300, 6000); notes(b, [392, 523, 659, 784, 1047, 1319], .07, typ='triangle', gain=.1, dur=.32)
for f in (1047, 1319, 1568): tone(b, f, .5, 1.1, 'sine', .05, attack=.05)
S['unlock'] = b
b = blank(.75); noise(b, 0, .45, .1, 200, 5000); tone(b, 180, 0, .45, 'sawtooth', .04, to=1400); tone(b, 1400, .42, .25, 'sine', .1, to=1760); S['transform'] = b
out = sys.argv[1]
for name, buf in S.items():
    peak = max(1e-6, max(abs(v) for v in buf)); k = min(1.0, .85 / peak) if peak > .85 else 1.0
    with wave.open(f'{out}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v * k * 1.6)) * 32000)) for v in buf))
print('wrote', len(S), 'sounds')
