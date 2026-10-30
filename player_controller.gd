
extends Node

const INVALID_CELL := Vector2i(2147483647, 2147483647)

@export var zoom_step: float = 0.3
@export var min_zoom: float = 1.0
@export var max_zoom: float = 5.0
@export var harvest_interval: float = 0.1

@onready var player: CharacterBody2D = get_parent()
@onready var camera: Camera2D = player.get_node("Camera2D")

var inventory_ui: CanvasLayer
var world: Node2D
var is_harvesting: bool = false
var harvest_timer: float = 0.0

var current_target: Vector2i = INVALID_CELL
var current_health: int = 0
var current_max_health: int = 0
var pending_reward: Dictionary = {}

func _ready() -> void:
	camera.make_current()
	camera.position = Vector2.ZERO
	camera.offset = Vector2.ZERO
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0

	inventory_ui = get_tree().root.get_node_or_null("Main/InventoryUI")
	world = get_tree().root.get_node_or_null("Main/World")

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	player.call("set_move_direction", direction)

	# Закрываем сундук, если игрок отошёл дальше пяти тайлов.
	if inventory_ui != null and world != null:
		if inventory_ui.call("is_chest_open"):
			if world.call(
				"is_too_far_from_open_chest",
				player.global_position
			):
				world.call("_close_chest_visual")
				inventory_ui.call("close_chest")

	# Повторяем удары, пока ПКМ зажата.
	if is_harvesting:
		harvest_timer += delta

		if harvest_timer >= harvest_interval:
			harvest_timer = 0.0
			_handle_right_click()
			
			
func _input(event: InputEvent) -> void:
	# Включаем и выключаем режим добычи.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_harvesting = true
				harvest_timer = 0.0
				_handle_right_click()
			else:
				reset_harvesting()

			return

	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.event_is_action(event, "inventory"):
			if inventory_ui != null:
				if inventory_ui.call("is_chest_open"):
					if world != null:
						world.call("_close_chest_visual")
					inventory_ui.call("close_chest")
				else:
					inventory_ui.call("toggle_inventory")
			return

		if InputMap.event_is_action(event, "clear_hand"):
			if inventory_ui != null:
				inventory_ui.call("clear_hand")
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (
				camera.zoom + Vector2.ONE * zoom_step
			).clamp(
				Vector2.ONE * min_zoom,
				Vector2.ONE * max_zoom
			)
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (
				camera.zoom - Vector2.ONE * zoom_step
			).clamp(
				Vector2.ONE * min_zoom,
				Vector2.ONE * max_zoom
			)
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click()
			return


func _handle_left_click() -> void:
	if inventory_ui == null or world == null:
		return

	if _is_hovering_inventory_ui():
		return

	var mouse_position := player.get_global_mouse_position()

	# Сначала проверяем, не находится ли курсор над сундуком.
	var chest_anchor: Vector2i = world.call(
		"get_chest_at",
		mouse_position,
		player.global_position
	)

	if chest_anchor != INVALID_CELL:
		if inventory_ui.call("is_chest_open"):
			world.call("_close_chest_visual")
			inventory_ui.call("close_chest")
			return

		var storage: Array = world.call("toggle_chest", chest_anchor)

		if not storage.is_empty():
			inventory_ui.call("open_chest", storage)
		return

	# Если предмет находится в руке, пытаемся его установить.
	if inventory_ui.call("has_held_item"):
		var item_id: String = inventory_ui.call("get_selected_item")

		if item_id.is_empty():
			return

		var placed: bool = world.call(
			"place_item",
			mouse_position,
			item_id,
			player.global_position
		)

		if placed:
			var consumed: bool = inventory_ui.call(
				"consume_held_item",
				1
			)

			if not consumed:
				push_error("Предмет установлен, но не удалось списать его из руки.")


func _handle_right_click() -> void:
	if inventory_ui == null or world == null:
		_reset_harvest_progress()
		return

	if _is_hovering_inventory_ui():
		_reset_harvest_progress()
		return

	if inventory_ui.call("has_held_item"):
		_reset_harvest_progress()
		return

	var mouse_position := player.get_global_mouse_position()

	# Не позволяем добывать сундук.
	var chest_anchor: Vector2i = world.call(
		"get_chest_at",
		mouse_position,
		player.global_position
	)

	if chest_anchor != INVALID_CELL:
		_reset_harvest_progress()
		return

	# Получаем ячейку под курсором.
	var ground: TileMapLayer = world.get("ground")

	var cell: Vector2i = ground.local_to_map(
		ground.to_local(mouse_position)
	)

	# Проверяем, есть ли в этой ячейке объект.
	var occupied: Dictionary = world.get("occupied_cells")

	var anchor: Vector2i = occupied.get(
		cell,
		INVALID_CELL
	)

	if anchor == INVALID_CELL:
		_reset_harvest_progress()
		return

	# Получаем информацию об объекте.
	var objects: Dictionary = world.get("objects")
	var object_data: Dictionary = objects.get(anchor, {})
	var object_type := str(object_data.get("type", ""))

	if object_type.is_empty():
		_reset_harvest_progress()
		return

	var storage: Node = world.get("id_storage")
	var item_data: Dictionary = storage.call(
		"get_item",
		object_type
	)

	# Если курсор перешёл на другой объект,
	# начинаем его добычу с полного здоровья.
	if anchor != current_target:
		current_target = anchor
		pending_reward.clear()

		current_max_health = int(item_data.get("health", 0))
		current_health = current_max_health

	if current_max_health <= 0:
		_reset_harvest_progress()
		return

	# Наносим удар.
	var result: Dictionary = world.call(
		"damage_object",
		mouse_position,
		player.global_position,
		current_health
	)

	if result.is_empty():
		_reset_harvest_progress()
		return

	current_health = int(
		result.get("health", current_health)
	)

	# Показываем прогресс добычи.
	inventory_ui.call(
		"show_harvest_progress",
		str(storage.call("get_item_name", object_type)),
		current_health,
		current_max_health
	)

	var reward: Dictionary = result.get("reward", {})

	# Объект ещё не разрушен.
	if reward.is_empty():
		return

	pending_reward = reward

	var amount := int(reward.get("amount", 0))
	var collected_id := str(reward.get("item_id", ""))

	if amount <= 0 or collected_id.is_empty():
		return

	# Проверяем, можно ли поместить награду в инвентарь.
	var accepted: bool = inventory_ui.call(
		"try_accept_reward",
		collected_id,
		amount
	)

	if not accepted:
		print("Инвентарь заполнен. Объект не собран.")
		_reset_harvest_progress()
		return

	# Удаляем разрушенный объект из мира.
	var committed: bool = world.call(
		"commit_harvest",
		reward
	)

	if not committed:
		push_error("Не удалось удалить собранный объект.")

	# Важно: не выключаем режим добычи!
	# ПКМ остаётся зажатой, следующий объект можно ломать сразу.
	_reset_harvest_progress()
	
	
func _is_hovering_inventory_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()

	return (
		hovered != null
		and inventory_ui != null
		and inventory_ui.is_ancestor_of(hovered)
	)


func _reset_harvest_progress() -> void:
	current_target = INVALID_CELL
	current_health = 0
	current_max_health = 0
	pending_reward.clear()

	if inventory_ui != null:
		inventory_ui.call("hide_harvest_progress")


func reset_camera_zoom() -> void:
	camera.zoom = Vector2.ONE
	camera.position = Vector2.ZERO
	camera.offset = Vector2.ZERO

func reset_harvesting() -> void:
	is_harvesting = false
	harvest_timer = 0.0

	_reset_harvest_progress()
