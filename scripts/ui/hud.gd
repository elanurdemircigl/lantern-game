class_name Hud
extends CanvasLayer
## Oyun içi gösterge: ışık çubuğu, parlama bekleme süresi, kıvılcım sayacı, süre ve bildirimler.

var _energy_bar: ProgressBar
var _flash_bar: ProgressBar
var _sparks_label: Label
var _time_label: Label
var _toast: Label
var _toast_tween: Tween
var _fill_normal: StyleBoxFlat
var _fill_low: StyleBoxFlat
var _damage: ColorRect


func setup(level_number: int, level_name: String, sparks_total: int) -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Ui.theme()
	add_child(root)

	# Hasar alınca ekran kenarı kızarır
	_damage = ColorRect.new()
	_damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage.color = Color(0.8, 0.05, 0.05, 0.0)
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var bar := HBoxContainer.new()
	margin.add_child(bar)

	# Sol: ışık ve parlama
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(300, 0)
	bar.add_child(left)
	var energy_title := Ui.label("IŞIK", 16, Ui.MUTED)
	energy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(energy_title)
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(280, 22)
	_energy_bar.show_percentage = false
	_energy_bar.max_value = 100
	_energy_bar.value = 100
	left.add_child(_energy_bar)
	_fill_normal = Ui.theme().get_stylebox("fill", "ProgressBar").duplicate()
	_fill_low = _fill_normal.duplicate()
	_fill_low.bg_color = Ui.DANGER
	_flash_bar = ProgressBar.new()
	_flash_bar.custom_minimum_size = Vector2(280, 6)
	_flash_bar.show_percentage = false
	_flash_bar.max_value = 1.0
	_flash_bar.value = 1.0
	var flash_fill := _fill_normal.duplicate() as StyleBoxFlat
	flash_fill.bg_color = Color(0.75, 0.85, 1.0)
	_flash_bar.add_theme_stylebox_override("fill", flash_fill)
	left.add_child(_flash_bar)

	# Orta: seviye adı
	var title := Ui.label("%d. %s" % [level_number, level_name], 26, Ui.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	# Sağ: kıvılcım ve süre
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	bar.add_child(right)
	_sparks_label = Ui.label("", 24, Color(0.6, 0.95, 1.0))
	_sparks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sparks_label)
	_time_label = Ui.label("0:00", 20, Ui.MUTED)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_time_label)
	update_sparks(0, sparks_total)

	# Bildirim
	_toast = Ui.label("", 28)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 130
	_toast.offset_bottom = 180
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# Alt: kontroller
	var hint := Ui.label("WASD / Oklar: Hareket   •   Boşluk: Parlama   •   Esc: Duraklat   •   R: Yeniden başla", 16, Ui.MUTED)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -14
	hint.modulate.a = 0.7
	root.add_child(hint)


func update_energy(value: float, max_value: float) -> void:
	_energy_bar.max_value = max_value
	_energy_bar.value = value
	var low := value / max_value < 0.25
	_energy_bar.add_theme_stylebox_override("fill", _fill_low if low else _fill_normal)


func update_flash(ratio: float) -> void:
	_flash_bar.value = ratio


func update_sparks(count: int, total: int) -> void:
	_sparks_label.text = "Kıvılcım  %d / %d" % [count, total]


func update_time(seconds: float) -> void:
	_time_label.text = Ui.format_time(seconds)


func damage_flash() -> void:
	_damage.color.a = 0.28
	create_tween().tween_property(_damage, "color:a", 0.0, 0.4)


func toast(text: String, color := Ui.TEXT, duration := 2.5) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
