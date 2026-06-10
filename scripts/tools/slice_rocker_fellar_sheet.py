from pathlib import Path
from PIL import Image


SRC = Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 12_20_15 AM (1).png")
OUT = Path(r"C:\Users\jeremy\Documents\New project\assets\sprites\rocker_fellar")


def cutout(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = im.crop(box).convert("RGBA")
    px = crop.load()
    for y in range(crop.height):
        for x in range(crop.width):
            r, g, b, a = px[x, y]
            # The sheet background is white/very light gray. Fade only that out;
            # keep bright VFX colors and white highlights inside the art.
            if r > 232 and g > 232 and b > 232 and max(r, g, b) - min(r, g, b) < 18:
                px[x, y] = (r, g, b, 0)
    return crop


def save_trimmed(im: Image.Image, name: str) -> None:
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        pad = 8
        x0 = max(bbox[0] - pad, 0)
        y0 = max(bbox[1] - pad, 0)
        x1 = min(bbox[2] + pad, im.width)
        y1 = min(bbox[3] + pad, im.height)
        im = im.crop((x0, y0, x1, y1))
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(path)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SRC).convert("RGB")
    (OUT / "source_sheet.png").write_bytes(SRC.read_bytes())

    crops = {
        # DirectionalBillboard frame order: back, back-left, left, front-left,
        # front, front-right, right, back-right.
        "rocker_back.png": (700, 58, 910, 360),
        "rocker_back_left.png": (885, 58, 1095, 360),
        "rocker_left.png": (1060, 58, 1268, 360),
        "rocker_front_left.png": (1230, 58, 1448, 360),
        "rocker_front.png": (0, 58, 225, 360),
        "rocker_front_right.png": (165, 58, 365, 360),
        "rocker_right.png": (340, 58, 545, 360),
        "rocker_back_right.png": (530, 58, 735, 360),
        # Combat states.
        "state_idle.png": (8, 395, 148, 655),
        "state_windup.png": (165, 395, 325, 655),
        "state_charge.png": (335, 398, 520, 655),
        "state_sonic.png": (530, 395, 735, 655),
        "state_cable_whip.png": (750, 395, 965, 655),
        "state_staggered.png": (980, 395, 1168, 655),
        "state_defeated.png": (1165, 395, 1360, 655),
        # Body part cutouts and UI icons.
        "part_head.png": (18, 710, 145, 855),
        "part_torso.png": (160, 710, 300, 855),
        "part_left_arm.png": (310, 710, 410, 850),
        "part_right_arm.png": (405, 710, 500, 850),
        "part_left_leg.png": (30, 880, 125, 1075),
        "part_right_leg.png": (160, 880, 250, 1075),
        "part_stage_core.png": (285, 875, 430, 1075),
        "icon_head.png": (1035, 725, 1160, 850),
        "icon_torso.png": (1165, 725, 1285, 850),
        "icon_arms.png": (1310, 725, 1435, 850),
        "icon_legs.png": (1040, 900, 1160, 1075),
        "icon_stage_core.png": (1250, 900, 1405, 1075),
        # VFX elements.
        "vfx_charge_warning_cone.png": (485, 710, 660, 875),
        "vfx_sonic_shockwave_ring.png": (670, 710, 835, 875),
        "vfx_cable_whip_slash_arc.png": (855, 710, 1010, 875),
        "vfx_soul_battery_rupture.png": (475, 895, 650, 1075),
        "vfx_sparks.png": (655, 930, 770, 1075),
        "vfx_feedback_static.png": (775, 930, 885, 1075),
        "vfx_bass_wave_distortion.png": (885, 930, 1005, 1075),
    }

    for name, box in crops.items():
        save_trimmed(cutout(sheet, box), name)


if __name__ == "__main__":
    main()
