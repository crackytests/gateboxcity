extends CanvasLayer
# ScreenFX — persistent full-screen post effects that survive scene changes. Currently: a VCR
# "rewind" scramble played on game load. Registered as an autoload (ScreenFX).
#
# Flow: pressing the load action triggers rewind() — an opaque VCR scramble snaps on (masking the
# load that runs the same frame), holds, then fades to reveal the loaded state. The load sound is
# already played by AudioDirector on the "GAME LOADED" message that fires the same frame, so the
# audio and visual line up without extra wiring.
#
# The scramble is fully procedural (animated static / tracking bars / scanlines) so it does not
# depend on capturing the screen texture — it always renders.

const SHADER_CODE := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 c) { return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Cold VHS blue base.
	vec3 col = vec3(0.02, 0.04, 0.06);

	// Rolling tracking bands.
	float band = floor(uv.y * 36.0);
	float bnoise = rand(vec2(band, floor(t * 30.0)));
	col += bnoise * 0.25;

	// Fine static.
	float st = rand(uv + vec2(t * 17.0, t * 9.0));
	col += st * 0.5;

	// Bright rewind tracking bar sweeping upward.
	float bar = smoothstep(0.10, 0.0, abs(fract(uv.y + (-t * 1.6)) - 0.5));
	col += bar * vec3(0.4, 0.9, 1.0) * 0.85;

	// Occasional horizontal tear lines.
	float tear = step(0.97, rand(vec2(floor(t * 20.0), band)));
	col += tear * 0.5;

	// Scanlines.
	col *= 0.82 + 0.18 * step(0.5, fract(uv.y * 180.0));

	COLOR = vec4(col, intensity * 0.92);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false


func _ready() -> void:
	layer = 100   # above the HUD and everything else
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat.shader = sh
	_mat.set_shader_parameter("intensity", 0.0)

	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.color = Color(1, 1, 1, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("load_game") and not _busy and GameState.has_save_file():
		rewind()


# VCR rewind scramble: snap to full scramble immediately (masking the load that runs this same
# frame), hold, then fade to reveal the loaded state.
func rewind() -> void:
	if _busy:
		return
	_busy = true
	_rect.visible = true
	_set_intensity(1.0)           # full scramble next frame — hides the just-loaded state
	var tw := create_tween()
	tw.tween_interval(0.55)       # hold scrambled while the synchronous load settles underneath
	tw.tween_method(_set_intensity, 1.0, 0.0, 0.7)   # fade out to reveal
	await tw.finished
	_rect.visible = false
	_busy = false


func _set_intensity(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("intensity", v)
