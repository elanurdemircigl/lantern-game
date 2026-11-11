extends Node
## Otomatik duman testi: her seviyeyi yükler, oyuncuyu kıvılcımlara ve çıkışa ışınlar,
## kazanma akışını ve ölümü doğrular.
##
## Kullanım: godot --headless --path . res://tools/smoke_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	GameManager.persist = false
	GameManager.best_scores = {}
	GameManager.unlocked = 1
	await _run()
	if _failures.is_empty():
		print("SMOKE TEST: TÜM SEVİYELER GEÇTİ")
		get_tree().quit(0)
	else:
		for f in _failures:
			print("SMOKE TEST HATA: ", f)
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var game_scene: PackedScene = load(GameManager.GAME_SCENE)
	for i in GameManager.level_count():
		GameManager.current_level = i
		var game := game_scene.instantiate()
		add_child(game)
		await _frames(30)

		var player: Player = game.player
		if player == null:
			_failures.append("Seviye %d: oyuncu yok" % (i + 1))
			game.queue_free()
			continue

		# Tüm kıvılcımları topla
		for node in game.get_tree().get_nodes_in_group("shadows"):
			node.process_mode = Node.PROCESS_MODE_DISABLED
		var sparks: Array[Pickup] = []
		for child in game.find_child("Entities", true, false).get_children():
			if child is Pickup and child.kind == Pickup.Kind.SPARK:
				sparks.append(child)
		for s in sparks:
			player.global_position = s.global_position
			await _frames(4)
		if game.sparks_collected != game.sparks_total:
			_failures.append("Seviye %d: kıvılcım %d/%d" % [i + 1, game.sparks_collected, game.sparks_total])
		if not game.exit_door.is_open:
			_failures.append("Seviye %d: kapı açılmadı" % (i + 1))

		player.global_position = game.exit_door.global_position
		await _frames(50)
		if game.state != game.State.WON:
			_failures.append("Seviye %d: kazanma durumu yok (state=%d)" % [i + 1, game.state])
		else:
			print("Seviye %d tamam: skor=%d" % [i + 1, GameManager.get_best(i)])
		game.queue_free()
		await _frames(2)

	# Ölüm akışı: ilk seviyede ışığı sıfırla
	GameManager.current_level = 1
	var g2 := game_scene.instantiate()
	add_child(g2)
	await _frames(10)
	g2.player.set_energy(0.0)
	await _frames(120)
	if g2.state != g2.State.LOST:
		_failures.append("Ölüm akışı çalışmadı")
	else:
		print("Ölüm akışı tamam")
	g2.queue_free()
	await _frames(2)

	# Gölge davranışı: seviye 2, oyuncuyu gölgenin yanına koy ve parlama yap
	GameManager.current_level = 1
	var g3 := game_scene.instantiate()
	add_child(g3)
	await _frames(10)
	var shadow: ShadowEnemy = g3.get_tree().get_nodes_in_group("shadows")[0]
	g3.player.global_position = shadow.global_position + Vector2(60, 0)
	await _frames(40)
	print("Gölge durumu yaklaşınca: ", ShadowEnemy.State.keys()[shadow.state], "  oyuncu ışığı: %.1f" % g3.player.energy)
	g3.player.try_flash()
	await _frames(2)
	if shadow.global_position.distance_to(g3.player.global_position) < Player.FLASH_RADIUS and shadow.state != ShadowEnemy.State.STUNNED:
		_failures.append("Parlama gölgeyi sersemletmedi")
	else:
		print("Parlama tamam: gölge ", ShadowEnemy.State.keys()[shadow.state])
	g3.queue_free()
	await _frames(2)

	# Menü yüklenebiliyor mu
	var menu: Control = load(GameManager.MENU_SCENE).instantiate()
	add_child(menu)
	await _frames(5)
	menu.call("_show_levels")
	menu.call("_show_settings")
	menu.call("_show_help")
	await _frames(5)
	menu.queue_free()
	print("Menü tamam")
