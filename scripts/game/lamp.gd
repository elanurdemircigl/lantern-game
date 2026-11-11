class_name Lamp
extends Node2D
## Fener direği: çevresi güvenli bölgedir. Gölgeler giremez, oyuncunun ışığı dolar.

const SAFE_RADIUS := 84.0

var _t := 0.0
var _light: PointLight2D


func _ready() -> void:
	add_to_group("lamps")
	_t = randf() * 10.0
	_light = LightTex.make_light(Color(1.0, 0.72, 0.42), 1.5, 1.0)
	_light.position = Vector2(0, -10)
	add_child(_light)


func covers(pos: Vector2) -> bool:
	return global_position.distance_to(pos) < SAFE_RADIUS


func _process(delta: float) -> void:
	_t += delta
	_light.energy = 1.0 + sin(_t * 7.0) * 0.05 + sin(_t * 13.0) * 0.03
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, SAFE_RADIUS, Color(1.0, 0.75, 0.4, 0.05))
	draw_arc(Vector2.ZERO, SAFE_RADIUS, 0.0, TAU, 64, Color(1.0, 0.8, 0.5, 0.22), 1.5)
	# Direk
	draw_rect(Rect2(-5, 6, 10, 4), Color(0.18, 0.16, 0.18))
	draw_rect(Rect2(-2, -6, 4, 14), Color(0.22, 0.19, 0.2))
	# Fener kutusu ve alev
	draw_rect(Rect2(-6, -18, 12, 12), Color(0.32, 0.26, 0.2))
	draw_rect(Rect2(-4, -16, 8, 8), Color(1.0, 0.8, 0.45))
	draw_circle(Vector2(0, -12), 2.5 + sin(_t * 11.0) * 0.4, Color(1, 0.97, 0.85))
