class_name ShadowEnemy
extends CharacterBody2D
## Karanlıkta dolaşan gölge. Fenerin parlaklığına çekilir; temas edince ışık çalar.
## Parlama ile sersemletilebilir, fener direklerinin güvenli alanına giremez.

enum State { WANDER, CHASE, STUNNED }

const WANDER_SPEED := 55.0
const CHASE_SPEED := 112.0
const BASE_DETECT := 140.0
const LIGHT_DETECT := 160.0
const LOSE_RANGE := 400.0
const HIT_DISTANCE := 22.0
const REPATH_TIME := 0.35

var level_map: LevelMap
var player: Player
var state := State.WANDER

var _path := PackedVector2Array()
var _path_timer := 0.0
var _stun_timer := 0.0
var _idle_timer := 0.0
var _home := Vector2.ZERO
var _t := 0.0
var _eyes: Node2D
var _look := Vector2.DOWN


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("shadows")
	_home = global_position
	_t = randf() * 10.0

	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	# Gözler karanlıkta da görünür (aydınlatmadan etkilenmez).
	_eyes = Node2D.new()
	_eyes.material = LightTex.unshaded_material()
	_eyes.draw.connect(_draw_eyes)
	add_child(_eyes)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_eyes.queue_redraw()
	if player == null or not is_instance_valid(player) or level_map == null:
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()

	match state:
		State.STUNNED:
			_stun_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			if _stun_timer <= 0.0:
				state = State.WANDER
				_path.clear()
		State.WANDER:
			if _can_see_player(dist):
				state = State.CHASE
				_path.clear()
				Sfx.play("alert", 0.1, -6.0)
			else:
				_wander(delta)
		State.CHASE:
			if not player.alive or player.in_safe_zone or dist > LOSE_RANGE:
				state = State.WANDER
				_path.clear()
			else:
				_chase(delta, to_player, dist)

	_avoid_lamps()
	if velocity.length() > 5.0:
		_look = velocity.normalized()
	move_and_slide()

	if state != State.STUNNED and player.alive and dist < HIT_DISTANCE and not player.in_safe_zone:
		if not player.is_invulnerable():
			player.take_hit(global_position)
		stun(player.global_position, 1.0)


func stun(from: Vector2, duration: float) -> void:
	state = State.STUNNED
	_stun_timer = duration
	_path.clear()
	var away := (global_position - from)
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = away.normalized() * 280.0


# --- Davranışlar -----------------------------------------------------------

func _can_see_player(dist: float) -> bool:
	if not player.alive or player.in_safe_zone:
		return false
	var detect := BASE_DETECT + LIGHT_DETECT * player.energy / Player.MAX_ENERGY
	if dist > detect:
		return false
	return _line_of_sight(player.global_position)


func _line_of_sight(target: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wander(delta: float) -> void:
	if _path.is_empty():
		_idle_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		if _idle_timer <= 0.0:
			var target := level_map.random_floor_near(_home, 6, _in_lamp_zone)
			_path = level_map.find_path(global_position, target)
			_idle_timer = randf_range(0.6, 1.8)
		return
	_follow_path(WANDER_SPEED)


func _chase(delta: float, to_player: Vector2, dist: float) -> void:
	# Doğrudan görüyorsa düz git, görmüyorsa A* ile yol bul.
	if dist < 120.0 and _line_of_sight(player.global_position):
		velocity = to_player.normalized() * CHASE_SPEED
		_path.clear()
		return
	_path_timer -= delta
	if _path_timer <= 0.0 or _path.is_empty():
		_path = level_map.find_path(global_position, player.global_position)
		_path_timer = REPATH_TIME
	_follow_path(CHASE_SPEED)


func _follow_path(speed: float) -> void:
	while _path.size() > 0 and global_position.distance_to(_path[0]) < 6.0:
		_path.remove_at(0)
	if _path.is_empty():
		velocity = Vector2.ZERO
		return
	velocity = global_position.direction_to(_path[0]) * speed


func _in_lamp_zone(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("lamps"):
		var lamp := node as Lamp
		if lamp and lamp.global_position.distance_to(pos) < Lamp.SAFE_RADIUS + 12.0:
			return true
	return false


## Fener direklerine yaklaşınca dışarı itilir.
func _avoid_lamps() -> void:
	for node in get_tree().get_nodes_in_group("lamps"):
		var lamp := node as Lamp
		if lamp == null:
			continue
		var away := global_position - lamp.global_position
		var limit := Lamp.SAFE_RADIUS + 10.0
		if away.length() < limit:
			var push := away.normalized() if away.length() > 0.01 else Vector2.UP
			velocity = push * maxf(velocity.length(), WANDER_SPEED)
			if state == State.CHASE:
				state = State.WANDER
				_path.clear()


# --- Çizim -----------------------------------------------------------------

func _draw() -> void:
	var stunned := state == State.STUNNED
	var col := Color(0.16, 0.07, 0.24) if not stunned else Color(0.38, 0.34, 0.46)
	var pts := PackedVector2Array()
	var count := 14
	for i in count:
		var a := TAU * i / count
		var wobble := sin(_t * 6.0 + i * 1.7) * 1.8
		var r := 13.0 + wobble
		if a > 0.2 and a < PI - 0.2:
			r += sin(_t * 9.0 + i) * 2.5  # Alt kenarda dalgalanan "etek"
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)
	draw_circle(Vector2(0, -2), 8.0, col.lightened(0.08))


func _draw_eyes() -> void:
	var off := _look * 3.0 + Vector2(0, -3)
	var col: Color
	match state:
		State.CHASE:
			col = Color(1.0, 0.3, 0.3)
		State.STUNNED:
			col = Color(0.6, 0.6, 0.7, 0.5)
		_:
			col = Color(0.85, 0.75, 1.0, 0.85)
	var blink := 1.0 if fmod(_t, 3.7) > 0.12 else 0.2
	for side in [-4.0, 4.0]:
		var p := Vector2(side, 0) + off
		_eyes.draw_set_transform(p, 0.0, Vector2(1.0, blink))
		_eyes.draw_circle(Vector2.ZERO, 2.2, col)
	_eyes.draw_set_transform(Vector2.ZERO)
