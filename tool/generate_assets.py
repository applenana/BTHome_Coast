"""Generate platform icon variants and a seamless, original ocean ambience."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MASTER_ICON = ROOT / "assets" / "branding" / "app_icon_master.png"


def _save_resized(source: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), Image.Resampling.LANCZOS).save(
        path,
        format="PNG",
        optimize=True,
    )


def _extract_white_mark(source: Image.Image) -> Image.Image:
    rgba = source.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (255, 255, 255, 0))
    source_pixels = rgba.load()
    output_pixels = output.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _ = source_pixels[x, y]
            brightness = max(red, green, blue)
            chroma = brightness - min(red, green, blue)
            alpha = max(0, min(255, (brightness - 188) * 5 - chroma * 5))
            output_pixels[x, y] = (255, 255, 255, alpha)
    return output


def _rounded_square(source: Image.Image, radius_fraction: float = 0.24) -> Image.Image:
    rounded = source.convert("RGBA")
    mask = Image.new("L", rounded.size, 0)
    draw = ImageDraw.Draw(mask)
    radius = round(min(rounded.size) * radius_fraction)
    draw.rounded_rectangle(
        (0, 0, rounded.width - 1, rounded.height - 1),
        radius=radius,
        fill=255,
    )
    rounded.putalpha(mask)
    return rounded


def generate_icons() -> None:
    master = Image.open(MASTER_ICON).convert("RGB")
    rounded_master = _rounded_square(master)
    _save_resized(
        rounded_master,
        ROOT / "assets" / "branding" / "app_icon.png",
        256,
    )

    legacy_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in legacy_sizes.items():
        _save_resized(
            rounded_master,
            android_res / folder / "ic_launcher.png",
            size,
        )

    mark = _extract_white_mark(Image.open(MASTER_ICON))
    bounds = mark.getbbox()
    if bounds is None:
        raise RuntimeError("Could not extract the white icon mark")
    mark = mark.crop(bounds)
    foreground_sizes = {
        "drawable-mdpi": 108,
        "drawable-hdpi": 162,
        "drawable-xhdpi": 216,
        "drawable-xxhdpi": 324,
        "drawable-xxxhdpi": 432,
    }
    for folder, canvas_size in foreground_sizes.items():
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (255, 255, 255, 0))
        target_width = round(canvas_size * 0.62)
        target_height = round(mark.height * target_width / mark.width)
        resized_mark = mark.resize(
            (target_width, target_height),
            Image.Resampling.LANCZOS,
        )
        offset = (
            (canvas_size - target_width) // 2,
            (canvas_size - target_height) // 2,
        )
        canvas.alpha_composite(resized_mark, offset)
        path = android_res / folder / "ic_launcher_foreground.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(path, format="PNG", optimize=True)

    windows_icon = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    rounded_master.save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def generate_ocean_ambience() -> None:
    sample_rate = 22_050
    duration_seconds = 24
    crossfade_seconds = 2
    output_count = sample_rate * duration_seconds
    crossfade_count = sample_rate * crossfade_seconds
    generated_count = output_count + crossfade_count
    rng = random.Random(0xB7_572)

    fast = 0.0
    medium = 0.0
    slow = 0.0
    generated: list[float] = []
    for index in range(generated_count):
        white = rng.uniform(-1.0, 1.0)
        fast += 0.18 * (white - fast)
        medium += 0.025 * (white - medium)
        slow += 0.0022 * (white - slow)
        time = index / sample_rate
        swell = (
            0.58
            + 0.21 * math.sin(2 * math.pi * time / 7.8 + 0.4)
            + 0.13 * math.sin(2 * math.pi * time / 3.7 + 2.1)
        )
        foam = fast - medium
        body = medium * 0.72 + slow * 0.9
        distant_rumble = math.sin(2 * math.pi * 52.0 * time) * 0.006
        generated.append((body + foam * 0.23) * swell + distant_rumble)

    blend: list[float] = []
    for index in range(crossfade_count):
        amount = index / (crossfade_count - 1)
        tail = generated[output_count + index]
        head = generated[index]
        blend.append(tail * (1.0 - amount) + head * amount)
    samples = generated[crossfade_count:output_count] + blend

    peak = max(abs(sample) for sample in samples) or 1.0
    gain = 0.72 / peak
    pcm = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample * gain))
        pcm.extend(struct.pack("<h", round(value * 32767)))

    output_path = ROOT / "assets" / "audio" / "gentle_shore.wav"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output_path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm)


if __name__ == "__main__":
    generate_icons()
    generate_ocean_ambience()
