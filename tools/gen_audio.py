"""Procedurally generated BGM and SFX for Eastern Barrage (numpy-vectorized).

6 BGM tracks >= 3 min each, full A-A-B-A'-C-A structure, loop-friendly.
4 SFX for shoot/bomb/kill/hit.
"""
import math
import wave
import struct
import random
from pathlib import Path
import numpy as np

SR = 22050  # 22 kHz is plenty for synthy chiptune BGM and halves compute
# Project root = tools/.. (this file lives in project/tools/)
ROOT = Path(__file__).resolve().parent.parent
random.seed(42)

# ---------------------------------------------------------------- helpers

def note_freq(midi):
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))

SCALES = {
    "minor":       np.array([0, 2, 3, 5, 7, 8, 10, 12], dtype=int),
    "major":       np.array([0, 2, 4, 5, 7, 9, 11, 12], dtype=int),
    "dorian":      np.array([0, 2, 3, 5, 7, 9, 10, 12], dtype=int),
    "phrygian_dom":np.array([0, 1, 4, 5, 7, 8, 10, 12], dtype=int),
    "penta_minor": np.array([0, 3, 5, 7, 10, 12, 15, 17], dtype=int),
}

def adsr(n, a=0.01, d=0.15, s=0.5, r=0.25):
    n = int(n)
    out = np.zeros(n, dtype=np.float32)
    na = int(a * SR); nd = int(d * SR); nr = int(r * SR)
    ns = n - na - nd - nr
    if ns < 0:
        nr = max(0, nr - (-ns))
        ns = 0
    if na > 0 and na < n:
        out[:na] = np.linspace(0.0, 1.0, na, dtype=np.float32)
    if nd > 0 and na + nd <= n:
        out[na:na+nd] = 1.0 - (1.0 - s) * np.linspace(0.0, 1.0, nd, dtype=np.float32)
    if ns > 0:
        out[na+nd:na+nd+ns] = s
    rs = na + nd + ns
    if nr > 0 and rs + nr <= n:
        out[rs:rs+nr] = s * np.linspace(1.0, 0.0, nr, dtype=np.float32)
    return out

def osc_sine(f, n):
    t = np.arange(n, dtype=np.float32) / SR
    return np.sin(2 * np.pi * f * t)

def osc_saw(f, n):
    t = np.arange(n, dtype=np.float32) / SR
    v = np.zeros(n, dtype=np.float32)
    for k in range(1, 6):
        v += np.sin(2 * np.pi * k * f * t) / k
    return v * 0.5

def osc_square(f, n):
    t = np.arange(n, dtype=np.float32) / SR
    v = np.zeros(n, dtype=np.float32)
    for k in range(1, 6, 2):
        v += np.sin(2 * np.pi * k * f * t) / k
    return v * 0.6

def osc_triangle(f, n):
    t = np.arange(n, dtype=np.float32) / SR
    v = np.zeros(n, dtype=np.float32)
    for k in range(1, 5):
        v += ((-1) ** (k - 1)) * np.sin(2 * np.pi * k * f * t) / (k * k)
    return v * 0.8

def osc_noise(n):
    return np.random.uniform(-1, 1, n).astype(np.float32)

def karplus_strong(f, n, decay=0.992):
    delay = max(2, int(SR / f))
    buf = np.random.uniform(-1, 1, delay).astype(np.float32)
    out = np.zeros(n, dtype=np.float32)
    for i in range(n):
        s = buf[i % delay]
        nxt = buf[(i + 1) % delay]
        buf[i % delay] = decay * 0.5 * (s + nxt)
        out[i] = s
    return out

def voice_render(f, n, voice):
    if voice == "sine":   return osc_sine(f, n)
    if voice == "square": return osc_square(f, n)
    if voice == "saw":    return osc_saw(f, n)
    if voice == "tri":    return osc_triangle(f, n)
    if voice == "pluck":  return karplus_strong(f, n, decay=0.992)
    return osc_sine(f, n)

def synth_track(events, total_sec, voice="sine", vol=0.3, reverb=True):
    n_total = int(total_sec * SR)
    out = np.zeros(n_total, dtype=np.float32)
    t = 0.0
    for midi, dur in events:
        f = note_freq(midi)
        ns = int(dur * SR)
        if ns <= 0: continue
        # ADSR params depend on voice
        if voice == "pluck":
            env = adsr(ns, a=0.001, d=0.3, s=0.2, r=0.7)
        elif voice == "square":
            env = adsr(ns, a=0.005, d=0.05, s=0.4, r=0.1)
        elif voice == "saw":
            env = adsr(ns, a=0.005, d=0.2, s=0.5, r=0.3)
        elif voice == "tri":
            env = adsr(ns, a=0.02, d=0.2, s=0.6, r=0.4)
        else:
            env = adsr(ns, a=0.02, d=0.1, s=0.6, r=0.25)
        w = voice_render(f, ns, voice) * env * vol
        start = int(t * SR)
        if start + ns > n_total:
            ns = max(0, n_total - start)
            w = w[:ns]
        if ns > 0:
            out[start:start+ns] += w
        t += dur
    if reverb:
        delay = int(0.18 * SR)
        if delay < n_total:
            echo = np.zeros(n_total, dtype=np.float32)
            echo[delay:] = out[:-delay] * 0.25
            out += echo
    return out

def drum_track(total_sec, bpm, style="soft"):
    n_total = int(total_sec * SR)
    out = np.zeros(n_total, dtype=np.float32)
    beat = 60.0 / bpm
    step = beat / 4
    step_index = 0
    t = 0.0
    while t < total_sec:
        idx = step_index % 16
        if style == "soft":
            hits = {0: ("kick", 0.6), 4: ("snare", 0.4),
                    8: ("kick", 0.5), 12: ("snare", 0.35)}
            hit = hits.get(idx)
        else:
            hit = None
            if idx % 4 == 0: hit = ("kick", 0.8)
            elif idx % 4 == 2: hit = ("snare", 0.55)
        # hat on off-beats
        if idx % 2 == 1:
            start = int(t * SR)
            ns = int(0.05 * SR)
            if start + ns < n_total and ns > 0:
                h = osc_noise(ns)
                env = adsr(ns, a=0.001, d=0.03, s=0.0, r=0.0)
                gain = 0.12 if style == "soft" else 0.18
                out[start:start+ns] += h * env * gain
        if hit is not None:
            start = int(t * SR)
            kind, vol = hit
            if kind == "kick":
                ns = int(0.35 * SR)
                if start + ns < n_total:
                    t_arr = np.arange(ns, dtype=np.float32) / SR
                    f = 110 + (40 - 110) * t_arr / 0.35
                    phase = 2 * np.pi * np.cumsum(f) / SR
                    b = np.sin(phase) * (1.0 - t_arr / 0.35) ** 1.5
                    out[start:start+ns] += b * vol
            elif kind == "snare":
                ns = int(0.2 * SR)
                if start + ns < n_total:
                    b = osc_noise(ns)
                    env = adsr(ns, a=0.001, d=0.08, s=0.0, r=0.0)
                    body = osc_sine(180, ns)
                    b = b * env * 1.6 + body * env * 0.2
                    out[start:start+ns] += b * vol
        t += step
        step_index += 1
    return out

def arpeggio_loop(root, scale, octaves, bars, beat=0.18, pattern=None):
    if pattern is None:
        pattern = [0, 2, 4, 6, 4, 2, 5, 3]
    seq = []
    for _ in range(bars):
        for step, pidx in enumerate(pattern):
            octv = octaves[(step // 4) % len(octaves)]
            semis = int(scale[pidx % len(scale)])
            midi = 12 * octv + (semis % 12) + (root % 12)
            seq.append((midi, beat))
    return seq

def melody_phrase(root, scale, octave=5, bars=4, dur=0.25, seed=0):
    rng = random.Random(seed)
    seq = []
    intervals = [0, 1, 2, 3, -1, -2]
    cur = int(scale[0])
    t_left = bars * 8
    while t_left > 0:
        step_len = rng.choice([1, 1, 1, 2, 2, 4])
        step_len = min(step_len, t_left)
        idx_in = int(cur % 12) if int(cur % 12) in list(scale) else 0
        # find closest scale index
        if int(cur % 12) not in list(scale):
            idx_in = 0
        else:
            idx_in = list(scale).index(int(cur % 12))
        mv = rng.choice(intervals)
        new_idx = (idx_in + mv) % len(scale)
        midi = 12 * octave + int(scale[new_idx]) % 12 + (root % 12)
        seq.append((midi, dur * step_len))
        cur = int(scale[new_idx])
        t_left -= step_len
    return seq

def pad_chord(root, scale, octave, bars_list, beat=0.5, vol=0.18):
    seq = []
    for bo, sidxs in bars_list:
        chord_dur = beat * 8
        for sidx in sidxs:
            sm = 12 * octave + int(scale[sidx % len(scale)]) % 12 + bo + (root % 12)
            seq.append((sm, chord_dur))
    return seq

def build_bgm(out_path, root_midi, scale_name, total_sec, bpm, drum_style,
              melody_voice="sine", arp_voice="pluck", pad_voice="tri"):
    scale = SCALES[scale_name]
    n_total = int(total_sec * SR)
    out = np.zeros(n_total, dtype=np.float32)
    sec = total_sec / 6.0
    sections = ["A", "A", "B", "Ap", "C", "A"]
    arp_seed = {"A": 11, "B": 27, "Ap": 41, "C": 7}.get
    pad_bars = [
        (0, [0, 2, 4]),
        (0, [0, 2, 4]),
        (3, [0, 2, 4]),
        (0, [0, 2, 4]),
        (5, [0, 2, 4]),
        (0, [0, 2, 4]),
    ]
    arp1 = [0, 2, 4, 2, 5, 4, 2, 0]
    arp2 = [0, 4, 7, 4, 5, 2, 4, 0]
    arpb = [0, 1, 4, 1, 0, 2, 1, 0]
    for si, name in enumerate(sections):
        sec_dur = sec
        arp = arpeggio_loop(root_midi, scale,
                            octaves=[4, 5] if name != "C" else [3, 4],
                            bars=8, beat=0.18,
                            pattern=(arpb if name == "B"
                                     else arp2 if name == "C"
                                     else arp1))
        pad_bars_used = (pad_bars * 4)[:4]
        pad = pad_chord(root_midi, scale, 3, pad_bars_used, beat=sec_dur/8, vol=0.16)
        mel = melody_phrase(root_midi, scale, octave=5, bars=8, dur=0.25,
                            seed=arp_seed(name) + si)
        arp_buf = synth_track(arp, sec_dur, voice=arp_voice, vol=0.18)
        pad_buf = synth_track(pad, sec_dur, voice=pad_voice, vol=0.20, reverb=True)
        mel_buf = synth_track(mel, sec_dur, voice=melody_voice, vol=0.22)
        start = int((sec * si) * SR)
        if start + len(arp_buf) <= n_total: out[start:start+len(arp_buf)] += arp_buf
        if start + len(pad_buf) <= n_total: out[start:start+len(pad_buf)] += pad_buf
        if start + len(mel_buf) <= n_total: out[start:start+len(mel_buf)] += mel_buf
    if drum_style != "none":
        drums = drum_track(total_sec, bpm, style=drum_style)
        out += drums * 0.7
    fade = int(0.5 * SR)
    out[:fade] *= np.linspace(0.0, 1.0, fade, dtype=np.float32)
    out[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
    write_wav(out_path, out)
    return out_path

def write_wav(path, samples):
    samples = samples.astype(np.float32)
    peak = max(1e-9, float(np.max(np.abs(samples))))
    g = 0.9 / peak
    data = np.clip(samples * g, -1.0, 1.0)
    data16 = (data * 32767).astype(np.int16)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data16.tobytes())

# ---------------- SFX -------------------
def sfx_shoot():
    n = int(0.12 * SR); t = np.arange(n, dtype=np.float32) / SR
    f = 1200 - 6000 * t
    env = (1.0 - t / 0.12)
    buf = np.sin(2 * np.pi * np.cumsum(f) / SR) * env
    nb = osc_noise(n)
    tn = int(0.005 * SR)
    buf[:tn] += nb[:tn] * 0.4 * (1 - np.arange(tn) / tn)
    write_wav(ROOT / "audio" / "sfx" / "sfx_shoot.wav", buf)

def sfx_bomb():
    n = int(1.2 * SR); t = np.arange(n, dtype=np.float32) / SR
    f = 600 - 400 * t
    buf = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-3 * t)
    nb = osc_noise(n)
    env = np.exp(-4 * t)
    buf += nb * env * 0.6 * (1.0 - t / 1.2)
    write_wav(ROOT / "audio" / "sfx" / "sfx_bomb.wav", buf)

def sfx_kill():
    n = int(0.25 * SR); t = np.arange(n, dtype=np.float32) / SR
    f = 180 + 1400 * np.exp(-10 * t)
    buf = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-7 * t)
    for k in [2, 3, 4]:
        buf += np.sin(2 * np.pi * 3 * k * 180 * t) * np.exp(-10 * t) * 0.15
    tn = int(0.02 * SR)
    nb = osc_noise(tn)
    buf[:tn] += nb * 0.3 * (1 - np.arange(tn) / tn)
    write_wav(ROOT / "audio" / "sfx" / "sfx_kill.wav", buf)

def sfx_hit():
    n = int(0.5 * SR); t = np.arange(n, dtype=np.float32) / SR
    f = 200 - 160 * t
    buf = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-4 * t)
    nb = osc_noise(n)
    env = np.exp(-6 * t)
    buf += nb * env * 0.7
    write_wav(ROOT / "audio" / "sfx" / "sfx_hit.wav", buf)

def main():
    bgm_dir = ROOT / "audio" / "bgm"
    sfx_dir = ROOT / "audio" / "sfx"
    bgm_dir.mkdir(parents=True, exist_ok=True)
    sfx_dir.mkdir(parents=True, exist_ok=True)
    jobs = [
        ("bgm_stage1_mid.wav",   57, "dorian",        192, 108, "soft",  "sine",  "pluck", "tri"),
        ("bgm_stage1_boss.wav",  57, "dorian",        190, 138, "hard",  "square","saw",   "saw"),
        ("bgm_stage2_mid.wav",   60, "major",         192, 98,  "soft",  "sine",  "pluck", "tri"),
        ("bgm_stage2_boss.wav",  57, "minor",         194, 132, "hard",  "square","saw",   "saw"),
        ("bgm_stage3_mid.wav",   50, "penta_minor",   192, 112, "soft",  "tri",   "pluck", "tri"),
        ("bgm_stage3_boss.wav",  50, "phrygian_dom",  196, 145, "hard",  "square","saw",   "saw"),
    ]
    import multiprocessing as mp
    worker_args = [(str(bgm_dir / j[0]),) + j[1:] for j in jobs]
    with mp.Pool(processes=min(6, mp.cpu_count())) as pool:
        pool.starmap(build_bgm_worker, worker_args)
    print("BGM done")
    sfx_shoot(); print("sfx_shoot")
    sfx_bomb();  print("sfx_bomb")
    sfx_kill();  print("sfx_kill")
    sfx_hit();   print("sfx_hit")
    print("ALL DONE")

def build_bgm_worker(path, root, scale, sec, bpm, drum, m, a, p):
    return build_bgm(Path(path), root, scale, sec, bpm, drum, m, a, p)

if __name__ == "__main__":
    # run the workers in __main__ guard so multiprocessing spawn works on Windows
    bgm_dir = ROOT / "audio" / "bgm"
    sfx_dir = ROOT / "audio" / "sfx"
    bgm_dir.mkdir(parents=True, exist_ok=True)
    sfx_dir.mkdir(parents=True, exist_ok=True)
    jobs = [
        ("bgm_stage1_mid.wav",   57, "dorian",        192, 108, "soft",  "sine",  "pluck", "tri"),
        ("bgm_stage1_boss.wav",  57, "dorian",        190, 138, "hard",  "square","saw",   "saw"),
        ("bgm_stage2_mid.wav",   60, "major",         192, 98,  "soft",  "sine",  "pluck", "tri"),
        ("bgm_stage2_boss.wav",  57, "minor",         194, 132, "hard",  "square","saw",   "saw"),
        ("bgm_stage3_mid.wav",   50, "penta_minor",   192, 112, "soft",  "tri",   "pluck", "tri"),
        ("bgm_stage3_boss.wav",  50, "phrygian_dom",  196, 145, "hard",  "square","saw",   "saw"),
    ]
    worker_args = [(str(bgm_dir / j[0]),) + j[1:] for j in jobs]
    import multiprocessing as mp
    ctx = mp.get_context("spawn")
    with ctx.Pool(processes=min(6, mp.cpu_count())) as pool:
        res = pool.starmap_async(build_bgm_worker, worker_args)
        res.get(timeout=600)
    print("BGM done")
    sfx_shoot(); print("sfx_shoot")
    sfx_bomb();  print("sfx_bomb")
    sfx_kill();  print("sfx_kill")
    sfx_hit();   print("sfx_hit")
    print("ALL DONE")