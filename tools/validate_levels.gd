extends SceneTree
## Seviye haritalarını doğrular: satır genişlikleri, kenar duvarları, tek P/E,
## ve oyuncunun tüm nesnelere ulaşabildiği.
##
## Kullanım: godot --headless --path . --script res://tools/validate_levels.gd

const LevelData := preload("res://scripts/levels.gd")


func _init() -> void:
	var all_ok := true
	for i in LevelData.LEVELS.size():
		var level: Dictionary = LevelData.LEVELS[i]
		var errors := check_map(level["map"])
		if errors.is_empty():
			print("[OK]   Seviye %d - %s" % [i + 1, level["name"]])
		else:
			all_ok = false
			print("[HATA] Seviye %d - %s" % [i + 1, level["name"]])
			for e in errors:
				print("         ", e)
	quit(0 if all_ok else 1)


static func check_map(map_text: String) -> Array[String]:
	var errors: Array[String] = []
	var rows: Array[String] = []
	for raw in map_text.strip_edges().split("\n"):
		rows.append(raw.strip_edges())
	var h := rows.size()
	var w := rows[0].length()
	for y in h:
		if rows[y].length() != w:
			errors.append("Satır %d genişliği %d (beklenen %d)" % [y, rows[y].length(), w])
	if not errors.is_empty():
		return errors

	var counts := {}
	var start := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var c := rows[y][x]
			counts[c] = int(counts.get(c, 0)) + 1
			if c == "P":
				start = Vector2i(x, y)
			var border := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if border and c != "#":
				errors.append("Kenar duvarı eksik: (%d,%d)" % [x, y])
			if not c in ["#", ".", "P", "E", "o", "*", "S", "L"]:
				errors.append("Bilinmeyen karakter '%s' (%d,%d)" % [c, x, y])
	if int(counts.get("P", 0)) != 1:
		errors.append("Tam olarak bir P olmalı")
	if int(counts.get("E", 0)) != 1:
		errors.append("Tam olarak bir E olmalı")
	if start.x < 0:
		return errors

	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if seen.has(n) or rows[n.y][n.x] == "#":
				continue
			seen[n] = true
			queue.append(n)

	for y in h:
		for x in w:
			var c := rows[y][x]
			if c != "#" and not seen.has(Vector2i(x, y)):
				errors.append("Ulaşılamayan hücre '%s' (%d,%d)" % [c, x, y])
	return errors
