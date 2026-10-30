
extends CanvasLayer

const SLOT_COUNT := 8
const MAX_STACK := 20
const SLOT_SIZE := Vector2(78, 54)
const TILE_SIZE := 16

var inventory_open := false
var slots: Array[Dictionary] = []
var slot_buttons: Array[Button] = []

# Все предметы хранятся по ID из IDStorage.
var selected_item := ""
var hand_item := ""
var hand_amount := 0

var root_control: Control
var panel: PanelContainer
var craft_panel: PanelContainer
var chest_panel: PanelContainer
var header: PanelContainer
var selected_label: Label
var hand_label: Label
var hand_icon: TextureRect
var craft_button: Button
var chest_craft_button: Button
var fence_craft_button: Button
var menu_button: Button
var chest_slot_buttons: Array[Button] = []
var harvest_panel: PanelContainer
var harvest_bar: ProgressBar
var harvest_label: Label

var chest_storage: Array = []
var chest_open := false

var dragging := false
var drag_offset := Vector2.ZERO

var id_storage: Node


func _ready() -> void:
	show()

	add_to_group("inventory_ui")

	id_storage = get_tree().root.get_node_or_null("Main/IDStorage")

	for i in range(SLOT_COUNT):
		slots.append({"item": "", "count": 0})

	_build_interface()
	_refresh_slots()
	_update_selected_label()

	panel.hide()
	craft_panel.hide()
	chest_panel.hide()
	harvest_panel.hide()

	if not EventBus.inventory_resource_ready.is_connected(_on_inventory_resource_ready):
		EventBus.inventory_resource_ready.connect(_on_inventory_resource_ready)

# --------------------------------------------------
# ID И ИКОНКИ
# --------------------------------------------------

# Поддерживает старые сигналы, передающие русское название,
# но внутри инвентаря всегда использует ID.
func _resolve_item_id(value: String) -> String:
	if value.is_empty():
		return ""

	if id_storage == null:
		return value

	var data: Dictionary = id_storage.call("get_item", value)
	if not data.is_empty():
		return value

	return str(id_storage.call("get_item_id_by_name", value))


func _get_item_icon(item_id: String) -> Texture2D:
	if id_storage == null or item_id.is_empty():
		return null

	var data: Dictionary = id_storage.call("get_item", item_id)
	if data.is_empty():
		return null

	var atlas: Texture2D = null
	var tile := Vector2i.ZERO
	var atlas_name := str(data.get("icon_atlas", ""))

	# Если у предмета задан отдельный тайл и атлас иконок.
	if data.has("icon_tile"):
		tile = data["icon_tile"]

		match atlas_name:
			"furniture":
				atlas = id_storage.get("furniture_texture")
			"objects":
				atlas = id_storage.get("objects_texture")
			_:
				atlas = id_storage.get("item_icons_texture")

	# Для объектов без отдельной иконки берём первый тайл мира.
	elif data.has("tiles") and not data["tiles"].is_empty():
		tile = data["tiles"][0]
		atlas = id_storage.get("objects_texture")

	# Для объектов мебели используем их варианты.
	elif data.has("variants") and not data["variants"].is_empty():
		tile = data["variants"][0]
		atlas = id_storage.get("furniture_texture")

	if atlas == null:
		return null

	var icon := AtlasTexture.new()
	icon.atlas = atlas
	icon.region = Rect2(
		Vector2(tile * TILE_SIZE),
		Vector2(TILE_SIZE, TILE_SIZE)
	)

	return icon


func _configure_item_button(
	button: Button,
	item_id: String,
	count: int
) -> void:
	button.text = str(count) if count > 0 else "Пусто"
	button.icon = _get_item_icon(item_id) if count > 0 else null
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER


# --------------------------------------------------
# СОЗДАНИЕ ИНТЕРФЕЙСА
# --------------------------------------------------

func _build_interface() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Иконка предмета, который сейчас находится в руке.
	hand_icon = TextureRect.new()
	hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_icon.custom_minimum_size = Vector2(32, 32)
	hand_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand_icon.hide()
	root_control.add_child(hand_icon)

	hand_label = Label.new()
	hand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_label.add_theme_color_override("font_color", Color.WHITE)
	hand_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hand_label.add_theme_constant_override("shadow_offset_x", 1)
	hand_label.add_theme_constant_override("shadow_offset_y", 1)
	hand_label.hide()
	root_control.add_child(hand_label)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(panel)

	var layout := VBoxContainer.new()
	panel.add_child(layout)

	header = PanelContainer.new()
	header.custom_minimum_size = Vector2(340, 36)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	layout.add_child(header)
	header.gui_input.connect(_on_header_input)

	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	selected_label = Label.new()
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(selected_label)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(grid)

	for i in range(SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.text = "Пусто"
		button.focus_mode = Control.FOCUS_NONE
		button.gui_input.connect(_on_inventory_slot_gui_input.bind(i))
		grid.add_child(button)
		slot_buttons.append(button)

	menu_button = Button.new()
	menu_button.text = "В меню"
	menu_button.custom_minimum_size = Vector2(120, 32)
	menu_button.pressed.connect(_return_to_menu)
	layout.add_child(menu_button)

	# Панель крафта.
	craft_panel = PanelContainer.new()
	craft_panel.custom_minimum_size = Vector2(440, 160)
	craft_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(craft_panel)

	var craft_layout := VBoxContainer.new()
	craft_panel.add_child(craft_layout)

	var craft_title := Label.new()
	craft_title.text = "КРАФТ"
	craft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_layout.add_child(craft_title)

	craft_button = Button.new()
	craft_button.text = "Создать Мега-камень (5 камней)"
	craft_button.pressed.connect(_craft_mega_stone)
	craft_layout.add_child(craft_button)

	chest_craft_button = Button.new()
	chest_craft_button.text = "Создать сундук (5 дерева)"
	chest_craft_button.pressed.connect(_craft_chest)
	craft_layout.add_child(chest_craft_button)

	fence_craft_button = Button.new()
	fence_craft_button.text = "Создать забор (2 дерева)"
	fence_craft_button.pressed.connect(craft_fence)
	craft_layout.add_child(fence_craft_button)

	# Панель сундука.
	chest_panel = PanelContainer.new()
	chest_panel.custom_minimum_size = Vector2(360, 180)
	chest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(chest_panel)

	var chest_layout := VBoxContainer.new()
	chest_panel.add_child(chest_layout)

	var chest_title := Label.new()
	chest_title.text = "СУНДУК — ЛКМ: стак, ПКМ: 1 предмет"
	chest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_layout.add_child(chest_title)

	var chest_grid := GridContainer.new()
	chest_grid.columns = 2
	chest_grid.add_theme_constant_override("h_separation", 6)
	chest_grid.add_theme_constant_override("v_separation", 6)
	chest_layout.add_child(chest_grid)

	for i in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(145, 48)
		button.text = "Пусто"
		button.focus_mode = Control.FOCUS_NONE
		button.gui_input.connect(_on_chest_slot_gui_input.bind(i))
		chest_grid.add_child(button)
		chest_slot_buttons.append(button)

	_position_windows()
		# Полоска прочности объекта внизу экрана.
	harvest_panel = PanelContainer.new()
	harvest_panel.custom_minimum_size = Vector2(300, 48)
	harvest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(harvest_panel)

	var harvest_layout := VBoxContainer.new()
	harvest_panel.add_child(harvest_layout)

	harvest_label = Label.new()
	harvest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	harvest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	harvest_layout.add_child(harvest_label)

	harvest_bar = ProgressBar.new()
	harvest_bar.min_value = 0
	harvest_bar.max_value = 100
	harvest_bar.value = 100
	harvest_bar.show_percentage = false
	harvest_bar.custom_minimum_size = Vector2(280, 12)
	harvest_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	harvest_layout.add_child(harvest_bar)

	harvest_panel.hide()

func _process(_delta: float) -> void:
	if not has_held_item():
		hand_icon.hide()
		hand_label.hide()
		return

	var mouse_position := get_viewport().get_mouse_position()

	hand_icon.texture = _get_item_icon(hand_item)
	hand_icon.position = mouse_position + Vector2(18, 18)
	hand_icon.show()

	hand_label.text = "x%d" % hand_amount
	hand_label.position = mouse_position + Vector2(18, 50)
	hand_label.show()


func _position_windows() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	if chest_open:
		var total_width := 380.0 + 12.0 + 360.0
		var start_x := (viewport_size.x - total_width) / 2.0
		var start_y := (viewport_size.y - 360.0) / 2.0 - 35.0

		panel.position = Vector2(start_x, start_y)
		chest_panel.position = Vector2(start_x + 392.0, start_y + 80.0)
	else:
		panel.position = Vector2(
			(viewport_size.x - 380.0) / 2.0,
			(viewport_size.y - 360.0) / 2.0 - 45.0
		)

		chest_panel.position = Vector2(
			(viewport_size.x - 360.0) / 2.0,
			(viewport_size.y - 180.0) / 2.0
		)

	craft_panel.position = Vector2(
		(viewport_size.x - 440.0) / 2.0,
		viewport_size.y - 180.0
	)


# --------------------------------------------------
# РУКА И РЕСУРСЫ
# --------------------------------------------------

func _on_inventory_resource_ready(item_name: String, amount: int) -> void:
	var item_id := _resolve_item_id(item_name)

	if item_id.is_empty() or amount <= 0:
		return

	if add_item(item_id, amount):
		print("Подобрано: ", item_id, " x", amount)
	elif not has_held_item():
		hand_item = item_id
		hand_amount = amount
		_update_selected_label()
	else:
		push_error("Инвентарь и рука заполнены.")


func has_held_item() -> bool:
	return not hand_item.is_empty() and hand_amount > 0


# Сохраняет имя старого метода, но теперь возвращает ID.
func get_selected_item() -> String:
	if has_held_item():
		return hand_item
	return ""


func get_held_item_id() -> String:
	return get_selected_item()


func consume_held_item(amount: int = 1) -> bool:
	if not has_held_item() or amount <= 0 or hand_amount < amount:
		return false

	var item_id := hand_item
	hand_amount -= amount

	if hand_amount <= 0:
		hand_amount = 0
		hand_item = ""
		_refill_hand_from_smallest_stack(item_id)

	_update_selected_label()
	return true


func _refill_hand_from_smallest_stack(item_id: String) -> void:
	var smallest_index := -1
	var smallest_count := MAX_STACK + 1

	for i in range(SLOT_COUNT):
		if slots[i]["item"] != item_id:
			continue

		var count := int(slots[i]["count"])

		if count > 0 and count < smallest_count:
			smallest_count = count
			smallest_index = i

	if smallest_index == -1:
		return

	hand_item = item_id
	hand_amount = smallest_count

	slots[smallest_index]["item"] = ""
	slots[smallest_index]["count"] = 0

	_refresh_slots()


func get_total_item_count(item_id: String) -> int:
	item_id = _resolve_item_id(item_id)
	var total := 0

	for slot in slots:
		if slot["item"] == item_id:
			total += int(slot["count"])

	if hand_item == item_id:
		total += hand_amount

	return total


func clear_hand() -> void:
	if not has_held_item():
		selected_item = ""
		_update_selected_label()
		return

	var item_id := hand_item
	var amount := hand_amount

	if not add_item(item_id, amount):
		print("Недостаточно места, предмет остался в руке.")
		return

	hand_item = ""
	hand_amount = 0
	selected_item = ""

	_update_selected_label()
	_refresh_slots()


# Проверяет, можно ли целиком принять награду.
func can_accept_reward(item_id: String, amount: int) -> bool:
	item_id = _resolve_item_id(item_id)

	if item_id.is_empty() or amount <= 0:
		return false

	if can_add_item(item_id, amount):
		return true

	return not has_held_item()


func try_accept_reward(item_id: String, amount: int) -> bool:
	item_id = _resolve_item_id(item_id)

	if not can_accept_reward(item_id, amount):
		return false

	if can_add_item(item_id, amount):
		return add_item(item_id, amount)

	hand_item = item_id
	hand_amount = amount
	_update_selected_label()
	return true


# Возвращает предмет, если World отказался его разместить.
func return_placed_item(item_id: String, amount: int = 1) -> bool:
	item_id = _resolve_item_id(item_id)

	if item_id.is_empty() or amount <= 0:
		return false

	if not has_held_item():
		hand_item = item_id
		hand_amount = amount
		_update_selected_label()
		return true

	if hand_item == item_id:
		hand_amount += amount
		_update_selected_label()
		return true

	return add_item(item_id, amount)


# --------------------------------------------------
# ОТКРЫТИЕ ИНВЕНТАРЯ
# --------------------------------------------------

func toggle_inventory() -> void:
	inventory_open = not inventory_open
	show()

	panel.visible = inventory_open
	craft_panel.visible = inventory_open

	if not chest_open:
		chest_panel.hide()

	if inventory_open:
		_position_windows()
		_refresh_slots()
		_update_selected_label()


func is_inventory_open() -> bool:
	return inventory_open


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse_event.pressed

			if dragging:
				drag_offset = get_viewport().get_mouse_position() - panel.position

			header.accept_event()

	elif event is InputEventMouseMotion and dragging:
		panel.position = get_viewport().get_mouse_position() - drag_offset
		header.accept_event()


# --------------------------------------------------
# ПЕРЕМЕЩЕНИЕ ПРЕДМЕТОВ
# --------------------------------------------------

func _on_inventory_slot_gui_input(event: InputEvent, index: int) -> void:
	_handle_slot_input(event, index, false)


func _on_chest_slot_gui_input(event: InputEvent, index: int) -> void:
	if not chest_open:
		return

	_handle_slot_input(event, index, true)


func _handle_slot_input(event: InputEvent, index: int, is_chest: bool) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton

	if not mouse_event.pressed:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT \
	and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	if is_chest and chest_storage.size() != 4:
		return

	var one_item: bool = mouse_event.button_index == MOUSE_BUTTON_RIGHT
	var slot: Dictionary

	if is_chest:
		slot = chest_storage[index]
	else:
		slot = slots[index]

	var slot_item: String = str(slot["item"])
	var slot_count: int = int(slot["count"])

	# Забираем предмет из слота в руку.
	if not has_held_item():
		if slot_count <= 0 or slot_item.is_empty():
			return

		var amount_to_take: int = 1 if one_item else slot_count

		hand_item = slot_item
		hand_amount = amount_to_take

		slot["count"] = slot_count - amount_to_take

		if int(slot["count"]) <= 0:
			slot["item"] = ""
			slot["count"] = 0

	# Кладём предмет из руки в слот.
	else:
		if slot_count == 0 or slot_item == hand_item:
			var amount_to_move: int = 1 if one_item else hand_amount
			var free_space: int = MAX_STACK - slot_count

			if free_space <= 0:
				return

			amount_to_move = mini(amount_to_move, free_space)

			if slot_count == 0:
				slot["item"] = hand_item

			slot["count"] = slot_count + amount_to_move
			hand_amount -= amount_to_move

			if hand_amount <= 0:
				hand_amount = 0
				hand_item = ""

		# ЛКМ по другому предмету меняет стаки местами.
		elif not one_item:
			var old_item: String = slot_item
			var old_count: int = slot_count

			slot["item"] = hand_item
			slot["count"] = hand_amount

			hand_item = old_item
			hand_amount = old_count
		else:
			return

	if is_chest:
		chest_storage[index] = slot
		_refresh_chest_slots()
	else:
		slots[index] = slot

	_refresh_slots()
	_update_selected_label()
	get_viewport().set_input_as_handled()


# --------------------------------------------------
# ХРАНЕНИЕ ПРЕДМЕТОВ
# --------------------------------------------------

func can_add_item(item_id: String, amount: int = 1) -> bool:
	item_id = _resolve_item_id(item_id)

	if item_id.is_empty() or amount <= 0:
		return false

	var capacity := 0

	for slot in slots:
		if slot["item"] == item_id:
			capacity += MAX_STACK - int(slot["count"])
		elif int(slot["count"]) == 0:
			capacity += MAX_STACK

	return capacity >= amount


func add_item(item_id: String, amount: int = 1) -> bool:
	item_id = _resolve_item_id(item_id)

	if not can_add_item(item_id, amount):
		return false

	var remaining := amount

	# Сначала заполняем существующие стаки.
	for i in range(SLOT_COUNT):
		if slots[i]["item"] != item_id:
			continue

		var available: int = MAX_STACK - int(slots[i]["count"])
		var added: int = mini(available, remaining)

		slots[i]["count"] = int(slots[i]["count"]) + added
		remaining -= added

		if remaining == 0:
			_refresh_slots()
			return true

	# Затем используем пустые слоты.
	for i in range(SLOT_COUNT):
		if int(slots[i]["count"]) != 0:
			continue

		var added: int = mini(MAX_STACK, remaining)
		slots[i]["item"] = item_id
		slots[i]["count"] = added
		remaining -= added

		if remaining == 0:
			_refresh_slots()
			return true

	_refresh_slots()
	return false


func remove_item(item_id: String, amount: int = 1) -> bool:
	item_id = _resolve_item_id(item_id)

	if amount <= 0:
		return true

	var available := 0

	for slot in slots:
		if slot["item"] == item_id:
			available += int(slot["count"])

	if available < amount:
		return false

	var remaining := amount

	for i in range(SLOT_COUNT):
		if slots[i]["item"] != item_id:
			continue

		var removed: int = mini(int(slots[i]["count"]), remaining)
		slots[i]["count"] = int(slots[i]["count"]) - removed
		remaining -= removed

		if int(slots[i]["count"]) <= 0:
			slots[i]["count"] = 0
			slots[i]["item"] = ""

		if remaining == 0:
			break

	if selected_item == item_id and not _has_item(item_id):
		selected_item = ""

	_refresh_slots()
	_update_selected_label()
	return true


func _has_item(item_id: String) -> bool:
	for slot in slots:
		if slot["item"] == item_id and int(slot["count"]) > 0:
			return true

	return false


# --------------------------------------------------
# КРАФТ
# --------------------------------------------------

func craft_fence() -> void:
	if has_held_item():
		print("Сначала положи предмет из руки в инвентарь.")
		return

	if get_total_item_count("wood") < 2:
		print("Для крафта забора нужно 2 древесины.")
		return

	if not can_add_item("fence", 1):
		print("Нет места для забора.")
		return

	if remove_item("wood", 2):
		add_item("fence", 1)
		print("Создан забор!")


func _craft_mega_stone() -> void:
	if has_held_item():
		print("Сначала положи предмет из руки в инвентарь.")
		return

	if get_total_item_count("stone") < 5:
		print("Для крафта нужно 5 камней.")
		return

	if not can_add_item("mega_stone", 1):
		print("Нет места для мега-камня.")
		return

	if remove_item("stone", 5):
		add_item("mega_stone", 1)
		print("Создан Мега-камень!")


func _craft_chest() -> void:
	if has_held_item():
		print("Сначала положи предмет из руки в инвентарь.")
		return

	if get_total_item_count("wood") < 5:
		print("Для крафта сундука нужно 5 древесины.")
		return

	if not can_add_item("chest", 1):
		print("Нет места для сундука.")
		return

	if remove_item("wood", 5):
		add_item("chest", 1)
		print("Создан сундук!")


# --------------------------------------------------
# СУНДУК
# --------------------------------------------------

func open_chest(storage: Array) -> void:
	chest_storage = storage
	chest_open = true
	inventory_open = true

	show()
	panel.show()
	craft_panel.show()
	chest_panel.show()

	_position_windows()
	_refresh_slots()
	_refresh_chest_slots()
	_update_selected_label()


func close_chest() -> void:
	chest_open = false
	chest_panel.hide()
	chest_storage = []

	inventory_open = false
	panel.hide()
	craft_panel.hide()


func is_chest_open() -> bool:
	return chest_open


func _refresh_chest_slots() -> void:
	if chest_storage.size() != 4:
		return

	for i in range(4):
		var item_id: String = str(chest_storage[i]["item"])
		var count: int = int(chest_storage[i]["count"])

		_configure_item_button(chest_slot_buttons[i], item_id, count)


# --------------------------------------------------
# ОБНОВЛЕНИЕ ИНТЕРФЕЙСА
# --------------------------------------------------

func _update_selected_label() -> void:
	if not is_instance_valid(selected_label):
		return

	if has_held_item():
		selected_label.text = "В руке: x%d" % hand_amount
	else:
		selected_label.text = "Рука пуста — выбери слот"


func _refresh_slots() -> void:
	for i in range(SLOT_COUNT):
		var item_id: String = str(slots[i]["item"])
		var count: int = int(slots[i]["count"])

		_configure_item_button(slot_buttons[i], item_id, count)

		slot_buttons[i].modulate = (
			Color(1.0, 0.85, 0.5)
			if item_id == selected_item and count > 0
			else Color.WHITE
		)


func _return_to_menu() -> void:
	var main := get_tree().get_first_node_in_group("main")

	if main == null:
		main = get_tree().root.get_node_or_null("Main")

	if main != null and main.has_method("return_to_menu"):
		main.return_to_menu()
	else:
		push_error("Инвентарь: не удалось найти Main.return_to_menu().")


func reset_inventory() -> void:
	for i in range(SLOT_COUNT):
		slots[i] = {"item": "", "count": 0}

	selected_item = ""
	hand_item = ""
	hand_amount = 0
	chest_storage = []
	chest_open = false
	inventory_open = false

	if is_instance_valid(panel):
		panel.hide()
	if is_instance_valid(craft_panel):
		craft_panel.hide()
	if is_instance_valid(chest_panel):
		chest_panel.hide()
	if is_instance_valid(hand_icon):
		hand_icon.hide()
	if is_instance_valid(hand_label):
		hand_label.hide()

	_refresh_slots()
	_update_selected_label()


func show_harvest_progress(
	item_name: String,
	current_health: int,
	max_health: int
) -> void:
	if not is_instance_valid(harvest_panel):
		return

	if max_health <= 0:
		harvest_panel.hide()
		return

	harvest_label.text = item_name
	harvest_bar.max_value = max_health
	harvest_bar.value = current_health

	var viewport_size := get_viewport().get_visible_rect().size

	harvest_panel.position = Vector2(
		(viewport_size.x - 300.0) / 2.0,
		viewport_size.y - 100.0
	)

	harvest_panel.show()


func hide_harvest_progress() -> void:
	if is_instance_valid(harvest_panel):
		harvest_panel.hide()
