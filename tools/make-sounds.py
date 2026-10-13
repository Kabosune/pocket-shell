#!/usr/bin/env python3
"""Synthesize Pocket Shell's UI sound packs.

Writes 48 kHz mono 16-bit WAVs (what Qt's SoundEffect wants) to
quickshell/sounds/<pack>/<event>.wav. Everything is generated here from
plain waveforms, so the sounds are original and can be tweaked and
regenerated:

    python3 tools/make-sounds.py

Packs:
    soft  warm bell/marimba tones (Dusk Tide)
    chip  square-wave chiptune bleeps (Stylus)

Events: move, select, back, page, open, toggle-on, toggle-off, launch,
error, notice, theme, boot.
"""

import os
import struct
import wave

import numpy as np

RATE = 48000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quickshell", "sounds")


def note(name):
    """Frequency of a note like 'C5' or 'F#4'."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4,
             "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n, attack=0.004, decay=None, release=0.006):
    """Short attack, optional exponential decay, short release (no clicks)."""
    env = np.ones(n)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    env[:a] = np.linspace(0, 1, a)
    if decay:
        env *= np.exp(-np.arange(n) / (RATE * decay))
    env[-r:] *= np.linspace(1, 0, r)
    return env


# --- Voices

def bell(freq, length, decay=0.12, level=1.0):
    """Soft bell: sine with a quiet octave and a hint of a 3rd harmonic."""
    x = t(length)
    tone = (np.sin(2 * np.pi * freq * x)
            + 0.28 * np.sin(2 * np.pi * freq * 2 * x) * np.exp(-x / (decay * 0.5))
            + 0.08 * np.sin(2 * np.pi * freq * 3 * x) * np.exp(-x / (decay * 0.3)))
    return level * tone * envelope(len(x), attack=0.003, decay=decay)


def marimba(freq, length, level=1.0):
    """Woody, quick decay: sine plus a short inharmonic strike."""
    x = t(length)
    tone = (np.sin(2 * np.pi * freq * x)
            + 0.35 * np.sin(2 * np.pi * freq * 3.9 * x) * np.exp(-x / 0.012))
    return level * tone * envelope(len(x), attack=0.002, decay=length * 0.35)


def square(freq, length, duty=0.5, level=1.0, decay=None):
    """Chip voice: pulse wave with a hard-ish edge."""
    x = t(length)
    phase = (freq * x) % 1.0
    tone = np.where(phase < duty, 1.0, -1.0)
    return level * tone * envelope(len(x), attack=0.001, decay=decay, release=0.004)


def triangle(freq, length, level=1.0, decay=None):
    x = t(length)
    phase = (freq * x) % 1.0
    tone = 4 * np.abs(phase - 0.5) - 1
    return level * tone * envelope(len(x), attack=0.001, decay=decay, release=0.004)


def noise(length, level=1.0, decay=0.05, seed=1):
    rng = np.random.default_rng(seed)
    x = rng.uniform(-1, 1, int(RATE * length))
    return level * x * envelope(len(x), attack=0.001, decay=decay)


def lowpass(x, cutoff):
    """One-pole low-pass, enough to round off edges."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def seq(*parts, gap=0.0):
    """Play parts one after another."""
    silence = np.zeros(int(RATE * gap))
    out = []
    for i, p in enumerate(parts):
        if i:
            out.append(silence)
        out.append(p)
    return np.concatenate(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(offset, part):
    return np.concatenate([np.zeros(int(RATE * offset)), part])


def sweep(f0, f1, length, voice="square", duty=0.5, level=1.0):
    x = t(length)
    freq = f0 * (f1 / f0) ** (x / length)
    phase = np.cumsum(freq) / RATE
    if voice == "square":
        tone = np.where(phase % 1.0 < duty, 1.0, -1.0)
    else:
        tone = np.sin(2 * np.pi * phase)
    return level * tone * envelope(len(x), attack=0.002, release=0.01)


# --- Packs

def soft_pack():
    return {
        "move": lowpass(marimba(note("E6"), 0.05, level=0.5), 6000),
        "select": mix(bell(note("A5"), 0.16, decay=0.06), at(0.045, bell(note("E6"), 0.2, decay=0.08))),
        "back": mix(bell(note("E6"), 0.12, decay=0.05, level=0.8), at(0.045, bell(note("A5"), 0.2, decay=0.08))),
        "page": mix(lowpass(noise(0.14, level=0.25, decay=0.05), 3000),
                    marimba(note("D6"), 0.12, level=0.55)),
        "open": mix(bell(note("C6"), 0.14, decay=0.06), at(0.06, bell(note("G6"), 0.3, decay=0.12))),
        "toggle-on": mix(marimba(note("D6"), 0.1), at(0.05, marimba(note("A6"), 0.18))),
        "toggle-off": mix(marimba(note("A6"), 0.1), at(0.05, marimba(note("D6"), 0.18))),
        "launch": mix(bell(note("C6"), 0.4, decay=0.15, level=0.7),
                      at(0.06, bell(note("E6"), 0.4, decay=0.15, level=0.7)),
                      at(0.12, bell(note("G6"), 0.4, decay=0.15, level=0.7)),
                      at(0.18, bell(note("C7"), 0.5, decay=0.2, level=0.7))),
        "error": lowpass(mix(bell(note("D4"), 0.22, decay=0.08), bell(note("D#4") * 0.995, 0.22, decay=0.08)), 1800),
        "notice": mix(bell(note("G6"), 0.3, decay=0.12, level=0.8), at(0.08, bell(note("D7"), 0.3, decay=0.1, level=0.5))),
        "theme": mix(bell(note("G5"), 0.6, decay=0.2, level=0.6),
                     at(0.08, bell(note("B5"), 0.6, decay=0.2, level=0.6)),
                     at(0.16, bell(note("D6"), 0.6, decay=0.2, level=0.6)),
                     at(0.24, bell(note("G6"), 0.8, decay=0.3, level=0.7))),
        "boot": mix(lowpass(mix(bell(note("C4"), 1.4, decay=0.6, level=0.5),
                                at(0.05, bell(note("G4"), 1.3, decay=0.55, level=0.45)),
                                at(0.1, bell(note("E5"), 1.2, decay=0.5, level=0.4))), 2500),
                    at(0.35, bell(note("G6"), 0.9, decay=0.3, level=0.45)),
                    at(0.5, bell(note("C7"), 1.0, decay=0.35, level=0.4))),
    }


def chip_pack():
    q = 0.045  # one chip "step"
    return {
        "move": square(note("C7"), 0.022, duty=0.25, level=0.45),
        "select": seq(square(note("E6"), q, duty=0.5), square(note("A6"), q * 1.6, duty=0.5, decay=0.05)),
        "back": seq(square(note("A6"), q, duty=0.5), square(note("E6"), q * 1.6, duty=0.5, decay=0.05)),
        "page": sweep(note("C7"), note("G5"), 0.08, duty=0.25, level=0.7),
        "open": seq(square(note("G5"), 0.035, duty=0.25), square(note("C6"), 0.035, duty=0.25),
                    square(note("G6"), 0.09, duty=0.25, decay=0.06)),
        "toggle-on": seq(square(note("D6"), 0.04, duty=0.125), square(note("D7"), 0.08, duty=0.125, decay=0.05)),
        "toggle-off": seq(square(note("D7"), 0.04, duty=0.125), square(note("D6"), 0.08, duty=0.125, decay=0.05)),
        "launch": seq(square(note("G5"), q), square(note("D6"), q), square(note("G6"), q),
                      mix(square(note("B6"), 0.22, decay=0.12), triangle(note("G4"), 0.22, decay=0.12, level=0.6))),
        "error": mix(square(110, 0.18, duty=0.5, level=0.6, decay=0.2), square(116, 0.18, duty=0.5, level=0.4, decay=0.2)),
        "notice": seq(square(note("C7"), 0.05, duty=0.25), square(note("G7"), 0.1, duty=0.25, decay=0.06)),
        "theme": seq(square(note("C6"), q, duty=0.25), square(note("E6"), q, duty=0.25),
                     square(note("A6"), q, duty=0.25), square(note("E7"), 0.18, duty=0.25, decay=0.1)),
        "boot": mix(seq(square(note("E6"), 0.07, duty=0.25), square(note("A5"), 0.07, duty=0.25),
                        square(note("E6"), 0.07, duty=0.25), square(note("B6"), 0.07, duty=0.25),
                        np.zeros(int(RATE * 0.07)),
                        square(note("A6"), 0.32, duty=0.25, decay=0.18)),
                    seq(triangle(note("A3"), 0.28, decay=0.3, level=0.7),
                        triangle(note("E4"), 0.28, decay=0.3, level=0.7),
                        triangle(note("A4"), 0.36, decay=0.3, level=0.7))),
    }


# Peak level per event, so ticks are quiet and big moments are louder.
LEVELS = {
    "move": 0.22, "select": 0.42, "back": 0.38, "page": 0.38, "open": 0.42,
    "toggle-on": 0.4, "toggle-off": 0.36, "launch": 0.5, "error": 0.45,
    "notice": 0.42, "theme": 0.5, "boot": 0.5,
}


def write(path, samples, peak):
    samples = samples / max(1e-9, np.max(np.abs(samples))) * peak
    data = np.clip(samples * 32767, -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    for pack, events in (("soft", soft_pack()), ("chip", chip_pack())):
        folder = os.path.join(ROOT, pack)
        os.makedirs(folder, exist_ok=True)
        for name, samples in events.items():
            write(os.path.join(folder, f"{name}.wav"), samples, LEVELS[name])
        print(f"{pack}: {len(events)} sounds")


if __name__ == "__main__":
    main()
