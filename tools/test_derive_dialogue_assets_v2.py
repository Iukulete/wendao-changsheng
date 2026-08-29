from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image, ImageDraw

from derive_dialogue_assets_v2 import derive


def synthetic_portrait(path: Path, size: tuple[int, int] = (1024, 1536)) -> None:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((360, 90, 660, 390), fill=(210, 180, 160, 255))
    draw.rectangle((245, 320, 775, 1280), fill=(30, 65, 80, 255))
    image.save(path, format="PNG")


def test_derive_dialogue_assets_preserves_transparency_and_sizes(tmp_path: Path) -> None:
    source = tmp_path / "source.png"
    bust = tmp_path / "dialogue" / "default_bust.png"
    avatar = tmp_path / "dialogue" / "avatar.png"
    synthetic_portrait(source)

    derive(source, bust, avatar, bust_focus_y=0.36, avatar_focus_y=0.16, focus_x=0.0)

    with Image.open(bust) as image:
        assert image.size == (1024, 1024)
        assert image.mode == "RGBA"
        assert image.getchannel("A").getbbox() is not None
    with Image.open(avatar) as image:
        assert image.size == (512, 512)
        assert image.mode == "RGBA"
        assert image.getchannel("A").getbbox() is not None


def test_derive_dialogue_assets_rejects_wrong_master_size(tmp_path: Path) -> None:
    source = tmp_path / "wrong.png"
    Image.new("RGBA", (512, 512), (20, 20, 20, 255)).save(source, format="PNG")

    with pytest.raises(RuntimeError, match="1024x1536"):
        derive(
            source,
            tmp_path / "bust.png",
            tmp_path / "avatar.png",
            bust_focus_y=0.36,
            avatar_focus_y=0.16,
            focus_x=0.0,
        )
