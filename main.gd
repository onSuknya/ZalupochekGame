
extends Node2D

@onready var world: Node2D = $World
@onready var main_menu: Control = $MenuLayer/MainMenu
@onready var inventory_ui: CanvasLayer = $InventoryUI
@onready var player: CharacterBody2D = $World/Player


func _ready() -> void:
	add_to_group("main")

	main_menu.world_requested.connect(_start_world)

	EventBus.return_to_menu_requested.connect(return_to_menu)

	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.hide()
	inventory_ui.hide()
	main_menu.show()



func _start_world() -> void:
	# Сначала полностью сбрасываем состояние.
	inventory_ui.call("reset_inventory")
	#добавляем тестовые предметы.
	inventory_ui.call("add_item", "Древесина", 20)
	inventory_ui.call("add_item", "Забор", 30)
	inventory_ui.call("add_item", "Камень", 10)
	inventory_ui.call("add_item", "Сундук", 5)
	var storage := get_node_or_null("ResourceStorage")
	if storage != null and storage.has_method("reset_storage"):
		storage.call("reset_storage")

	# Включаем мир и генерируем его заново.
	world.show()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.generate_world()

	# Возвращаем игрока в начало и сбрасываем масштаб камеры.
	var player := world.get_node_or_null("Player")
	if player != null:
		player.global_position = Vector2.ZERO
		if player.has_method("reset_camera_zoom"):
			player.call("reset_camera_zoom")

	# Меню скрываем; инвентарь появляется пустым.
	$MenuLayer/MainMenu.hide()


func return_to_menu() -> void:
	# Закрываем интерфейс и очищаем инвентарь.
	inventory_ui.call("reset_inventory")

	var storage := get_node_or_null("ResourceStorage")
	if storage != null and storage.has_method("reset_storage"):
		storage.call("reset_storage")

	# Отключаем мир до следующего запуска.
	world.hide()
	world.process_mode = Node.PROCESS_MODE_DISABLED

	var player := world.get_node_or_null("Player")
	if player != null and player.has_method("reset_camera_zoom"):
		player.call("reset_camera_zoom")

	$MenuLayer/MainMenu.show()
