extends Node
## Oyun geneli durum: seviye ilerlemesi, en iyi skorlar, ayarlar ve kayıt dosyası.

const SAVE_PATH := "user://save.cfg"
const LevelData := preload("res://scripts/levels.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

var current_level := 0
var unlocked := 1
var best_scores: Dictionary = {}
var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.8
var fullscreen := false
## Testler kayıt dosyasına dokunmasın diye kapatılabilir.
var persist := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_game()
	apply_settings()


# --- Seviyeler -------------------------------------------------------------

func level_count() -> int:
	return LevelData.LEVELS.size()


func get_level(index: int) -> Dictionary:
	return LevelData.LEVELS[clampi(index, 0, level_count() - 1)]


func is_last_level() -> bool:
	return current_level >= level_count() - 1


func start_level(index: int) -> void:
	current_level = clampi(index, 0, level_count() - 1)
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func restart_level() -> void:
	start_level(current_level)


func next_level() -> void:
	start_level(current_level + 1)


func goto_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Skorlar ---------------------------------------------------------------

func get_best(index: int) -> int:
	return int(best_scores.get(str(index), 0))


func total_best() -> int:
	var total := 0
	for i in level_count():
		total += get_best(i)
	return total


## Seviye bitince çağrılır. Yeni rekor ise true döner.
func complete_level(score: int) -> bool:
	var is_record := score > get_best(current_level)
	if is_record:
		best_scores[str(current_level)] = score
	unlocked = maxi(unlocked, mini(current_level + 2, level_count()))
	save_game()
	return is_record


# --- Ayarlar ---------------------------------------------------------------

func apply_settings() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# --- Kayıt -----------------------------------------------------------------

func save_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best_scores", best_scores)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, level_count())
	var scores: Variant = cfg.get_value("progress", "best_scores", {})
	if scores is Dictionary:
		best_scores = scores
	master_volume = float(cfg.get_value("settings", "master_volume", master_volume))
	music_volume = float(cfg.get_value("settings", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", sfx_volume))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", fullscreen))


# --- Girdi -----------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_add_action("flash", [KEY_SPACE], [JOY_BUTTON_A])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("restart", [KEY_R], [JOY_BUTTON_Y])
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


func _add_action(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button: JoyButton in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis
	jm.axis_value = value
	InputMap.action_add_event(action, jm)
