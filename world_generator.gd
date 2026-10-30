extends Node

@export var world_size: int = 300
@export var id_storage_path: NodePath = ^"../IDStorage"

var id_storage: Node2D

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()


func _ready() -> void:
	id_storage = get_node_or_null(id_storage_path)

	if id_storage == null:
		push_error("WorldGenerator: не найден IDStorage.")
		return

	rng.randomize()

	noise.frequency = 0.035
	noise.fractal_octaves = 3


# ==================================================
# ГЕНЕРАЦИЯ МИРА
# ==================================================

func generate() -> Dictionary:
	if not is_instance_valid(id_storage):
		push_error("WorldGenerator: генерация невозможна без IDStorage.")
		return {}

	noise.seed = rng.randi()

	var terrain: Dictionary = {}
	var objects: Dictionary = {}
	var half := int(world_size / 2)

	# Генерируем поверхность.
	for x in range(-half, half):
		for y in range(-half, half):
			var cell := Vector2i(x, y)
			var value := noise.get_noise_2d(x, y)
			var surface := _get_surface(value)

			terrain[cell] = {
				"type": surface,
				"source_id": 0,
				"atlas": _random_tile(surface)
			}

	# Размещаем ресурсы после создания всей поверхности.
	_generate_resources(terrain, objects)

	return {
		"terrain": terrain,
		"objects": objects,
		"world_size": world_size
	}


func _get_surface(value: float) -> String:
	if value < -0.42:
		return "water"
	if value < -0.30:
		return "sand"
	if value > 0.35:
		return "dirt"

	return "grass"


# ==================================================
# РАБОТА С IDSTORAGE
# ==================================================

func _item_data(item_id: String) -> Dictionary:
	return id_storage.get_item(item_id)


func _random_tile(item_id: String) -> Vector2i:
	var tiles: Array = id_storage.get_tiles(item_id)

	if tiles.is_empty():
		push_error("WorldGenerator: у предмета '%s' нет тайлов." % item_id)
		return Vector2i.ZERO

	return tiles[rng.randi_range(0, tiles.size() - 1)]


# ==================================================
# ГЕНЕРАЦИЯ РЕСУРСОВ
# ==================================================

func _generate_resources(
	terrain: Dictionary,
	objects: Dictionary
) -> void:
	var half := int(world_size / 2)

	for x in range(-half, half):
		for y in range(-half, half):
			var cell := Vector2i(x, y)
			var surface: String = terrain[cell]["type"]

			# Вода и пустые клетки пропускаются.
			if surface == "water":
				continue

			# Свободная область в центре карты.
			if abs(x) <= 2 and abs(y) <= 2:
				continue

			var roll := rng.randf()
			var item_id := ""

			if surface == "sand":
				if roll < 0.018:
					item_id = "stone"
			elif roll < 0.018:
				item_id = "stone"
			elif roll < 0.026:
				item_id = "bush"
			elif roll < 0.031:
				item_id = "tree"
			elif roll < 0.035:
				item_id = "stump"

			if not item_id.is_empty():
				_add_object(cell, item_id, terrain, objects)


# ==================================================
# ДОБАВЛЕНИЕ ОБЪЕКТОВ
# ==================================================

func _add_object(
	anchor: Vector2i,
	item_id: String,
	terrain: Dictionary,
	objects: Dictionary
) -> void:
	var data := _item_data(item_id)

	if data.is_empty():
		return

	var source_id: int = id_storage.get_world_source_id(item_id)

	if source_id < 0:
		return

	var size_tiles := int(data.get("size_tiles", 1))
	var cells: Array[Vector2i] = []

	# Проверяем всю площадь объекта.
	for x in range(size_tiles):
		for y in range(size_tiles):
			var cell := anchor + Vector2i(x, y)

			if not terrain.has(cell):
				return

			var surface: String = terrain[cell]["type"]

			if surface == "water":
				return

			if surface == "sand" and item_id != "stone":
				return

			if objects.has(cell):
				return

			cells.append(cell)

	# Размещаем объект.
	objects[anchor] = {
		"type": item_id,
		"source_id": source_id,
		"atlas": _random_tile(item_id),
		"cells": cells,
		"collision_enabled": bool(data.get("collision_enabled", false)),
		"size_tiles": size_tiles
	}
