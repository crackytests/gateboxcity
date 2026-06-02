extends CanvasLayer

const HAUNTED_CRT_SHADER := preload("res://shaders/haunted_crt.gdshader")

@export var effect_enabled := true:
	set(value):
		effect_enabled = value
		if _screen_rect != null:
			_screen_rect.visible = effect_enabled

@export_range(0.0, 1.0, 0.01) var effect_strength := 1.0:
	set(value):
		effect_strength = value
		_set_shader_param("effect_strength", effect_strength)

var _screen_rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func set_shader_param(param_name: StringName, value: Variant) -> void:
	_set_shader_param(param_name, value)


func _build_overlay() -> void:
	_material = ShaderMaterial.new()
	_material.shader = HAUNTED_CRT_SHADER
	_material.set_shader_parameter("effect_strength", effect_strength)

	_screen_rect = ColorRect.new()
	_screen_rect.name = "HauntedCRTScreen"
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_rect.color = Color.WHITE
	_screen_rect.material = _material
	_screen_rect.visible = effect_enabled
	add_child(_screen_rect)


func _set_shader_param(param_name: StringName, value: Variant) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(param_name, value)
