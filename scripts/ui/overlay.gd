class_name Overlay
extends CanvasLayer
## Oyun içi menü katmanı (duraklatma, kazanma, kaybetme). Oyun duraklatılmışken de çalışır.

var _root: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## buttons: [["Metin", Callable], ...]
func show_menu(title: String, lines: Array, buttons: Array, title_color := Ui.ACCENT) -> void:
	_clear()
	visible = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = Ui.theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(Ui.label(title, 44, title_color))
	if not lines.is_empty():
		box.add_child(Ui.spacer(4))
	for line in lines:
		box.add_child(Ui.label(str(line), 22))
	box.add_child(Ui.spacer(10))

	var first: Button = null
	for entry in buttons:
		var btn := Ui.button(entry[0], entry[1])
		box.add_child(btn)
		if first == null:
			first = btn
	if first:
		(func() -> void:
			if is_instance_valid(first) and first.is_inside_tree():
				first.grab_focus()).call_deferred()

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)


func hide_menu() -> void:
	_clear()
	visible = false


func _clear() -> void:
	if _root:
		_root.queue_free()
		_root = null
