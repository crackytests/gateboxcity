from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

SOURCES = [
    {
        "name": "goon_material",
        "source": Path(r"C:\Users\jeremy\Downloads\edited-photo.png"),
        "threshold": 24,
    },
    {
        "name": "rain_mutant",
        "source": Path(r"C:\Users\jeremy\Downloads\edited-photo (2).png"),
        "threshold": 24,
    },
    {
        "name": "splice",
        "source": Path(r"C:\Users\jeremy\Downloads\edited-photo (1).png"),
        "threshold": 24,
    },
]

SHEET_ORDER = [
    "front",
    "front_left",
    "left",
    "back_left",
    "back",
    "back_right",
    "right",
    "front_right",
]

FRAME_ORDER = [
    "back",
    "back_left",
    "left",
    "front_left",
    "front",
    "front_right",
    "right",
    "back_right",
]


def is_background_pixel(pixel, threshold):
    r, g, b, a = pixel
    return a < 8 or (r <= threshold and g <= threshold and b <= threshold)


def flood_background(image, threshold):
    width, height = image.size
    pixels = image.load()
    visited = [[False] * width for _ in range(height)]
    queue = deque()

    def enqueue(x, y):
        if visited[y][x]:
            return
        if not is_background_pixel(pixels[x, y], threshold):
            return
        visited[y][x] = True
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                enqueue(nx, ny)

    return visited


def component_bounds(mask, min_area=5000):
    height = len(mask)
    width = len(mask[0])
    seen = [[False] * width for _ in range(height)]
    bounds = []

    for y in range(height):
        for x in range(width):
            if seen[y][x] or not mask[y][x]:
                continue
            queue = deque([(x, y)])
            seen[y][x] = True
            min_x = max_x = x
            min_y = max_y = y
            area = 0
            while queue:
                cx, cy = queue.popleft()
                area += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx] and mask[ny][nx]:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            if area >= min_area:
                bounds.append((min_x, min_y, max_x + 1, max_y + 1, area))

    return sorted(bounds, key=lambda item: item[0])


def merge_overlapping_bounds(bounds, gap=4, min_overlap_fraction=0.3):
    if not bounds:
        return []
    merged = []
    current = list(bounds[0])
    for item in bounds[1:]:
        overlap = min(current[2], item[2]) - max(current[0], item[0])
        min_width = max(1, min(current[2] - current[0], item[2] - item[0]))
        if overlap > 0:
            should_merge = float(overlap) / float(min_width) >= min_overlap_fraction
        else:
            should_merge = item[0] <= current[2] + gap
        if should_merge:
            current[0] = min(current[0], item[0])
            current[1] = min(current[1], item[1])
            current[2] = max(current[2], item[2])
            current[3] = max(current[3], item[3])
            current[4] += item[4]
        else:
            merged.append(tuple(current))
            current = list(item)
    merged.append(tuple(current))
    return merged


def make_cutout(image, bg_mask):
    cutout = image.copy()
    pixels = cutout.load()
    width, height = cutout.size
    for y in range(height):
        for x in range(width):
            if bg_mask[y][x]:
                r, g, b, _a = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)
    return cutout


def export_sheet(config):
    source = config["source"]
    name = config["name"]
    out_dir = ROOT / "assets" / "sprites" / name
    out_dir.mkdir(parents=True, exist_ok=True)

    image = Image.open(source).convert("RGBA")
    bg_mask = flood_background(image, config["threshold"])
    foreground = [
        [not bg_mask[y][x] and image.getpixel((x, y))[3] >= 8 for x in range(image.size[0])]
        for y in range(image.size[1])
    ]
    bounds = merge_overlapping_bounds(component_bounds(foreground))
    if len(bounds) != 8:
        raise RuntimeError(f"{name}: expected 8 sprite components, found {len(bounds)}: {bounds}")

    cutout = make_cutout(image, bg_mask)
    cropped_by_sheet_direction = {}
    pad = 12
    for direction, (left, top, right, bottom, _area) in zip(SHEET_ORDER, bounds):
        left = max(0, left - pad)
        top = max(0, top - pad)
        right = min(image.size[0], right + pad)
        bottom = min(image.size[1], bottom + pad)
        cropped_by_sheet_direction[direction] = cutout.crop((left, top, right, bottom))

    max_w = max(sprite.size[0] for sprite in cropped_by_sheet_direction.values()) + 24
    max_h = max(sprite.size[1] for sprite in cropped_by_sheet_direction.values()) + 24
    for direction in FRAME_ORDER:
        sprite = cropped_by_sheet_direction[direction]
        frame = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
        x = (max_w - sprite.size[0]) // 2
        y = max_h - sprite.size[1] - 12
        frame.alpha_composite(sprite, (x, y))
        frame.save(out_dir / f"{name}_{direction}.png")

    print(f"{name}: exported 8 frames to {out_dir}")


def main():
    for config in SOURCES:
        export_sheet(config)


if __name__ == "__main__":
    main()
