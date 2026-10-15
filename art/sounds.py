# Renders Hush's message sounds into media/sounds/, all made from scratch.
#   python3 art/sounds.py      (needs numpy and ffmpeg)
import os
import subprocess
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "media", "sounds")


def tone(freq, length, partials=((1, 1.0), (2, 0.18), (3, 0.06)), attack=0.006, decay=11.0, sweep=1.0):
    """A note: partials as (multiple, level), a short attack, an exponential fade.
    sweep > 1 glides the pitch up over the note, < 1 down."""
    t = np.arange(int(length * RATE)) / RATE
    glide = np.linspace(1.0, sweep, len(t))
    phase = 2 * np.pi * freq * np.cumsum(glide) / RATE
    wave_ = sum(level * np.sin(multiple * phase) for multiple, level in partials)
    return wave_ * np.minimum(t / attack, 1) * np.exp(-t * decay)


def mix(length, *notes):
    """notes: (start in seconds, samples, level)"""
    out = np.zeros(int(length * RATE))
    for start, samples, level in notes:
        i = int(start * RATE)
        n = min(len(samples), len(out) - i)
        out[i:i + n] += samples[:n] * level
    return out


BELL = ((1, 1.0), (2.0, 0.45), (2.76, 0.25), (5.4, 0.08))  # bell-like, slightly inharmonic
GLASS = ((1, 1.0), (2.76, 0.3), (5.4, 0.12))

SOUNDS = {
    # The original: two soft rising notes, G5 then D6.
    "hush": (0.5, mix(0.55, (0, tone(784.0, 0.45), 0.8), (0.085, tone(1174.7, 0.45), 1))),
    # One soft note.
    "drop": (0.5, mix(0.3, (0, tone(880.0, 0.3, decay=14), 1))),
    # A tiny high pop, barely there.
    "pebble": (0.4, mix(0.12, (0, tone(1318.5, 0.12, attack=0.002, decay=40, sweep=0.92), 1))),
    # A light glassy ping.
    "glass": (0.32, mix(0.7, (0, tone(2093.0, 0.7, GLASS, attack=0.002, decay=7), 1))),
    # The quietest: a slow, soft rise.
    "feather": (0.28, mix(0.5, (0, tone(659.3, 0.45, attack=0.03, decay=8), 0.8), (0.12, tone(880.0, 0.38, attack=0.03, decay=9), 1))),
    # A short rising blip.
    "bubble": (0.42, mix(0.16, (0, tone(520.0, 0.16, ((1, 1.0), (2, 0.1)), attack=0.003, decay=22, sweep=2.0), 1))),
    # A soft bell, rings a little longer.
    "bell": (0.4, mix(0.95, (0, tone(698.5, 0.95, BELL, attack=0.003, decay=5), 1))),
    # Three quick rising notes, C6 E6 G6.
    "chime": (0.45, mix(0.5, (0, tone(1046.5, 0.32, decay=14), 0.8), (0.06, tone(1318.5, 0.32, decay=14), 0.85), (0.12, tone(1568.0, 0.36, decay=12), 1))),
    # Two soft low taps.
    "knock": (0.55, mix(0.26, (0, tone(392.0, 0.1, ((1, 1.0), (2, 0.35), (3, 0.15)), attack=0.002, decay=45), 1), (0.11, tone(392.0, 0.12, ((1, 1.0), (2, 0.35), (3, 0.15)), attack=0.002, decay=40), 0.9))),
    # The original turned around: two soft falling notes, D6 then G5.
    "fall": (0.5, mix(0.55, (0, tone(1174.7, 0.45), 0.8), (0.085, tone(784.0, 0.45), 1))),
}

os.makedirs(OUT, exist_ok=True)
for name, (peak, sound) in SOUNDS.items():
    sound = sound / np.max(np.abs(sound)) * peak
    fade = min(len(sound), int(0.01 * RATE))  # no click at the very end
    sound[-fade:] *= np.linspace(1, 0, fade)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)
    print(name, round(len(sound) / RATE, 2), "s")
