extends Control
## Ana menü: oyna, seviye seçimi, nasıl oynanır, ayarlar.

var _content: VBoxContainer
var _motes: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Ui.theme()
	get_tree().paused = false
	Sfx.play_music()

	for i in 70:
		_motes.append({
			"pos": Vector2(randf() * 1280.0, randf() * 720.0),
			"vel": Vector2(randf_range(-8, 8), randf_range(-22, -6)),
			"size": randf_range(1.0, 3.2),
			"phase": randf() * TAU,
		})

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	center.add_child(_content)
	_show_main()


func _process(delta: float) -> void:
	_t += delta
	for m in _motes:
		m["pos"] += m["vel"] * delta
		if m["pos"].y < -10.0:
			m["pos"] = Vector2(randf() * size.x, size.y + 10.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.06, 0.11))
	# Başlığın arkasında yumuşak fener ışıltısı
	var glow_center := Vector2(size.x * 0.5, size.y * 0.28)
	var pulse := 0.9 + 0.1 * sin(_t * 1.7)
	for i in 10:
		var r := (380.0 - i * 34.0) * pulse
		draw_circle(glow_center, r, Color(1.0, 0.7, 0.35, 0.025))
	for m in _motes:
		var a := 0.25 + 0.25 * sin(_t * 2.0 + float(m["phase"]))
		draw_circle(m["pos"], m["size"], Color(1.0, 0.82, 0.5, a))


func _clear() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()


func _focus_first() -> void:
	for c in _content.get_children():
		if c is Button and not (c as Button).disabled:
			var b := c as Button
			(func() -> void:
				if is_instance_valid(b) and b.is_inside_tree():
					b.grab_focus()).call_deferred()
			return


# --- Ekranlar --------------------------------------------------------------

func _show_main() -> void:
	_clear()
	_content.add_child(Ui.label("FENER", 110, Ui.ACCENT))
	_content.add_child(Ui.label("Karanlıkta ışığını kaybetme.", 24, Ui.MUTED))
	_content.add_child(Ui.spacer(30))
	var play_text := "Oyna" if GameManager.unlocked <= 1 and GameManager.total_best() == 0 else "Devam Et"
	_content.add_child(Ui.button(play_text, func() -> void:
		GameManager.start_level(GameManager.unlocked - 1)))
	_content.add_child(Ui.button("Seviye Seç", _show_levels))
	_content.add_child(Ui.button("Nasıl Oynanır", _show_help))
	_content.add_child(Ui.button("Ayarlar", _show_settings))
	if not OS.has_feature("web"):
		_content.add_child(Ui.button("Çıkış", func() -> void: get_tree().quit()))
	var total := GameManager.total_best()
	if total > 0:
		_content.add_child(Ui.spacer(10))
		_content.add_child(Ui.label("Toplam en iyi skor: %d" % total, 18, Ui.MUTED))
	_focus_first()


func _show_levels() -> void:
	_clear()
	_content.add_child(Ui.label("Seviye Seç", 48, Ui.ACCENT))
	_content.add_child(Ui.spacer(10))
	for i in GameManager.level_count():
		var data := GameManager.get_level(i)
		var locked := i >= GameManager.unlocked
		var text := "%d. %s" % [i + 1, data["name"]]
		if locked:
			text += "   (kilitli)"
		elif GameManager.get_best(i) > 0:
			text += "   —   En iyi: %d" % GameManager.get_best(i)
		var index := i
		var b := Ui.button(text, func() -> void: GameManager.start_level(index), 520)
		b.disabled = locked
		_content.add_child(b)
	_content.add_child(Ui.spacer(10))
	_content.add_child(Ui.button("Geri", _show_main, 520))
	_focus_first()


func _show_help() -> void:
	_clear()
	_content.add_child(Ui.label("Nasıl Oynanır", 48, Ui.ACCENT))
	_content.add_child(Ui.spacer(6))
	var lines := [
		"Fenerinin ışığı zamanla azalır. Sıfırlanırsa karanlık seni yutar.",
		"Altın ışık küreleri fenerini doldurur.",
		"Mavi kıvılcımların hepsini topla, çıkış kapısı açılsın.",
		"Gölgeler parlak ışığa çekilir ve dokunursa ışık çalar.",
		"BOŞLUK ile parlama yap: yakındaki gölgeleri sersemletir (ışık harcar).",
		"Fener direklerinin çemberi güvenlidir: gölgeler giremez, ışığın dolar.",
		"",
		"Hareket: WASD / Oklar   •   Duraklat: Esc / P   •   Yeniden başla: R",
	]
	for line in lines:
		_content.add_child(Ui.label(line, 20))
	_content.add_child(Ui.spacer(14))
	_content.add_child(Ui.button("Geri", _show_main))
	_focus_first()


func _show_settings() -> void:
	_clear()
	_content.add_child(Ui.label("Ayarlar", 48, Ui.ACCENT))
	_content.add_child(Ui.spacer(10))
	_content.add_child(_slider_row("Ana ses", GameManager.master_volume, func(v: float) -> void:
		GameManager.master_volume = v))
	_content.add_child(_slider_row("Müzik", GameManager.music_volume, func(v: float) -> void:
		GameManager.music_volume = v))
	_content.add_child(_slider_row("Efektler", GameManager.sfx_volume, func(v: float) -> void:
		GameManager.sfx_volume = v
		Sfx.play("orb")))
	var fs := CheckButton.new()
	fs.text = "Tam ekran"
	fs.button_pressed = GameManager.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		GameManager.fullscreen = on
		GameManager.apply_settings())
	_content.add_child(fs)
	_content.add_child(Ui.spacer(14))
	_content.add_child(Ui.button("Geri", func() -> void:
		GameManager.save_game()
		_show_main()))
	_focus_first()


func _slider_row(title: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Ui.label(title, 22)
	l.custom_minimum_size = Vector2(140, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 32)
	s.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		GameManager.apply_settings())
	row.add_child(s)
	return row
