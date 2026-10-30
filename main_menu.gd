
extends Control

signal world_requested

var main_box: VBoxContainer
var settings_box: VBoxContainer
var bindings_box: VBoxContainer
var capture_panel: PanelContainer
var capture_label: Label

var pending_action: String = ""
var binding_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_build_settings()
	_build_capture_panel()
	_show_main_menu()


func _make_button(
	parent: Control,
	button_text: String,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(300, 42)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_menu() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.06, 0.08, 0.07, 0.96)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	main_box = VBoxContainer.new()
	main_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_box.position = Vector2(-160, -140)
	main_box.custom_minimum_size = Vector2(320, 280)
	main_box.add_theme_constant_override("separation", 12)
	add_child(main_box)

	var title := Label.new()
	title.text = "МОЯ ИГРА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	main_box.add_child(title)

	_make_button(main_box, "Создать мир", _on_create_world_pressed)
	_make_button(main_box, "Настройки", _show_settings)
	_make_button(main_box, "Выход", _on_exit_pressed)


func _build_settings() -> void:
	settings_box = VBoxContainer.new()
	settings_box.set_anchors_preset(Control.PRESET_CENTER)
	settings_box.position = Vector2(-220, -260)
	settings_box.custom_minimum_size = Vector2(440, 520)
	settings_box.add_theme_constant_override("separation", 8)
	add_child(settings_box)

	var title := Label.new()
	title.text = "НАСТРОЙКИ УПРАВЛЕНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	settings_box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_box.add_child(scroll)

	bindings_box = VBoxContainer.new()
	bindings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bindings_box.add_theme_constant_override("separation", 6)
	scroll.add_child(bindings_box)

	var actions: Array[String] = [
		"move_up",
		"move_left",
		"move_down",
		"move_right",
		"break_block",
		"inventory",
		"clear_hand",
		"chest"
	]

	for action in actions:
		var row := HBoxContainer.new()
		bindings_box.add_child(row)

		var label := Label.new()
		label.text = InputSettings.ACTION_NAMES[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(115, 36)
		button.pressed.connect(_start_capture.bind(action))
		row.add_child(button)

		binding_buttons[action] = button

	_make_button(
		settings_box,
		"Настройки по умолчанию",
		_reset_bindings
	)
	_make_button(settings_box, "Назад", _show_main_menu)

	settings_box.hide()


func _build_capture_panel() -> void:
	capture_panel = PanelContainer.new()
	capture_panel.set_anchors_preset(Control.PRESET_CENTER)
	capture_panel.position = Vector2(-170, -55)
	capture_panel.custom_minimum_size = Vector2(340, 110)
	add_child(capture_panel)

	var box := VBoxContainer.new()
	capture_panel.add_child(box)

	capture_label = Label.new()
	capture_label.text = "Нажмите новую клавишу"
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(capture_label)

	_make_button(box, "Отмена", _cancel_capture)
	capture_panel.hide()


func _show_main_menu() -> void:
	pending_action = ""
	capture_panel.hide()
	settings_box.hide()
	main_box.show()


func _show_settings() -> void:
	main_box.hide()
	settings_box.show()
	_refresh_binding_buttons()


func _refresh_binding_buttons() -> void:
	for action in binding_buttons:
		var button: Button = binding_buttons[action]
		button.text = InputSettings.get_binding_text(action)


func _start_capture(action: String) -> void:
	pending_action = action
	capture_label.text = (
		"Назначение: " + InputSettings.ACTION_NAMES[action]
		+ "\nНажмите новую клавишу"
	)
	capture_panel.show()


func _cancel_capture() -> void:
	pending_action = ""
	capture_panel.hide()


func _input(event: InputEvent) -> void:
	if pending_action.is_empty():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return

		InputSettings.set_binding(pending_action, event)
		_cancel_capture()
		_refresh_binding_buttons()
		get_viewport().set_input_as_handled()


func _reset_bindings() -> void:
	InputSettings.reset_to_defaults()
	_refresh_binding_buttons()


func _on_create_world_pressed() -> void:
	world_requested.emit()


func _on_exit_pressed() -> void:
	get_tree().quit()
