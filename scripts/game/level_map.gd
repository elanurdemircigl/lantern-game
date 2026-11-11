class_name LevelMap
extends Node2D
## ASCII haritadan seviyeyi kurar: zemin/duvar çizimi, çarpışmalar,
## ışık engelleyiciler (gölgeler) ve gölge düşmanlar için A* yol bulma.

const TILE := 32
const FLOOR_A := Color(0.40, 0.36, 0.32)
const FLOOR_B := Color(0.36, 0.33, 0.30)
const FLOOR_SPECK := Color(0.30, 0.27, 0.25)
const WALL_TOP := Color(0.34, 0.31, 0.42)
const WALL_FACE := Color(0.20, 0.18, 0.26)
const WALL_EDGE := Color(0.48, 0.44, 0.56)

var width := 0
var height := 0
var astar: AStarGrid2D

var _solid := PackedByteArray()
var _walls: Node2D


func build(map_text: String) -> Dictionary:
	var rows: Array[String] = []
	for raw in map_text.strip_edges().split("\n"):
		rows.append(raw.strip_edges())
	height = rows.size()
	width = 0
	for r in rows:
		width = maxi(width, r.length())
	_solid.resize(width * height)
	_solid.fill(0)

	var spawns := {
		"player": Vector2.ZERO,
		"exit": Vector2.ZERO,
		"orbs": [],
		"sparks": [],
		"shadows": [],
		"lamps": [],
	}
	for y in height:
		var row := rows[y]
		for x in width:
			var c := row[x] if x < row.length() else "#"
			var pos := cell_center(Vector2i(x, y))
			match c:
				"#":
					_solid[y * width + x] = 1
				"P":
					spawns["player"] = pos
				"E":
					spawns["exit"] = pos
				"o":
					spawns["orbs"].append(pos)
				"*":
					spawns["sparks"].append(pos)
				"S":
					spawns["shadows"].append(pos)
				"L":
					spawns["lamps"].append(pos)

	_walls = Node2D.new()
	_walls.name = "Walls"
	_walls.light_mask = 2
	_walls.draw.connect(_draw_walls)
	add_child(_walls)

	_build_colliders()
	_build_astar()
	queue_redraw()
	return spawns


# --- Sorgular --------------------------------------------------------------

func is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return true
	return _solid[cell.y * width + cell.x] == 1


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func world_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if is_solid(a) or is_solid(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b, true)


## center etrafında (hücre cinsinden) rastgele bir zemin noktası; bulamazsa center.
func random_floor_near(center: Vector2, radius_cells: int, avoid: Callable = Callable()) -> Vector2:
	var c := world_to_cell(center)
	for attempt in 24:
		var cell := c + Vector2i(randi_range(-radius_cells, radius_cells), randi_range(-radius_cells, radius_cells))
		if is_solid(cell):
			continue
		var pos := cell_center(cell)
		if avoid.is_valid() and avoid.call(pos):
			continue
		return pos
	return center


# --- Kurulum ---------------------------------------------------------------

func _build_colliders() -> void:
	var body := StaticBody2D.new()
	body.name = "WallBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# Komşu duvar hücrelerini yatay şeritlerde birleştir (daha az düğüm).
	for y in height:
		var x := 0
		while x < width:
			if not is_solid(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while x < width and is_solid(Vector2i(x, y)):
				x += 1
			var rect := Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE)

			var shape := RectangleShape2D.new()
			shape.size = rect.size
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = rect.get_center()
			body.add_child(cs)

			var poly := OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y),
			])
			var occ := LightOccluder2D.new()
			occ.occluder = poly
			add_child(occ)


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE * 0.5, TILE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			if is_solid(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)


# --- Çizim -----------------------------------------------------------------

func _draw() -> void:
	for y in height:
		for x in width:
			if is_solid(Vector2i(x, y)):
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(r, FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
			# Deterministik küçük lekeler: taş zemin dokusu
			var h := (x * 73856093) ^ (y * 19349663)
			if h % 3 == 0:
				var p := r.position + Vector2(4 + abs(h) % 20, 4 + abs(h >> 5) % 20)
				draw_rect(Rect2(p, Vector2(3, 3)), FLOOR_SPECK)


func _draw_walls() -> void:
	for y in height:
		for x in width:
			if not is_solid(Vector2i(x, y)):
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			var floor_below := not is_solid(Vector2i(x, y + 1))
			if floor_below:
				# Ön yüz: üstte kapak, altta koyu yüz → derinlik hissi
				_walls.draw_rect(Rect2(r.position, Vector2(TILE, TILE * 0.55)), WALL_TOP)
				_walls.draw_rect(Rect2(r.position + Vector2(0, TILE * 0.55), Vector2(TILE, TILE * 0.45)), WALL_FACE)
			else:
				_walls.draw_rect(r, WALL_TOP)
			if not is_solid(Vector2i(x, y - 1)):
				_walls.draw_rect(Rect2(r.position, Vector2(TILE, 2)), WALL_EDGE)
