from collections import deque
from pathlib import Path

from PIL import Image


OUT = Path(r"C:\Users\jeremy\Documents\New project\assets\sprites\rocker_fellar")

SOURCES = [
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_22_23 PM.png"), "rocker_front.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_27_08 PM.png"), "rocker_front_right.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_27_22 PM.png"), "rocker_right.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_30_35 PM.png"), "rocker_back_right.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_32_39 PM.png"), "rocker_back.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_36_02 PM.png"), "rocker_back_left.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 06_50_52 PM.png"), "rocker_left.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 07_11_09 PM.png"), "rocker_front_left.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 07_14_13 PM.png"), "state_windup.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 07_17_05 PM.png"), "state_charge.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 07_20_43 PM.png"), "state_sonic.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 07_39_16 PM.png"), "state_cable_whip.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 07_58_46 PM.png"), "state_staggered.png"),
    (Path(r"C:\Users\jeremy\Downloads\ChatGPT Image Jun 10, 2026, 08_04_10 PM.png"), "state_defeated.png"),
]


def is_checker_pixel(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return r >= 222 and g >= 222 and b >= 222 and max(r, g, b) - min(r, g, b) <= 16


def remove_edge_checkerboard(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    width, height = im.size
    visited = bytearray(width * height)
    q: deque[tuple[int, int]] = deque()

    def push_if_bg(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx]:
            return
        visited[idx] = 1
        if is_checker_pixel(px[x, y]):
            q.append((x, y))

    for x in range(width):
        push_if_bg(x, 0)
        push_if_bg(x, height - 1)
    for y in range(height):
        push_if_bg(0, y)
        push_if_bg(width - 1, y)

    while q:
        x, y = q.popleft()
        r, g, b, _a = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            idx = ny * width + nx
            if visited[idx]:
                continue
            visited[idx] = 1
            if is_checker_pixel(px[nx, ny]):
                q.append((nx, ny))

    return im


def trim_alpha(im: Image.Image, pad: int = 18) -> Image.Image:
    bbox = im.getchannel("A").getbbox()
    if bbox == None:
        return im
    x0 = max(bbox[0] - pad, 0)
    y0 = max(bbox[1] - pad, 0)
    x1 = min(bbox[2] + pad, im.width)
    y1 = min(bbox[3] + pad, im.height)
    return im.crop((x0, y0, x1, y1))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    for index, (src, name) in enumerate(SOURCES, 1):
        if not src.exists():
            raise FileNotFoundError(src)
        im = trim_alpha(remove_edge_checkerboard(Image.open(src)))
        out_path = OUT / name
        im.save(out_path)
        print(f"{index:02d} -> {out_path} {im.size}")


if __name__ == "__main__":
    main()
