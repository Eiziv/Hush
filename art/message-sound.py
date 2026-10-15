# Renders media/message.ogg, Hush's message sound: two soft rising notes, made from scratch.
#   python3 art/message-sound.py && ffmpeg -y -i message.wav -c:a libvorbis -q:a 5 media/message.ogg
import wave

import numpy as np

RATE = 44100


def note(freq, length, start, total):
    t = np.arange(int(length * RATE)) / RATE
    # A sine with a little second and third harmonic, a 6 ms attack and a quick fade.
    tone = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(4 * np.pi * freq * t) + 0.06 * np.sin(6 * np.pi * freq * t)
    envelope = np.minimum(t / 0.006, 1) * np.exp(-t * 11)
    out = np.zeros(total)
    i = int(start * RATE)
    out[i:i + len(t)] = (tone * envelope)[: total - i]
    return out


total = int(0.55 * RATE)
sound = note(784.0, 0.45, 0.0, total) * 0.8 + note(1174.7, 0.45, 0.085, total)  # G5, then D6
sound = sound / np.max(np.abs(sound)) * 0.5  # about -6 dB: present, not loud

with wave.open("message.wav", "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
