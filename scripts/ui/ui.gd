class_name Ui
extends RefCounted
## Ortak arayüz teması ve küçük düğüm oluşturma yardımcıları.

const ACCENT := Color(1.0, 0.78, 0.4)
const TEXT := Color(0.95, 0.92, 0.85)
const MUTED := Color(0.65, 0.62, 0.7)
const DANGER := Color(1.0, 0.42, 0.38)
const GOOD := Color(0.5, 1.0, 0.8)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22

	t.set_stylebox("normal", "Button", _box(Color(0.16, 0.13, 0.2), Color(0.45, 0.36, 0.25)))
	t.set_stylebox("hover", "Button", _box(Color(0.24, 0.19, 0.28), ACCENT))
	t.set_stylebox("pressed", "Button", _box(Color(0.30, 0.22, 0.15), ACCENT))
	t.set_stylebox("disabled", "Button", _box(Color(0.10, 0.09, 0.12), Color(0.22, 0.2, 0.24)))
	var focus := _box(Color(0, 0, 0, 0), ACCENT)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.38, 0.42))

	var panel := _box(Color(0.07, 0.06, 0.1, 0.94), Color(0.45, 0.36, 0.25), 14)
	panel.set_content_margin_all(32)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)

	var bar_bg := _box(Color(0.1, 0.08, 0.12, 0.85), Color(0.35, 0.3, 0.25), 6)
	bar_bg.set_content_margin_all(0)
	var bar_fill := _box(ACCENT, ACCENT, 6)
	bar_fill.set_border_width_all(0)
	bar_fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	_theme = t
	return t


static func _box(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, on_pressed: Callable, min_width := 300) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 52)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		on_pressed.call())
	return b


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
