extends Node

const AUDIO_DIR := "res://assets/audio/"
const DEFAULT_SFX_VOLUME_DB := -7.0
const DEFAULT_MUSIC_VOLUME_DB := -15.0
const DEFAULT_AMBIENCE_VOLUME_DB := -18.0

const SFX := {
	"breach_gate_use": "breach_gate_use.ogg",
	"dialogue_next": "dialogue_next.ogg",
	"face_failsafe_boot": "face_failsafe_boot.ogg",
	"generator_restored": "generator_restored.ogg",
	"goon_cannon_charge": "goon_cannon_charge.ogg",
	"goon_cannon_fire": "goon_cannon_fire.ogg",
	"lan_restore": "lan_restore.ogg",
	"load_game": "load_game.ogg",
	"melee_scrap_hit": "melee_scrap_hit.ogg",
	"menu_close": "menu_close.ogg",
	"menu_open": "menu_open.ogg",
	"quest_update": "quest_update.ogg",
	"save_game": "save_game.ogg",
	"scrap_pistol_dry_fire": "scrap_pistol_dry_fire.ogg",
	"scrap_pistol_fire": "scrap_pistol_fire_01.ogg",
	"scrap_pistol_reload": "scrap_pistol_reload.ogg",
	"security_node_charge": "security_node_charge.ogg",
	"security_node_core_destroyed": "security_node_core_destroyed.ogg",
	"security_node_fire": "security_node_fire.ogg",
	"shelter_enter": "shelter_enter.ogg",
	"splice_aggro": "splice_aggro.ogg",
	"splice_death": "splice_death.ogg",
	"splice_drag_frame_detonate": "splice_drag_frame_detonate.ogg",
	"splice_graft_shell_break": "splice_graft_shell_break.ogg",
	"splice_lunge_charge": "splice_lunge_charge.ogg",
	"splice_lunge_hit": "splice_lunge_hit.ogg",
	"splice_wire_skull_break": "splice_wire_skull_break.ogg",
	"system_x_terminal_on": "system_x_terminal_on.ogg",
	"target_lock_begin": "target_lock_begin.ogg",
	"target_lock_build": "target_lock_build.ogg",
	"target_lock_ready": "target_lock_ready.ogg",
	"target_miss_static": "target_miss_static.ogg",
	"toxic_rain_damage_tick": "toxic_rain_damage_tick.ogg",
}

const LOOPS := {
	"breach_gate_idle": "breach_gate_idle_loop.ogg",
	"cooters_bar": "cooters_bar_loop.ogg",
	"comfort_annexe": "Comfort Annexe.ogg",
	"dead_food_court": "dead_food_court_loop.ogg",
	"faded_atrium_music": "Faded Atrium Theme.ogg",
	"faded_atrium_ambience": "faded_atrium_ambience_loop.ogg",
	"generator_sag": "generator_sag_loop.ogg",
	"pipe_tunnels": "pipe_tunnels_ambience_loop.ogg",
	"rocker_fellar": "Rocker Fellar Boss.ogg",
	"splice_combat": "Splice Combat.ogg",
	"sub_basement": "Sub-Sub-Basement Exploration.ogg",
	"suitors_lounge": "suitors_lounge_loop.ogg",
	"toxic_rain": "toxic_rain_loop.ogg",
	"toxic_rain_music": "Toxic Rain Event.ogg",
	"wan_moa_torai": "wan_moa_torai_office_loop.ogg",
	"water_cistern": "water_cistern_ambience_loop.ogg",
}

const SCENE_LOOPS := {
	"res://scenes/levels/MallHub.tscn": {"music": "faded_atrium_music", "ambience": "faded_atrium_ambience"},
	"res://scenes/levels/SubSubBasementDistrict.tscn": {"music": "sub_basement"},
	"res://scenes/levels/Test_SubSubBasement.tscn": {"music": "sub_basement"},
	"res://scenes/levels/PipeUtilityTunnels.tscn": {"ambience": "pipe_tunnels"},
	"res://scenes/levels/WaterReclamationCistern.tscn": {"ambience": "water_cistern"},
	"res://scenes/levels/DeadFoodCourtBloom.tscn": {"ambience": "dead_food_court"},
	"res://scenes/levels/CollapsedServiceAtrium.tscn": {"ambience": "faded_atrium_ambience"},
	"res://scenes/levels/CootersInterior.tscn": {"music": "cooters_bar", "ambience": "cooters_bar"},
	"res://scenes/levels/SuitorsInterior.tscn": {"music": "suitors_lounge", "ambience": "suitors_lounge"},
	"res://scenes/levels/ComfortAnnexe_Reception.tscn": {"music": "comfort_annexe", "ambience": "comfort_annexe"},
	"res://scenes/levels/ComfortAnnexe_WardFloor.tscn": {"music": "comfort_annexe", "ambience": "comfort_annexe"},
	"res://scenes/levels/ComfortAnnexe_Sublevel.tscn": {"music": "comfort_annexe", "ambience": "comfort_annexe"},
	"res://scenes/levels/RockerFellarKeep.tscn": {"music": "rocker_fellar"},
}

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _generator_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _current_scene := ""
var _current_music := ""
var _current_ambience := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = _make_player(DEFAULT_MUSIC_VOLUME_DB)
	_ambience_player = _make_player(DEFAULT_AMBIENCE_VOLUME_DB)
	_rain_player = _make_player(DEFAULT_AMBIENCE_VOLUME_DB - 2.0)
	_generator_player = _make_player(DEFAULT_AMBIENCE_VOLUME_DB - 1.0)
	for _i in 14:
		_sfx_pool.append(_make_player(DEFAULT_SFX_VOLUME_DB))
	_apply_scene_audio()


func _process(_delta: float) -> void:
	var scene_path := _scene_path()
	if scene_path != _current_scene:
		_apply_scene_audio()


func play_sfx(id: String, volume_offset_db := 0.0, pitch_scale := 1.0) -> void:
	var stream := _stream_for(id, SFX)
	if stream == null:
		return
	var player := _next_sfx_player()
	player.stream = stream
	player.volume_db = DEFAULT_SFX_VOLUME_DB + volume_offset_db
	player.pitch_scale = pitch_scale
	player.play()


func play_music(id: String) -> void:
	if id == _current_music and _music_player.playing:
		return
	_current_music = id
	_play_loop(_music_player, id, DEFAULT_MUSIC_VOLUME_DB)


func play_ambience(id: String) -> void:
	if id == _current_ambience and _ambience_player.playing:
		return
	_current_ambience = id
	_play_loop(_ambience_player, id, DEFAULT_AMBIENCE_VOLUME_DB)


func set_rain_active(active: bool) -> void:
	_set_layer_loop(_rain_player, "toxic_rain", active, DEFAULT_AMBIENCE_VOLUME_DB - 2.0)


func set_generator_sag_active(active: bool) -> void:
	_set_layer_loop(_generator_player, "generator_sag", active, DEFAULT_AMBIENCE_VOLUME_DB - 1.0)


func play_weapon_log(message: String) -> void:
	var msg := message.to_lower()
	if msg.begins_with("empty") or msg.contains("no reserve"):
		play_sfx("scrap_pistol_dry_fire")
	elif msg.begins_with("reloaded"):
		play_sfx("scrap_pistol_reload")
	elif msg.begins_with("missed") or msg.begins_with("untargeted"):
		play_sfx("target_miss_static", -2.0)


func play_body_part_break(part_name: String) -> void:
	match part_name:
		"Graft Shell":
			play_sfx("splice_graft_shell_break", 1.0)
		"Wire Skull":
			play_sfx("splice_wire_skull_break", 0.0)
		"Drag Frame":
			play_sfx("splice_drag_frame_detonate", 1.5)
		"Core":
			play_sfx("security_node_core_destroyed", 0.0)
		_:
			play_sfx("melee_scrap_hit", -4.0)


func play_enemy_attack(message: String) -> void:
	var msg := message.to_lower()
	if msg.contains("charging"):
		if msg.contains("graft") or msg.contains("splice"):
			play_sfx("splice_lunge_charge")
		elif msg.contains("right arm") or msg.contains("cannon"):
			play_sfx("goon_cannon_charge")
		else:
			play_sfx("security_node_charge", -2.0)
	elif msg.contains("pulse hit"):
		play_sfx("security_node_fire")
	elif msg.contains("cannon hit"):
		play_sfx("goon_cannon_fire")
	elif msg.contains("splice") and (msg.contains("drove") or msg.contains("impact")):
		play_sfx("splice_lunge_hit", 0.5)


func play_ui_message(message: String) -> void:
	var msg := message.to_lower()
	if msg.contains("saved"):
		play_sfx("save_game", -1.0)
	elif msg.contains("loaded"):
		play_sfx("load_game", -1.0)
	elif msg.contains("quest") or msg.contains("complete") or msg.contains("found"):
		play_sfx("quest_update", -2.0)


func _apply_scene_audio() -> void:
	var previous_scene := _current_scene
	_current_scene = _scene_path()
	if not previous_scene.is_empty() and previous_scene != _current_scene:
		play_sfx("breach_gate_use", -3.0)
	var cfg: Dictionary = SCENE_LOOPS.get(_current_scene, {})
	if cfg.has("music"):
		play_music(str(cfg["music"]))
	else:
		_music_player.stop()
		_current_music = ""
	if cfg.has("ambience"):
		play_ambience(str(cfg["ambience"]))
	else:
		_ambience_player.stop()
		_current_ambience = ""


func _play_loop(player: AudioStreamPlayer, id: String, volume_db: float) -> void:
	var stream := _stream_for(id, LOOPS)
	if stream == null:
		player.stop()
		return
	_make_looping(stream)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	player.play()


func _set_layer_loop(player: AudioStreamPlayer, id: String, active: bool, volume_db: float) -> void:
	if not active:
		player.stop()
		return
	if player.playing:
		return
	_play_loop(player, id, volume_db)


func _stream_for(id: String, source: Dictionary) -> AudioStream:
	if not source.has(id):
		return null
	var path := AUDIO_DIR + str(source[id])
	if _cache.has(path):
		return _cache[path] as AudioStream
	var stream: AudioStream
	if path.get_extension().to_lower() == "ogg":
		stream = AudioStreamOggVorbis.load_from_file(path)
	else:
		stream = ResourceLoader.load(path) as AudioStream
	if stream == null:
		push_warning("Audio missing: " + path)
		return null
	_cache[path] = stream
	return stream


func _make_looping(stream: AudioStream) -> void:
	if stream == null:
		return
	for prop in ["loop", "loop_mode"]:
		var list := stream.get_property_list()
		for p: Dictionary in list:
			if str(p.get("name", "")) == prop:
				if prop == "loop":
					stream.set(prop, true)
				else:
					stream.set(prop, 1)
				return


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	add_child(player)
	return player


func _next_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0]


func _scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""
