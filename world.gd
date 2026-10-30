extends Node2D

@export var world_size: int = 300
@export var placement_range_tiles: float = 4.0
@export var harvest_range_tiles: float = 3.0

const TILE_SIZE := 16
const INVALID_CELL := Vector2i(2147483647, 2147483647)

const FENCE_DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

const DEFAULT_DROPS := {
	"stone": {"item_id": "stone", "min": 1, "max": 1},
	"mega_stone": {"item_id": "mega_stone", "min": 1, "max": 1},
	"floor": {"item_id": "wood", "min": 1, "max": 1},
	"fence": {"item_id": "fence", "min": 1, "max": 1}
}

@onready var id_storage: Node2D = $"../IDStorage"
@onready var ground: TileMapLayer = $"../IDStorage/Ground"
@onready var resources_layer: TileMapLayer = $"../IDStorage/Resources"
@onready var world_generator: Node = $"../WorldGenerator"

var rng := RandomNumberGenerator.new()

var terrain_types: Dictionary = {}
var objects: Dictionary = {}
var occupied_cells: Dictionary = {}

var open_chest_anchor: Vector2i = INVALID_CELL


func _ready() -> void:
	add_to_group("world")
	rng.randomize()

	if not id_storage.setup_tilesets():
		push_error("Не удалось настроить TileSet в IDStorage.")


# ==================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==================================================

func _item_data(item_id: String) -> Dictionary:
	return id_storage.get_item(item_id)


func _tiles(item_id: String) -> Array:
	return id_storage.get_tiles(item_id)


func _random_tile(item_id: String) -> Vector2i:
	var tiles := _tiles(item_id)

	if tiles.is_empty():
		push_warning("У предмета '%s' нет тайлов мира." % item_id)
		return Vector2i.ZERO

	return tiles.pick_random()


func _resolve_item_id(value: String) -> String:
	if not _item_data(value).is_empty():
		return value

	return id_storage.get_item_id_by_name(value)


func _ground_kind(cell: Vector2i) -> String:
	return str(terrain_types.get(cell, "empty"))


func _cell_world_position(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


func get_world_bounds() -> Rect2:
	var size := float(world_size * TILE_SIZE)
	return Rect2(Vector2(-size / 2.0, -size / 2.0), Vector2(size, size))


func _is_walkable_cell(cell: Vector2i) -> bool:
	return _ground_kind(cell) not in ["water", "empty"]


func _can_place_on_cell(cell: Vector2i) -> bool:
	if not get_world_bounds().has_point(_cell_world_position(cell)):
		return false

	if not _is_walkable_cell(cell):
		return false

	return not occupied_cells.has(cell) \
		and resources_layer.get_cell_source_id(cell) == -1


func _create_body(
	body_name: String,
	cell: Vector2i,
	size: Vector2
) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = ground.map_to_local(cell)
	body.collision_layer = 1
	body.collision_mask = 1

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size

	collision.shape = shape
	body.add_child(collision)
	add_child(body)

	return body


func _register_object(
	anchor: Vector2i,
	item_id: String,
	body: Node,
	cells: Array,
	extra_data: Dictionary = {}
) -> void:
	var item_data := _item_data(item_id)
	var max_health := int(item_data.get("health", 0))

	var object_data := {
		"type": item_id,
		"body": body,
		"cells": cells,
		"max_health": max_health,
		"health": max_health
	}

	object_data.merge(extra_data, true)
	objects[anchor] = object_data

	for cell in cells:
		occupied_cells[cell] = anchor


func _get_object_tile(item_id: String, generated_tile: Vector2i) -> Vector2i:
	if generated_tile != Vector2i(-1, -1):
		return generated_tile

	return _random_tile(item_id)


# ==================================================
# ГЕНЕРАЦИЯ МИРА
# ==================================================

func generate_world() -> void:
	_close_chest_visual()

	for data in objects.values():
		var body: Node = data.get("body")
		if is_instance_valid(body):
			body.queue_free()

	ground.clear()
	resources_layer.clear()

	terrain_types.clear()
	objects.clear()
	occupied_cells.clear()
	open_chest_anchor = INVALID_CELL

	var generated: Dictionary = world_generator.generate()

	if generated.is_empty():
		push_error("WorldGenerator вернул пустой мир.")
		return

	world_size = int(generated.get("world_size", world_size))

	for cell in generated.get("terrain", {}):
		var tile_data: Dictionary = generated["terrain"][cell]

		ground.set_cell(
			cell,
			int(tile_data.get("source_id", 0)),
			tile_data.get("atlas", Vector2i.ZERO)
		)
		
		terrain_types[cell] = str(tile_data.get("type", ""))

	for anchor in generated.get("objects", {}):
		var object_data: Dictionary = generated["objects"][anchor]
		var item_id := str(object_data.get("type", ""))

		if item_id.is_empty():
			continue

		_spawn_object(
			anchor,
			item_id,
			object_data.get("atlas", Vector2i(-1, -1))
		)

	EventBus.world_generated.emit()


# ==================================================
# СОЗДАНИЕ ОБЪЕКТОВ
# ==================================================

func _spawn_object(
	cell: Vector2i,
	item_id: String,
	generated_tile: Vector2i = Vector2i(-1, -1)
) -> bool:
	if not _is_walkable_cell(cell) or occupied_cells.has(cell):
		return false

	if _ground_kind(cell) == "sand" and item_id != "stone":
		return false

	var data := _item_data(item_id)
	var source_id: int = id_storage.get_world_source_id(item_id)

	if data.is_empty() or source_id < 0:
		return false

	var tile := _get_object_tile(item_id, generated_tile)

	if _tiles(item_id).is_empty():
		return false

	resources_layer.set_cell(cell, source_id, tile)

	var body: StaticBody2D = null

	if data.get("collision_enabled", true):
		body = _create_body(
			"Obstacle_" + item_id,
			cell,
			Vector2(TILE_SIZE, TILE_SIZE)
		)

	_register_object(cell, item_id, body, [cell])
	return true


func _create_mega_stone(
	cell: Vector2i,
	generated_tile: Vector2i = Vector2i(-1, -1)
) -> bool:
	var data := _item_data("mega_stone")

	if data.is_empty():
		return false

	var size_tiles := int(data.get("size_tiles", 3))
	var cells: Array[Vector2i] = []

	for x in range(size_tiles):
		for y in range(size_tiles):
			var part := cell + Vector2i(x, y)

			if not _is_walkable_cell(part) or occupied_cells.has(part):
				return false

			if resources_layer.get_cell_source_id(part) != -1:
				return false

			cells.append(part)

	var tile := _get_object_tile("mega_stone", generated_tile)

	var offset := Vector2(
		TILE_SIZE * (size_tiles - 1) / 2.0,
		TILE_SIZE * (size_tiles - 1) / 2.0
	)

	var body := _create_body(
		"MegaStone",
		cell,
		Vector2(TILE_SIZE * size_tiles, TILE_SIZE * size_tiles)
	)

	body.position += offset

	var sprite := Sprite2D.new()
	sprite.texture = id_storage.objects_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(tile * TILE_SIZE),
		Vector2(TILE_SIZE, TILE_SIZE)
	)
	sprite.scale = Vector2(size_tiles, size_tiles)

	body.add_child(sprite)

	_register_object(cell, "mega_stone", body, cells)
	return true


func _create_chest(cell: Vector2i) -> bool:
	if not _can_place_on_cell(cell):
		return false

	var body := _create_body(
		"Chest",
		cell,
		Vector2(TILE_SIZE, TILE_SIZE)
	)

	var sprite := Sprite2D.new()
	sprite.texture = id_storage.furniture_texture
	sprite.region_enabled = true
	sprite.region_rect = _furniture_region("chest", 0)
	body.add_child(sprite)

	var storage: Array[Dictionary] = []

	for i in range(4):
		storage.append({"item": "", "count": 0})

	_register_object(cell, "chest", body, [cell], {
		"storage": storage,
		"sprite": sprite
	})

	return true


func _furniture_region(item_id: String, index: int) -> Rect2:
	var tile: Vector2i = id_storage.get_variation_tile(item_id, index)
	return Rect2(Vector2(tile * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))


func _create_wood_floor(cell: Vector2i) -> bool:
	if not _can_place_on_cell(cell):
		return false

	var source_id: int = id_storage.get_world_source_id("floor")
	var tile: Vector2i = id_storage.get_variation_tile("floor", 0)

	if source_id < 0:
		return false

	resources_layer.set_cell(cell, source_id, tile)
	_register_object(cell, "floor", null, [cell])

	return true


# ==================================================
# СБОР РЕСУРСОВ
# ==================================================
func damage_object(
	mouse_position: Vector2,
	player_position: Vector2,
	current_health: int
) -> Dictionary:
	if player_position.distance_to(mouse_position) > harvest_range_tiles * TILE_SIZE:
		return {}

	var cell := ground.local_to_map(ground.to_local(mouse_position))

	if not occupied_cells.has(cell):
		return {}

	var anchor: Vector2i = occupied_cells[cell]
	var data: Dictionary = objects.get(anchor, {})
	var kind := str(data.get("type", ""))

	if kind.is_empty() or kind == "chest":
		return {}

	# Максимальное здоровье берём непосредственно из IDStorage.
	var max_health := int(_item_data(kind).get("health", 0))

	if max_health <= 0:
		return {}

	# Наносим один удар, не сохраняя здоровье в objects.
	var health: int = maxi(0, current_health - 1)

	if health > 0:
		return {
			"anchor": anchor,
			"health": health,
			"max_health": max_health,
			"reward": {}
		}

	var reward := harvest_at(mouse_position, player_position)

	return {
		"anchor": anchor,
		"health": 0,
		"max_health": max_health,
		"reward": reward
	}

func harvest_at(mouse_position: Vector2, player_position: Vector2) -> Dictionary:
	if player_position.distance_to(mouse_position) > harvest_range_tiles * TILE_SIZE:
		print("Слишком далеко для сбора.")
		return {}

	var cell := ground.local_to_map(ground.to_local(mouse_position))

	if not occupied_cells.has(cell):
		print("Здесь нет ресурса.")
		return {}

	var anchor: Vector2i = occupied_cells[cell]
	var data: Dictionary = objects.get(anchor, {})
	var kind := str(data.get("type", ""))

	if kind.is_empty():
		return {}

	if kind == "chest":
		print("Сундук открывается клавишей F.")
		return {}

	var drops: Array = _item_data(kind).get("drops", [])

	if drops.is_empty() and DEFAULT_DROPS.has(kind):
		drops = [DEFAULT_DROPS[kind]]

	if drops.is_empty():
		print("У этого объекта нет ресурсов для сбора.")
		return {}

	var drop: Dictionary = drops[0]
	var drop_id := str(drop.get("item_id", ""))

	if drop_id.is_empty():
		push_warning("У объекта '%s' не указан item_id выпадения." % kind)
		return {}

	var minimum := int(drop.get("min", 1))
	var maximum := int(drop.get("max", minimum))

	return {
		"anchor": anchor,
		"object_type": kind,
		"item_id": drop_id,
		"item_name": id_storage.get_item_name(drop_id),
		"amount": rng.randi_range(minimum, maximum)
	}


func commit_harvest(reward: Dictionary) -> bool:
	if reward.is_empty():
		return false

	var anchor: Vector2i = reward.get("anchor", INVALID_CELL)
	var expected_type := str(reward.get("object_type", ""))

	if not objects.has(anchor):
		return false

	if objects[anchor].get("type") != expected_type or expected_type == "chest":
		return false

	_remove_object(anchor)

	if expected_type == "tree":
		_spawn_object(anchor, "stump")

	return true


func _remove_object(anchor: Vector2i) -> void:
	if not objects.has(anchor):
		return

	if open_chest_anchor == anchor:
		_close_chest_visual()

	var data: Dictionary = objects[anchor]
	var was_fence: bool = str(data.get("type", "")) == "fence"

	for cell in data.get("cells", [anchor]):
		occupied_cells.erase(cell)
		resources_layer.erase_cell(cell)

	objects.erase(anchor)

	var body: Node = data.get("body")
	if is_instance_valid(body):
		body.queue_free()

	if was_fence:
		_refresh_fence_tiles_around(anchor)


# ==================================================
# УСТАНОВКА ПРЕДМЕТОВ
# ==================================================

func place_item(
	world_position: Vector2,
	item_name_or_id: String,
	player_position: Vector2
) -> bool:
	if not get_world_bounds().has_point(world_position):
		return false

	if player_position.distance_to(world_position) > placement_range_tiles * TILE_SIZE:
		print("Слишком далеко для установки.")
		return false

	var cell := ground.local_to_map(ground.to_local(world_position))
	var item_id := _resolve_item_id(item_name_or_id)

	if item_id.is_empty():
		return false

	var place_as := str(_item_data(item_id).get("place_as", ""))

	match place_as:
		"stone", "bush", "tree", "stump":
			return _spawn_object(cell, place_as)
		"mega_stone":
			return _create_mega_stone(cell)
		"chest":
			return _create_chest(cell)
		"floor":
			return _create_wood_floor(cell)
		"fence":
			return _create_fence(cell)

	return false


# ==================================================
# СУНДУКИ
# ==================================================

func _close_chest_visual() -> void:
	if open_chest_anchor == INVALID_CELL:
		return

	if objects.has(open_chest_anchor):
		var sprite: Sprite2D = objects[open_chest_anchor].get("sprite")

		if is_instance_valid(sprite):
			sprite.region_rect = _furniture_region("chest", 0)

	open_chest_anchor = INVALID_CELL


func toggle_chest(anchor: Vector2i) -> Array:
	if not objects.has(anchor) or objects[anchor].get("type") != "chest":
		return []

	if open_chest_anchor == anchor:
		_close_chest_visual()
		return []

	_close_chest_visual()
	open_chest_anchor = anchor

	var sprite: Sprite2D = objects[anchor].get("sprite")

	if is_instance_valid(sprite):
		sprite.region_rect = _furniture_region("chest", 1)

	return objects[anchor]["storage"]


func find_nearest_chest(player_position: Vector2) -> Vector2i:
	var best_anchor := INVALID_CELL
	var best_distance := harvest_range_tiles * TILE_SIZE

	for anchor in objects:
		if objects[anchor].get("type") != "chest":
			continue

		var distance := player_position.distance_to(_cell_world_position(anchor))

		if distance <= best_distance:
			best_distance = distance
			best_anchor = anchor

	return best_anchor


func get_chest_storage(anchor: Vector2i) -> Array:
	if objects.get(anchor, {}).get("type") != "chest":
		return []

	return objects[anchor]["storage"]


func get_chest_at(mouse_position: Vector2, player_position: Vector2) -> Vector2i:
	if player_position.distance_to(mouse_position) > harvest_range_tiles * TILE_SIZE:
		return INVALID_CELL

	var cell := ground.local_to_map(ground.to_local(mouse_position))

	if not occupied_cells.has(cell):
		return INVALID_CELL

	var anchor: Vector2i = occupied_cells[cell]

	if objects.get(anchor, {}).get("type") != "chest":
		return INVALID_CELL

	return anchor


func is_too_far_from_open_chest(player_position: Vector2) -> bool:
	if open_chest_anchor == INVALID_CELL:
		return false

	return player_position.distance_to(_cell_world_position(open_chest_anchor)) > 5.0 * TILE_SIZE


# ==================================================
# ЗАБОРЫ
# ==================================================

func _fence_mask(cell: Vector2i) -> int:
	var mask := 0

	for i in range(FENCE_DIRS.size()):
		var neighbor := cell + FENCE_DIRS[i]

		if objects.get(neighbor, {}).get("type") == "fence":
			mask |= 1 << i

	return mask


func _update_fence_tile(cell: Vector2i) -> void:
	if objects.get(cell, {}).get("type") != "fence":
		return

	var source_id: int = id_storage.get_world_source_id("fence")

	if source_id < 0:
		push_warning("Для забора не назначен источник тайлов.")
		return

	var tile: Vector2i = id_storage.get_variation_tile("fence", _fence_mask(cell))
	resources_layer.set_cell(cell, source_id, tile)


func _refresh_fence_tiles_around(cell: Vector2i) -> void:
	_update_fence_tile(cell)

	for direction in FENCE_DIRS:
		_update_fence_tile(cell + direction)


func _create_fence(cell: Vector2i) -> bool:
	if not _can_place_on_cell(cell):
		return false

	var data := _item_data("fence")
	var body: StaticBody2D = null

	if data.get("collision_enabled", true):
		body = _create_body(
			"Fence",
			cell,
			Vector2(TILE_SIZE, TILE_SIZE)
		)

	_register_object(cell, "fence", body, [cell])
	_refresh_fence_tiles_around(cell)

	return true
