"""Check actual time offsets and overlapping tracks in the generated PCM."""
import array
import math
import pathlib
import sys
import wave


def load(path, length_ms, channels):
    with wave.open(str(path), "rb") as source:
        assert (source.getframerate(), source.getnchannels(), source.getsampwidth()) == (16000, channels, 2)
        assert source.getnframes() == length_ms * 16
        samples = array.array("h", source.readframes(source.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        return samples[::channels]


def component(samples, start_ms, end_ms, frequency):
    start = start_ms * 16
    block = samples[start : end_ms * 16]
    re = sum(value * math.cos(2 * math.pi * frequency * idx / 16000) for idx, value in enumerate(block))
    im = sum(value * math.sin(2 * math.pi * frequency * idx / 16000) for idx, value in enumerate(block))
    return math.hypot(re, im) / len(block)


root = pathlib.Path(sys.argv[1])
scene = load(root / "cena.wav", 2000, 2)
segment = load(root / "segmento.wav", 1000, 2)
silence = load(root / "silencio.wav", 2000, 1)
assert not any(silence)
assert not any(scene[: 450 * 16])
assert component(scene, 550, 650, 440) > 500
assert component(scene, 550, 650, 660) < 5
assert component(scene, 900, 1000, 440) > 500
assert 200 < component(scene, 900, 1000, 660) < component(scene, 900, 1000, 440)
assert not any(scene[1550 * 16 :])
assert component(segment, 100, 200, 440) > 500
assert component(segment, 370, 470, 660) > 200
print("OK: atrasos, sobreposição, volume, fatia por segmento e silêncio.")
