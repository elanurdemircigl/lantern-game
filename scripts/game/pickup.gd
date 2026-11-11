class_name Pickup
extends Area2D
## Toplanabilir nesne: ışık küresi (fener doldurur) veya kıvılcım (kapıyı açar).

signal collected(pickup: Pickup)

enum Kind { ORB, SPARK }

@export var kind := Kind.ORB

var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_t = randf() * TAU
	material = LightTex.unshaded_material()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	var p := body as Player
	if p == null or not p.alive:
		return
	_taken = true
	collected.emit(self)
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var bob := Vector2(0, sin(_t * 3.0) * 2.5)
	if kind == Kind.ORB:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(bob, 12.0, Color(1.0, 0.8, 0.4, 0.08 + 0.06 * pulse))
		draw_circle(bob, 8.0, Color(1.0, 0.8, 0.4, 0.18))
		draw_circle(bob, 5.0, Color(1.0, 0.88, 0.55, 0.9))
		draw_circle(bob + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 0.9))
	else:
		var rot := _t * 1.5
		var pts := PackedVector2Array()
		for i in 8:
			var r := 11.0 if i % 2 == 0 else 4.0
			var a := rot + TAU * i / 8.0
			pts.append(bob + Vector2(cos(a), sin(a)) * r)
		draw_circle(bob, 15.0, Color(0.5, 0.9, 1.0, 0.08 + 0.05 * sin(_t * 5.0)))
		draw_colored_polygon(pts, Color(0.6, 0.95, 1.0))
		draw_circle(bob, 3.0, Color(1, 1, 1))
