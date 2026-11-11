extends Node2D
## Bir seviyeyi kurar ve oyun akışını yönetir: toplama, kapı, kazanma/kaybetme, duraklatma.

enum State { PLAYING, PAUSED, WON, LOST }

const PLAYER_SCENE := preload("res://scenes/game/player.tscn")
const SHADOW_SCENE := preload("res://scenes/game/shadow.tscn")
const PICKUP_SCENE := preload("res://scenes/game/pickup.tscn")
const EXIT_SCENE := preload("res://scenes/game/exit_door.tscn")
const LAMP_SCENE := preload("res://scenes/game/lamp.tscn")

const ORB_ENERGY := 30.0
const DARKNESS := Color(0.045, 0.04, 0.075)
const CAMERA_ZOOM := 1.6

var state := State.PLAYING
var level: Dictionary
var level_map: LevelMap
var player: Player
var exit_door: ExitDoor
var camera: Camera2D
var hud: Hud
var overlay: Overlay
var sparks_total := 0
var sparks_collected := 0
var elapsed := 0.0

var _world: Node2D
var _shake := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	level = GameManager.get_level(GameManager.current_level)
	_build_world()
	_build_ui()
	Sfx.play_music()
	hud.toast(String(level.get("hint", "")), Ui.TEXT, 4.0)


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)

	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	_world.add_child(dark)

	level_map = LevelMap.new()
	level_map.name = "LevelMap"
	_world.add_child(level_map)
	var spawns: Dictionary = level_map.build(level["map"])

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	_world.add_child(entities)

	for pos: Vector2 in spawns["lamps"]:
		var lamp: Lamp = LAMP_SCENE.instantiate()
		lamp.position = pos
		entities.add_child(lamp)

	exit_door = EXIT_SCENE.instantiate()
	exit_door.position = spawns["exit"]
	exit_door.reached.connect(_on_exit_reached)
	entities.add_child(exit_door)

	for pos: Vector2 in spawns["orbs"]:
		_spawn_pickup(entities, pos, Pickup.Kind.ORB)
	for pos: Vector2 in spawns["sparks"]:
		_spawn_pickup(entities, pos, Pickup.Kind.SPARK)
	sparks_total = spawns["sparks"].size()

	player = PLAYER_SCENE.instantiate()
	player.position = spawns["player"]
	player.drain_rate = float(level.get("drain", 2.0))
	player.energy_changed.connect(_on_energy_changed)
	player.hit.connect(_on_player_hit)
	player.died.connect(_on_player_died)
	entities.add_child(player)

	for pos: Vector2 in spawns["shadows"]:
		var s: ShadowEnemy = SHADOW_SCENE.instantiate()
		s.position = pos
		s.level_map = level_map
		s.player = player
		entities.add_child(s)

	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	var size := level_map.world_size()
	var margin := 64
	camera.limit_left = -margin
	camera.limit_top = -margin
	camera.limit_right = int(size.x) + margin
	camera.limit_bottom = int(size.y) + margin
	player.add_child(camera)

	if sparks_total == 0:
		exit_door.set_open(true)


func _spawn_pickup(parent: Node, pos: Vector2, kind: Pickup.Kind) -> void:
	var p: Pickup = PICKUP_SCENE.instantiate()
	p.kind = kind
	p.position = pos
	p.collected.connect(_on_pickup_collected)
	parent.add_child(p)


func _build_ui() -> void:
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(GameManager.current_level + 1, String(level["name"]), sparks_total)
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE

	overlay = Overlay.new()
	overlay.name = "Overlay"
	add_child(overlay)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		elapsed += delta
		hud.update_time(elapsed)
		hud.update_flash(player.flash_ready_ratio())
	if _shake > 0.0 and state != State.PAUSED:
		_shake = maxf(_shake - delta * 30.0, 0.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		camera.offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			_pause()
		elif state == State.PAUSED:
			_resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and state != State.PAUSED:
		GameManager.restart_level()


# --- Durumlar --------------------------------------------------------------

func _pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	overlay.show_menu("Duraklatıldı", [], [
		["Devam Et", _resume],
		["Yeniden Başla", GameManager.restart_level],
		["Ana Menü", GameManager.goto_menu],
	])


func _resume() -> void:
	overlay.hide_menu()
	get_tree().paused = false
	state = State.PLAYING


func _calc_score() -> int:
	var par := float(level.get("par", 90.0))
	var time_bonus := maxi(0, int((par - elapsed) * 10.0))
	return sparks_total * 100 + int(player.energy) * 5 + time_bonus


# --- Olaylar ---------------------------------------------------------------

func _on_energy_changed(value: float, max_value: float) -> void:
	hud.update_energy(value, max_value)


func _on_pickup_collected(p: Pickup) -> void:
	if p.kind == Pickup.Kind.ORB:
		player.add_energy(ORB_ENERGY)
		Sfx.play("orb", 0.08)
		return
	sparks_collected += 1
	hud.update_sparks(sparks_collected, sparks_total)
	Sfx.play("spark")
	if sparks_collected >= sparks_total:
		exit_door.set_open(true)
		Sfx.play("door")
		hud.toast("Kapı açıldı! Çıkışa ulaş.", Ui.GOOD, 3.0)
	else:
		hud.toast("Kıvılcım %d / %d" % [sparks_collected, sparks_total], Color(0.6, 0.95, 1.0), 1.2)


func _on_player_hit() -> void:
	_shake = 9.0
	hud.damage_flash()


func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.LOST
	Sfx.play("lose")
	await get_tree().create_timer(1.4).timeout
	overlay.show_menu("Karanlık seni yuttu", [
		"Fenerin söndü...",
		"Süre: %s   •   Kıvılcım: %d / %d" % [Ui.format_time(elapsed), sparks_collected, sparks_total],
	], [
		["Tekrar Dene", GameManager.restart_level],
		["Ana Menü", GameManager.goto_menu],
	], Ui.DANGER)


func _on_exit_reached() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	player.freeze()
	Sfx.play("win")
	var score := _calc_score()
	var record := GameManager.complete_level(score)
	var lines := [
		"Süre: %s" % Ui.format_time(elapsed),
		"Kalan ışık: %%%d" % int(player.energy),
		"Skor: %d%s" % [score, "   ★ Yeni rekor!" if record else ""],
		"En iyi: %d" % GameManager.get_best(GameManager.current_level),
	]
	await get_tree().create_timer(0.6).timeout
	if GameManager.is_last_level():
		lines.append("")
		lines.append("Tüm fenerleri yaktın! Toplam en iyi skor: %d" % GameManager.total_best())
		overlay.show_menu("Karanlık dağıldı!", lines, [
			["Ana Menü", GameManager.goto_menu],
			["Tekrar Oyna", GameManager.restart_level],
		], Ui.GOOD)
	else:
		overlay.show_menu("Seviye Tamamlandı", lines, [
			["Sonraki Seviye", GameManager.next_level],
			["Tekrar Oyna", GameManager.restart_level],
			["Ana Menü", GameManager.goto_menu],
		], Ui.GOOD)
