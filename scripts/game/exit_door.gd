class_name ExitDoor
extends Area2D
## Çıkış kapısı. Tüm kıvılcımlar toplanınca açılır; oyuncu girince seviye biter.

signal reached

var is_open := false

var _t := 0.0
var _done := false
var _light: PointLight2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	material = LightTex.unshaded_material()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_light = LightTex.make_light(Color(0.4, 1.0, 0.8), 1.3, 0.0)
	add_child(_light)


func set_open(value: bool) -> void:
	is_open = value
	create_tween().tween_property(_light, "energy", 1.0 if value else 0.0, 0.8)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not is_open or _done:
		return
	for body in get_overlapping_bodies():
		var p := body as Player
		if p and p.alive:
			_done = true
			reached.emit()
			return


func _draw() -> void:
	var frame := Rect2(-14, -16, 28, 32)
	if is_open:
		draw_rect(frame, Color(0.15, 0.35, 0.3))
		draw_rect(frame.grow(-3), Color(0.25, 0.9, 0.7, 0.35 + 0.15 * sin(_t * 4.0)))
		for i in 3:
			var r := fmod(_t * 10.0 + i * 4.0, 12.0)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0.7, 1.0, 0.9, 1.0 - r / 12.0), 1.5)
	else:
		# Kapalıyken soluk görünür ki oyuncu hedefi bilsin.
		draw_rect(frame, Color(0.2, 0.16, 0.26, 0.6))
		draw_rect(frame.grow(-3), Color(0.08, 0.06, 0.1, 0.8))
		draw_rect(Rect2(-4, -2, 8, 7), Color(0.6, 0.5, 0.75, 0.7))
		draw_arc(Vector2(0, -2), 3.0, PI, TAU, 8, Color(0.6, 0.5, 0.75, 0.7), 1.5)
