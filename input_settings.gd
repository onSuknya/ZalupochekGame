
extends Node

const CONFIG_PATH := "user://input_settings.cfg"

const DEFAULT_BINDINGS := {
	"move_up": KEY_W,
	"move_left": KEY_A,
	"move_down": KEY_S,
	"move_right": KEY_D,
	"inventory": KEY_E,
	"clear_hand": KEY_Q,
	"chest": KEY_F
}

const ACTION_NAMES := {
	"move_up": "Движение вверх",
	"move_left": "Движение влево",
	"move_down": "Движение вниз",
	"move_right": "Движение вправо",
	"inventory": "Инвентарь",
	"clear_hand": "Убрать предмет из руки",
	"chest": "Открыть / закрыть сундук",
	"break_block": "Ломать / собирать"
}


func _ready() -> void:
	_setup_actions()
	load_bindings()


func _setup_actions() -> void:
	for action in ACTION_NAMES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	for action in DEFAULT_BINDINGS:
		_set_key(action, DEFAULT_BINDINGS[action])

	# По умолчанию ломание и сбор — левой кнопкой мыши.
	InputMap.action_erase_events("break_block")
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("break_block", mouse_event)


func _set_key(action: String, key: int) -> void:
	InputMap.action_erase_events(action)

	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func set_binding(action: String, event: InputEventKey) -> void:
	if not ACTION_NAMES.has(action):
		return

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_bindings()


func get_binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action)

	if events.is_empty():
		return "Не назначено"

	return events[0].as_text()


func save_bindings() -> void:
	var config := ConfigFile.new()

	for action in ACTION_NAMES:
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue

		var event: InputEvent = events[0]
		if event is InputEventKey:
			config.set_value("bindings", action, event.physical_keycode)

		elif event is InputEventMouseButton:
			config.set_value("bindings", action, "mouse_left")

	config.save(CONFIG_PATH)


func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	for action in ACTION_NAMES:
		if not config.has_section_key("bindings", action):
			continue

		var value = config.get_value("bindings", action)

		if value is int:
			_set_key(action, value)
		elif value == "mouse_left":
			InputMap.action_erase_events(action)
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event(action, event)


func reset_to_defaults() -> void:
	_setup_actions()
	save_bindings()
