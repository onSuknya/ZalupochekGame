
extends Node2D

@export var atlas_texture: Texture2D
@export var objects_texture: Texture2D
@export var furniture_texture: Texture2D
@export var item_icons_texture: Texture2D

const TILE_SIZE := 16

@onready var ground: TileMapLayer = $Ground
@onready var resources_layer: TileMapLayer = $Resources


const ITEMS: Dictionary = {
	"grass": {
		"name": "Трава",
		"tiles": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"atlas_id": -1,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [],
		"collision_enabled": false,
		"size_tiles": 1
	},
	"sand": {
		"name": "Песок",
		"tiles": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)],
		"atlas_id": -1,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [],
		"collision_enabled": false,
		"size_tiles": 1
	},
	"dirt": {
		"name": "Земля",
		"tiles": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3)],
		"atlas_id": -1,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [],
		"collision_enabled": false,
		"size_tiles": 1
	},
	"water": {
		"name": "Вода",
		"tiles": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)],
		"atlas_id": -1,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [],
		"collision_enabled": true,
		"size_tiles": 1
	},
	"stone": {
		"name": "Камень",
		"tiles": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"atlas_id": 0,
		"icon_tile": Vector2i(2, 0),
		"icon_atlas": "items",
		"place_as": "stone",
		"drops": [{"item_id": "stone", "min": 1, "max": 1}],
		"collision_enabled": true,
		"size_tiles": 1,
		"health": 6,
		"stackable": true
	},
	"bush": {
		"name": "Куст",
		"tiles": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 2), Vector2i(1, 3)],
		"atlas_id": 0,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [{"item_id": "branch", "min": 1, "max": 3}],
		"collision_enabled": true,
		"size_tiles": 1,
		"health": 3
	},
	"tree": {
		"name": "Дерево",
		"tiles": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)],
		"atlas_id": 0,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [{"item_id": "wood", "min": 2, "max": 2}],
		"collision_enabled": true,
		"size_tiles": 1,
		"health": 6
	},
	"stump": {
		"name": "Пень",
		"tiles": [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3)],
		"atlas_id": 0,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [{"item_id": "wood", "min": 1, "max": 1}],
		"collision_enabled": true,
		"size_tiles": 1,
		"health": 3
	},
	"mega_stone": {
		"name": "Мега-камень",
		"tiles": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"atlas_id": 0,
		"icon_tile": Vector2i(6,0),
		"icon_atlas": "items",
		"place_as": "mega_stone",
		"drops": [{"item_id": "mega_stone", "min": 1, "max": 1}],
		"collision_enabled": true,
		"size_tiles": 3,
		"health": 8
	},
	"chest": {
		"name": "Сундук",
		"tiles": [],
		"variants": [Vector2i(0, 0), Vector2i(1, 0)],
		"atlas_id": 1,
		"icon_tile": Vector2i(7,0),
		"icon_atlas": "items",
		"place_as": "chest",
		"drops": [],
		"collision_enabled": true,
		"size_tiles": 1,
		"health": 3
	},
	"floor": {
		"name": "Деревянный пол",
		"tiles": [],
		"variants": [Vector2i(2, 0)],
		"atlas_id": 1,
		"icon_tile": Vector2i.ZERO,
		"icon_atlas": "",
		"place_as": "",
		"drops": [{"item_id": "wood", "min": 1, "max": 1}],
		"collision_enabled": false,
		"size_tiles": 1,
		"health": 1
	},
	"fence": {
		"name": "Забор",
		"tiles": [],
		"variants": [
			Vector2i(0, 1), Vector2i(7, 2),
			Vector2i(4, 2), Vector2i(2, 1),
			Vector2i(5, 2), Vector2i(7, 1),
			Vector2i(3, 1), Vector2i(3, 2),
			Vector2i(6, 2), Vector2i(5, 1),
			Vector2i(6, 1), Vector2i(2, 2),
			Vector2i(4, 1), Vector2i(1, 2),
			Vector2i(0, 2), Vector2i(1, 1)
		],
		"atlas_id": 1,
		"icon_tile": Vector2i(5, 0),
		"icon_atlas": "items",
		"place_as": "fence",
		"drops": [{"item_id": "fence", "min": 1, "max": 1}],
		"collision_enabled": true,
		"size_tiles": 1,
		"stackable": true,
		"health": 3
	},
	"wood": {
		"name": "Древесина",
		"tiles": [],
		"atlas_id": -1,
		"icon_tile": Vector2i(0, 0),
		"icon_atlas": "items",
		"place_as": "floor",
		"drops": [],
		"stackable": true
	},
	"branch": {
		"name": "Ветка",
		"tiles": [],
		"atlas_id": -1,
		"icon_tile": Vector2i(1, 0),
		"icon_atlas": "items",
		"place_as": "",
		"drops": [],
		"stackable": true
	},
	"knife": {
		"name": "Нож",
		"tiles": [],
		"atlas_id": -1,
		"icon_tile": Vector2i(3, 0),
		"icon_atlas": "items",
		"place_as": "",
		"drops": [],
		"stackable": false
	},
	"axe": {
		"name": "Топор",
		"tiles": [],
		"atlas_id": -1,
		"icon_tile": Vector2i(4, 0),
		"icon_atlas": "items",
		"place_as": "",
		"drops": [],
		"stackable": false
	}
}


var resources: Dictionary = {}


func _ready() -> void:
	if not EventBus.resource_collected.is_connected(_on_resource_collected):
		EventBus.resource_collected.connect(_on_resource_collected)


func setup_tilesets() -> bool:
	if atlas_texture == null:
		push_error("IDStorage: назначь атлас земли.")
		return false

	if objects_texture == null:
		push_error("IDStorage: назначь атлас объектов.")
		return false

	if furniture_texture == null:
		push_error("IDStorage: назначь атлас мебели.")
		return false

	if item_icons_texture == null:
		push_error("IDStorage: назначь атлас иконок Items.")
		return false

	_setup_tileset(ground, atlas_texture)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(_make_atlas(objects_texture), 0)
	tile_set.add_source(_make_atlas(furniture_texture), 1)

	resources_layer.tile_set = tile_set
	return true


func _make_atlas(texture: Texture2D) -> TileSetAtlasSource:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var columns := int(texture.get_width() / TILE_SIZE)
	var rows := int(texture.get_height() / TILE_SIZE)

	for x in range(columns):
		for y in range(rows):
			atlas.create_tile(Vector2i(x, y))

	return atlas


func _setup_tileset(layer: TileMapLayer, texture: Texture2D) -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()

	var atlas := _make_atlas(texture)
	tile_set.add_source(atlas, 0)

	var water_tiles: Array = ITEMS["water"].get("tiles", [])
	var half := TILE_SIZE / 2.0

	var points := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])

	for tile_coords: Vector2i in water_tiles:
		var tile_data := atlas.get_tile_data(tile_coords, 0)
		tile_data.set_collision_polygons_count(0, 1)
		tile_data.set_collision_polygon_points(0, 0, points)

	layer.tile_set = tile_set
func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


func get_tiles(item_id: String) -> Array:
	return get_item(item_id).get("tiles", [])


func get_variation_tile(item_id: String, index: int) -> Vector2i:
	var variants: Array = get_item(item_id).get("variants", [])

	if index < 0 or index >= variants.size():
		push_warning("Нет варианта '%s' с индексом %d." % [item_id, index])
		return Vector2i.ZERO

	return variants[index]


func get_item_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id))


func get_item_id_by_name(item_name: String) -> String:
	for item_id in ITEMS:
		if ITEMS[item_id].get("name", "") == item_name:
			return item_id
	return ""


func get_icon_texture(item_id: String) -> Texture2D:
	var atlas_name := str(get_item(item_id).get("icon_atlas", ""))

	match atlas_name:
		"items":
			return item_icons_texture
		"furniture":
			return furniture_texture
		"objects":
			return objects_texture

	return null


func get_icon_tile(item_id: String) -> Vector2i:
	return get_item(item_id).get("icon_tile", Vector2i.ZERO)


func get_world_source_id(item_id: String) -> int:
	var data: Dictionary = get_item(item_id)
	return int(data.get("atlas_id", -1))


func _on_resource_collected(item_name: String, amount: int) -> void:
	if item_name.is_empty() or amount <= 0:
		return

	resources[item_name] = int(resources.get(item_name, 0)) + amount
	print("Всего добыто: ", item_name, " x", resources[item_name])
	EventBus.inventory_resource_ready.emit(item_name, amount)


func get_resource_count(item_name: String) -> int:
	return int(resources.get(item_name, 0))


func reset_storage() -> void:
	resources.clear()
