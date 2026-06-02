from collections import deque
import hashlib
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "assets" / "sprites" / "weapon" / "spooky_scrap_pistol" / "fire_anim_raw"
OUT_DIR = PROJECT_ROOT / "assets" / "sprites" / "weapon" / "spooky_scrap_pistol" / "fire_anim"
OUT_SIZE = 444
MARGIN = 8


def _is_checker_pixel(pixel: tuple[int, int, int]) -> bool:
	r, g, b = pixel
	return min(r, g, b) >= 215 and max(r, g, b) - min(r, g, b) <= 26


def _is_baked_checker_smoke(pixel: tuple[int, int, int]) -> bool:
	r, g, b = pixel
	return min(r, g, b) >= 145 and max(r, g, b) - min(r, g, b) <= 18


def _remove_edge_checker_background(image: Image.Image) -> Image.Image:
	rgb = image.convert("RGB")
	w, h = rgb.size
	pixels = rgb.load()
	visited: set[tuple[int, int]] = set()
	queue: deque[tuple[int, int]] = deque()

	for x in range(w):
		for y in (0, h - 1):
			if _is_checker_pixel(pixels[x, y]):
				queue.append((x, y))
				visited.add((x, y))
	for y in range(h):
		for x in (0, w - 1):
			if (x, y) not in visited and _is_checker_pixel(pixels[x, y]):
				queue.append((x, y))
				visited.add((x, y))

	while queue:
		x, y = queue.popleft()
		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if nx < 0 or ny < 0 or nx >= w or ny >= h or (nx, ny) in visited:
				continue
			if _is_checker_pixel(pixels[nx, ny]):
				visited.add((nx, ny))
				queue.append((nx, ny))

	rgba = rgb.convert("RGBA")
	alpha = rgba.getchannel("A")
	alpha_pixels = alpha.load()
	for y in range(h):
		for x in range(w):
			if _is_baked_checker_smoke(pixels[x, y]):
				alpha_pixels[x, y] = 0
	for x, y in visited:
		alpha_pixels[x, y] = 0

	# Lightly clean compression halos that touch removed background.
	for x, y in list(visited):
		for nx in range(max(0, x - 1), min(w, x + 2)):
			for ny in range(max(0, y - 1), min(h, y + 2)):
				if (nx, ny) in visited:
					continue
				pr, pg, pb = pixels[nx, ny]
				if min(pr, pg, pb) >= 205 and max(pr, pg, pb) - min(pr, pg, pb) <= 34:
					alpha_pixels[nx, ny] = min(alpha_pixels[nx, ny], 64)

	rgba.putalpha(alpha)
	return rgba


def _alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
	alpha = image.getchannel("A")
	return alpha.getbbox() or (0, 0, image.width, image.height)


def _pad_bbox(
	bbox: tuple[int, int, int, int], width: int, height: int, margin: int
) -> tuple[int, int, int, int]:
	x0, y0, x1, y1 = bbox
	return (
		max(0, x0 - margin),
		max(0, y0 - margin),
		min(width, x1 + margin),
		min(height, y1 + margin),
	)


def _uid_for_resource(resource_path: str) -> str:
	digest = hashlib.sha1(resource_path.encode("utf-8")).hexdigest()
	alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
	value = int(digest[:16], 16)
	chars: list[str] = []
	for _index in range(13):
		value, remainder = divmod(value, len(alphabet))
		chars.append(alphabet[remainder])
	return "uid://" + "".join(chars)


def _write_redot_import(image_path: Path) -> None:
	relative = image_path.relative_to(PROJECT_ROOT).as_posix()
	source_file = "res://" + relative
	source_hash = hashlib.md5(source_file.encode("utf-8")).hexdigest()
	imported_path = f"res://.godot/imported/{image_path.name}-{source_hash}.ctex"
	image_path.with_suffix(image_path.suffix + ".import").write_text(
		f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{_uid_for_resource(source_file)}"
path="{imported_path}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{source_file}"
dest_files=["{imported_path}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
""",
		encoding="utf-8",
	)


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	raw_paths = sorted(RAW_DIR.glob("fire_*.png"))
	if not raw_paths:
		raise SystemExit(f"No extracted frames found in {RAW_DIR}")

	cleaned: list[Image.Image] = []
	union: tuple[int, int, int, int] | None = None
	for path in raw_paths:
		frame = _remove_edge_checker_background(Image.open(path))
		cleaned.append(frame)
		bbox = _alpha_bbox(frame)
		union = bbox if union is None else (
			min(union[0], bbox[0]),
			min(union[1], bbox[1]),
			max(union[2], bbox[2]),
			max(union[3], bbox[3]),
		)

	assert union is not None
	crop_box = _pad_bbox(union, cleaned[0].width, cleaned[0].height, MARGIN)
	crop_w = crop_box[2] - crop_box[0]
	crop_h = crop_box[3] - crop_box[1]
	scale = min(OUT_SIZE / crop_w, OUT_SIZE / crop_h)
	scaled_w = max(1, round(crop_w * scale))
	scaled_h = max(1, round(crop_h * scale))

	for index, frame in enumerate(cleaned):
		cropped = frame.crop(crop_box)
		resized = cropped.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
		canvas = Image.new("RGBA", (OUT_SIZE, OUT_SIZE), (0, 0, 0, 0))
		x = (OUT_SIZE - scaled_w) // 2
		y = OUT_SIZE - scaled_h
		canvas.alpha_composite(resized, (x, y))
		canvas_pixels = canvas.load()
		for py in range(0, min(190, OUT_SIZE)):
			for px in range(0, min(230, OUT_SIZE)):
				pr, pg, pb, pa = canvas_pixels[px, py]
				if pa > 0 and min(pr, pg, pb) >= 80 and max(pr, pg, pb) - min(pr, pg, pb) <= 34:
					canvas_pixels[px, py] = (pr, pg, pb, 0)
		output_path = OUT_DIR / f"spooky_scrap_pistol_fire_anim_{index:02d}.png"
		canvas.save(output_path)
		_write_redot_import(output_path)

	print(f"wrote {len(cleaned)} transparent frames to {OUT_DIR}")
	print(f"source crop {crop_box}, scaled to {scaled_w}x{scaled_h}")


if __name__ == "__main__":
	main()
