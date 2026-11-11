class_name Player
extends CharacterBody2D
## Fenerini taşıyan küçük gezgin. Işık (enerji) zamanla azalır; sıfırlanırsa oyun biter.

signal energy_changed(value: float, max_value: float)
signal hit
signal died

const SPEED := 165.0
const MAX_ENERGY := 100.0
const FLASH_COST := 15.0
const FLASH_COOLDOWN := 1.2
const FLASH_RADIUS := 200.0
const FLASH_STUN := 2.8
const HIT_DAMAGE := 25.0
const LAMP_REGEN := 10.0
const MIN_LIGHT_SCALE := 0.75
const MAX_LIGHT_SCALE := 2.5

var energy := MAX_ENERGY
var drain_rate := 2.0
var alive := true
var in_safe_zone := false
var controllable := true

var _invuln := 0.0
var _flash_timer := 0.0
var _knockback := Vector2.ZERO
var _facing := Vector2.RIGHT
var _walk := 0.0
var _t := 0.0
var _light: PointLight2D
var _flash_light: PointLight2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("player")

	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	_light = LightTex.make_light(Color(1.0, 0.8, 0.55), MAX_LIGHT_SCALE, 1.15)
	add_child(_light)
	_flash_light = LightTex.make_light(Color(0.85, 0.9, 1.0), 3.4, 0.0)
	add_child(_flash_light)


func _physics_process(delta: float) -> void:
	_t += delta
	_invuln = maxf(_invuln - delta, 0.0)
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	queue_redraw()
	if not alive:
		return

	var dir := Vector2.ZERO
	if controllable:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_facing = dir.normalized()
		_walk += delta * 14.0
	velocity = dir * SPEED + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()

	in_safe_zone = _check_safe_zone()
	if controllable:
		if in_safe_zone:
			add_energy(LAMP_REGEN * delta)
		else:
			set_energy(energy - drain_rate * delta)
		if Input.is_action_just_pressed("flash"):
			try_flash()
	_update_light()


# --- Enerji ----------------------------------------------------------------

func set_energy(value: float) -> void:
	if not alive:
		return
	energy = clampf(value, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)
	if energy <= 0.0:
		_die()


func add_energy(amount: float) -> void:
	set_energy(energy + amount)


func flash_ready_ratio() -> float:
	return 1.0 - _flash_timer / FLASH_COOLDOWN


func try_flash() -> void:
	if _flash_timer > 0.0:
		return
	if energy <= FLASH_COST:
		Sfx.play("deny")
		return
	_flash_timer = FLASH_COOLDOWN
	set_energy(energy - FLASH_COST)
	Sfx.play("flash", 0.05)
	_flash_light.energy = 2.2
	var tw := create_tween()
	tw.tween_property(_flash_light, "energy", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	for node in get_tree().get_nodes_in_group("shadows"):
		var s := node as ShadowEnemy
		if s and s.global_position.distance_to(global_position) <= FLASH_RADIUS:
			s.stun(global_position, FLASH_STUN)


func take_hit(from: Vector2) -> void:
	if not alive or _invuln > 0.0:
		return
	_invuln = 1.2
	_knockback = (global_position - from).normalized() * 420.0
	Sfx.play("hurt", 0.05)
	hit.emit()
	set_energy(energy - HIT_DAMAGE)


func is_invulnerable() -> bool:
	return _invuln > 0.0


## Seviye bitince hareketi durdurur.
func freeze() -> void:
	controllable = false
	velocity = Vector2.ZERO


func _die() -> void:
	alive = false
	died.emit()
	var tw := create_tween().set_parallel()
	tw.tween_property(_light, "texture_scale", 0.05, 1.0)
	tw.tween_property(_light, "energy", 0.0, 1.0)


# --- Yardımcılar -----------------------------------------------------------

func _check_safe_zone() -> bool:
	for node in get_tree().get_nodes_in_group("lamps"):
		var lamp := node as Lamp
		if lamp and lamp.covers(global_position):
			return true
	return false


func _update_light() -> void:
	var ratio := energy / MAX_ENERGY
	var flicker := sin(_t * 9.0) * 0.03 + sin(_t * 23.0) * 0.02
	if ratio < 0.25:
		flicker += sin(_t * 37.0) * 0.1 * (1.0 - ratio / 0.25)
	_light.texture_scale = maxf(lerpf(MIN_LIGHT_SCALE, MAX_LIGHT_SCALE, ratio) + flicker, 0.05)
	_light.energy = lerpf(0.8, 1.2, ratio)


func _draw() -> void:
	if _invuln > 0.0 and int(_invuln * 14.0) % 2 == 0:
		return
	var bob := sin(_walk) * 1.5
	# Yer gölgesi
	draw_set_transform(Vector2(0, 9), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Pelerin ve yüz
	draw_circle(Vector2(0, bob), 10.0, Color(0.28, 0.42, 0.62))
	draw_circle(Vector2(0, -5 + bob), 6.0, Color(0.93, 0.80, 0.66))
	draw_arc(Vector2(0, -5 + bob), 7.0, PI, TAU, 12, Color(0.20, 0.30, 0.48), 3.0)
	# Gözler bakış yönüne kayar
	var eye_off := _facing * 1.5
	draw_circle(Vector2(-2, -5 + bob) + eye_off, 1.1, Color(0.15, 0.1, 0.1))
	draw_circle(Vector2(2, -5 + bob) + eye_off, 1.1, Color(0.15, 0.1, 0.1))
	# Fener
	var lp := _facing * 12.0 + Vector2(0, 2 + bob)
	draw_line(Vector2(0, bob), lp, Color(0.35, 0.28, 0.2), 2.0)
	draw_rect(Rect2(lp - Vector2(4, 4), Vector2(8, 9)), Color(0.35, 0.28, 0.2))
	var flame := Color(1.0, 0.9, 0.6).lerp(Color(1.0, 0.45, 0.2), 1.0 - energy / MAX_ENERGY)
	draw_circle(lp + Vector2(0, 0.5), 3.0, flame)
