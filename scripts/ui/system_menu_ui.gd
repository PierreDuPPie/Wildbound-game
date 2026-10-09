class_name SystemMenuUI
extends Control
const UI = preload("res://scripts/ui/frontier_theme.gd")

signal closed
signal resume_requested
signal save_requested
signal load_requested
signal new_game_requested
signal backpack_requested
signal quit_requested

var main_panel: Panel
var confirmation_panel: Panel
var notification_label: Label
var notification_timer: Timer
var _actions: GridContainer
var _touch_buttons: Array[Button] = []
var _quit_button: Button
var _settings_scroll: ScrollContainer
var _deadzone_slider: HSlider
var _smoothing_slider: HSlider
var _quality_picker: OptionButton

func _ready() -> void:
	scale = Vector2.ONE
	theme = UI.create_theme()
	_build_ui()
	get_viewport().size_changed.connect(_apply_layout)
	MobileControls.layout_changed.connect(_apply_layout)
	_apply_layout()
	visible = false

func open() -> void:
	_apply_layout()
	visible = true
	main_panel.visible = true
	confirmation_panel.visible = false
	notification_label.visible = false
	MobileControls.suspend_gameplay()

func close() -> void:
	visible = false
	closed.emit()
	resume_requested.emit()
	MobileControls.refresh_context()

func show_notification(text: String, is_success: bool = true) -> void:
	notification_label.text = text
	var text_color := Color("#a2e57d") if is_success else Color("#e57d7d")
	notification_label.add_theme_color_override("font_color", text_color)
	notification_label.visible = true
	if notification_timer != null:
		notification_timer.start(2.2)

func handle_back() -> bool:
	if not visible:
		return false
	if confirmation_panel.visible:
		_cancel_new_game()
	else:
		close()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			handle_back()
			get_viewport().set_input_as_handled()

func _panel(color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	return button

func _panel_contents(panel: Panel) -> VBoxContainer:
	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	margin.add_child(contents)
	return contents

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	main_panel = _panel(Color(0.08, 0.12, 0.09, 0.98), Color("#b8c795"))
	add_child(main_panel)
	var contents := _panel_contents(main_panel)
	var title := Label.new()
	title.text = "SYSTEM MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f5efdc"))
	contents.add_child(title)

	# Save feedback has a reserved line, so it never shifts the controls.
	notification_label = Label.new()
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notification_label.add_theme_font_size_override("font_size", 18)
	var notification_space := Control.new()
	notification_space.custom_minimum_size.y = 32
	contents.add_child(notification_space)
	notification_space.add_child(notification_label)
	notification_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_label.visible = false
	notification_timer = Timer.new()
	notification_timer.one_shot = true
	add_child(notification_timer)
	notification_timer.timeout.connect(func() -> void: notification_label.visible = false)

	var scroll := ScrollContainer.new()
	_settings_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contents.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_actions = GridContainer.new()
	_actions.columns = 2
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_theme_constant_override("h_separation", 12)
	_actions.add_theme_constant_override("v_separation", 12)
	body.add_child(_actions)
	_actions.add_child(_button("SAVE GAME", func() -> void: save_requested.emit()))
	_actions.add_child(_button("LOAD GAME", func() -> void: load_requested.emit()))
	_actions.add_child(_button("NEW GAME", func() -> void:
		main_panel.visible = false
		confirmation_panel.visible = true
	))
	_actions.add_child(_button("BACKPACK", func() -> void:
		close()
		backpack_requested.emit()
	))

	var touch_title := Label.new()
	touch_title.text = "TOUCH CONTROLS"
	touch_title.add_theme_font_size_override("font_size", 18)
	body.add_child(touch_title)
	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 10)
	body.add_child(touch_row)
	var modes := ["auto", "touch", "desktop"]
	var labels := ["AUTO", "ON", "OFF"]
	for i in range(modes.size()):
		var selected_mode: String = modes[i]
		var button := _button(labels[i], func() -> void: MobileControls.set_mode(selected_mode))
		button.toggle_mode = true
		touch_row.add_child(button)
		_touch_buttons.append(button)

	_deadzone_slider = _setting_slider(body, "JOYSTICK DEAD ZONE", 0.05, 0.30, 0.01, func(value: float) -> void:
		MobileControls.set_joystick_deadzone(value)
	)
	var settings := get_node_or_null("/root/MobileSettings")
	if settings != null:
		_smoothing_slider = _setting_slider(body, "CAMERA FOLLOW SPEED", 3.0, 12.0, 0.5, func(value: float) -> void:
			settings.set_follow_smoothing(value)
		)
		_smoothing_slider.tooltip_text = "Lower follows gently; higher responds faster."
		var quality_label := Label.new()
		quality_label.text = "GRAPHICS QUALITY"
		body.add_child(quality_label)
		_quality_picker = OptionButton.new()
		_quality_picker.custom_minimum_size.y = 64
		for option in ["AUTO", "LOW", "MEDIUM", "HIGH"]:
			_quality_picker.add_item(option)
		_quality_picker.item_selected.connect(func(index: int) -> void:
			settings.set_quality(["auto", "low", "medium", "high"][index])
		)
		body.add_child(_quality_picker)

	# Resume remains reachable while the body scrolls on small screens.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	contents.add_child(footer)
	footer.add_child(_button("RESUME", close))
	if not OS.has_feature("web"):
		_quit_button = _button("QUIT TO DESKTOP", func() -> void: quit_requested.emit())
		footer.add_child(_quit_button)

	confirmation_panel = _panel(Color(0.1, 0.05, 0.05, 0.98), Color("#e74c3c"))
	confirmation_panel.visible = false
	add_child(confirmation_panel)
	var confirmation := _panel_contents(confirmation_panel)
	var warning := Label.new()
	warning.text = "START NEW GAME?"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 24)
	warning.add_theme_color_override("font_color", Color("#e74c3c"))
	confirmation.add_child(warning)
	var message := Label.new()
	message.text = "Start fresh? Any unsaved progress will be reset."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_font_size_override("font_size", 20)
	confirmation.add_child(message)
	confirmation.add_child(_button("YES, START NEW GAME", func() -> void: new_game_requested.emit()))
	confirmation.add_child(_button("CANCEL / BACK", _cancel_new_game))

func _setting_slider(parent: Control, title: String, low: float, high: float, increment: float, callback: Callable) -> HSlider:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = increment
	slider.custom_minimum_size.y = 64
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider

func _cancel_new_game() -> void:
	confirmation_panel.visible = false
	main_panel.visible = true

func _apply_layout() -> void:
	var ui_scale: float = 1.0 if MobileControls.enabled else 2.0
	scale = Vector2.ONE * ui_scale
	size = get_viewport_rect().size / ui_scale
	var viewport_safe: Rect2 = MobileControls.safe_rect()
	var safe := Rect2(viewport_safe.position / ui_scale, viewport_safe.size / ui_scale).grow(-16)
	var panel_size := Vector2(minf(680, safe.size.x), minf(720 if safe.size.y > safe.size.x else 500, safe.size.y))
	main_panel.size = panel_size
	main_panel.position = safe.position + (safe.size - panel_size) * 0.5
	var confirmation_size := Vector2(minf(600, safe.size.x), minf(340, safe.size.y))
	confirmation_panel.size = confirmation_size
	confirmation_panel.position = safe.position + (safe.size - confirmation_size) * 0.5
	_actions.columns = 2 if panel_size.x >= 560 else 1
	if _quit_button != null:
		_quit_button.visible = not MobileControls.enabled
	var modes := ["auto", "touch", "desktop"]
	for i in range(_touch_buttons.size()):
		_touch_buttons[i].set_pressed_no_signal(MobileControls.mode == modes[i])

	if _deadzone_slider != null:
		_deadzone_slider.set_value_no_signal(MobileControls.joystick_deadzone)
	var settings := get_node_or_null("/root/MobileSettings")
	if settings != null and _smoothing_slider != null:
		_smoothing_slider.set_value_no_signal(settings.follow_smoothing)
		_quality_picker.select(["auto", "low", "medium", "high"].find(settings.quality))
