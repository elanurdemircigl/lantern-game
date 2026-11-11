extends Node
## README / itch.io için ekran görüntüsü alır (pencereli çalıştırılmalı, headless değil).
##
## Kullanım: godot --path . res://tools/screenshot.tscn
## Çıktı: docs/screenshots/*.png

const OUT_DIR := "res://docs/screenshots/"


func _ready() -> void:
	GameManager.persist = false
	await _shot_menu()
	await _shot_level(0, Vector2(4, 6), "level1.png", false)
	await _shot_level(1, Vector2(26, 5), "level2.png", true)
	await _shot_level(2, Vector2(3, 3), "level3.png", false)
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	print("Kaydedildi: ", name)


func _shot_menu() -> void:
	var menu: Control = load(GameManager.MENU_SCENE).instantiate()
	add_child(menu)
	await _wait(90)
	await _save("menu.png")
	menu.queue_free()
	await _wait(2)


func _shot_level(index: int, cell: Vector2, name: String, flash: bool) -> void:
	GameManager.current_level = index
	var game: Node2D = load(GameManager.GAME_SCENE).instantiate()
	add_child(game)
	await _wait(5)
	game.player.global_position = cell * LevelMap.TILE + Vector2(16, 16)
	await _wait(80)
	if flash:
		game.player.try_flash()
		await _wait(4)
	await _save(name)
	game.queue_free()
	await _wait(2)
