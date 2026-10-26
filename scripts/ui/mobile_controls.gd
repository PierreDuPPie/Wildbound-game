extends CanvasLayer
## Shared touch mode and responsive viewport. Gameplay still owns every action.
signal layout_changed
const UI = preload("res://scripts/ui/frontier_theme.gd")
const JOYSTICK = preload("res://scripts/ui/mobile_joystick.gd")
const TOUCH_BUTTON = preload("res://scripts/ui/mobile_action_button.gd")
const PREFERENCE_PATH := "user://interface.cfg"
const DIRECTIONS := ["move_left", "move_right", "move_forward", "move_back"]
var enabled: bool = false
var mode: String = "auto"
var joystick_deadzone: float = 0.12
var button_size: float = 72.0
var action_margin_x: float = 12.0
var action_margin_y: float = 12.0
var root: Control
var joystick: Control
var action_bar: GridContainer
var buttons: Dictionary = {}
var context: String = ""
var _bootstrap: Node
var _keys: Dictionary = {}
var _movement: Dictionary = {}
var _size := Vector2.ZERO
var _original_scale_size := Vector2i(1920, 1080)
var _original_aspect: int = Window.CONTENT_SCALE_ASPECT_IGNORE
var _preview: bool = false
var _context_signature: String = ""
var _original_mouse_emulation: bool = false
var _sprinting: bool = false
var _movement_deadzones: Dictionary = {}
var _orientation_blocked: bool = false
var _previous_pause: bool = false
var _rotation_notice: Control
var _pause_reasons: Dictionary = {}
var _application_suspended: bool = false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_original_scale_size = get_window().content_scale_size
	_original_aspect = get_window().content_scale_aspect
	_original_mouse_emulation = Input.emulate_mouse_from_touch
	for action: String in DIRECTIONS:
		_movement_deadzones[action] = InputMap.action_get_deadzone(action)
	_preview = "--mobile-preview" in OS.get_cmdline_user_args()
	var config := ConfigFile.new()
	if config.load(PREFERENCE_PATH) == OK:
		mode = str(config.get_value("controls", "mode", "auto"))
		if mode not in ["auto", "touch", "desktop"]: mode = "auto"
		joystick_deadzone = clampf(float(config.get_value("controls", "joystick_deadzone", 0.12)), 0.05, 0.30)
		button_size = clampf(float(config.get_value("controls", "button_size", 72.0)), 56.0, 96.0)
		action_margin_x = clampf(float(config.get_value("controls", "action_margin_x", 12.0)), 0.0, 240.0)
		action_margin_y = clampf(float(config.get_value("controls", "action_margin_y", 12.0)), 0.0, 200.0)
	if _preview: mode = "touch"
	_build_controls()
	_build_rotation_notice()
	_apply_mode()
	get_viewport().size_changed.connect(_reflow)
	get_tree().root.focus_exited.connect(release_all)

func bind_bootstrap(bootstrap: Node) -> void:
	release_all()
	_bootstrap = bootstrap
	_context_signature = ""

func suspend_gameplay() -> void:
	if enabled:
		_set_context("menu", null)

func refresh_context() -> void:
	_process(0.0)

func set_mode(new_mode: String) -> void:
	if new_mode not in ["auto", "touch", "desktop"]: return
	mode = new_mode
	if not _preview:
		var config := ConfigFile.new()
		config.load(PREFERENCE_PATH)
		config.set_value("controls", "mode", mode)
		var result := config.save(PREFERENCE_PATH)
		if result != OK: push_warning("Could not save control preference: " + error_string(result))
	_apply_mode()

func set_joystick_deadzone(value: float) -> void:
	joystick_deadzone = clampf(value, 0.05, 0.30)
	if is_instance_valid(joystick):
		joystick.deadzone = joystick_deadzone
		joystick.reset()
	var config := ConfigFile.new()
	config.load(PREFERENCE_PATH)
	config.set_value("controls", "joystick_deadzone", joystick_deadzone)
	var result := config.save(PREFERENCE_PATH)
	if result != OK: push_warning("Could not save joystick preference: " + error_string(result))

func set_button_size(value: float) -> void:
	button_size = clampf(value, 56.0, 96.0)
	_apply_button_styles()
	_position_actions()
	var config := ConfigFile.new()
	config.load(PREFERENCE_PATH)
	config.set_value("controls", "button_size", button_size)
	var result := config.save(PREFERENCE_PATH)
	if result != OK: push_warning("Could not save button size preference: " + error_string(result))
	layout_changed.emit()

func set_action_margin_x(value: float) -> void:
	action_margin_x = clampf(value, 0.0, 240.0)
	_position_actions()
	var config := ConfigFile.new()
	config.load(PREFERENCE_PATH)
	config.set_value("controls", "action_margin_x", action_margin_x)
	var result := config.save(PREFERENCE_PATH)
	if result != OK: push_warning("Could not save button margin x preference: " + error_string(result))
	layout_changed.emit()

func set_action_margin_y(value: float) -> void:
	action_margin_y = clampf(value, 0.0, 200.0)
	_position_actions()
	var config := ConfigFile.new()
	config.load(PREFERENCE_PATH)
	config.set_value("controls", "action_margin_y", action_margin_y)
	var result := config.save(PREFERENCE_PATH)
	if result != OK: push_warning("Could not save button margin y preference: " + error_string(result))
	layout_changed.emit()

func _apply_mode() -> void:
	release_all()
	enabled = mode == "touch" or (mode == "auto" and (OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()))
	get_window().content_scale_size = _mobile_scale_size() if enabled else _original_scale_size
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if enabled else _original_aspect
	Input.emulate_mouse_from_touch = true if enabled else _original_mouse_emulation
	for action: String in DIRECTIONS:
		# The pad owns its radial deadzone; avoid a second half-pad deadzone.
		InputMap.action_set_deadzone(action, 0.0 if enabled else _movement_deadzones[action])
	root.visible = enabled
	_context_signature = ""
	_reflow.call_deferred()

func safe_rect() -> Rect2:
	var rect := get_viewport().get_visible_rect()
	# Native mobile OS reports notch/system-bar bounds in display pixels.
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if safe.size.x > 0 and safe.size.y > 0 and screen.x > 0 and screen.y > 0:
			var factor := rect.size / Vector2(screen)
			rect = Rect2(Vector2(safe.position) * factor, Vector2(safe.size) * factor)
	return rect.grow(-12.0)

func _build_controls() -> void:
	root = Control.new()
	root.name = "TouchControls"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.create_theme()
	add_child(root)
	joystick = JOYSTICK.new()
	joystick.name = "MovementPad"
	joystick.deadzone = joystick_deadzone
	joystick.moved.connect(_steer)
	root.add_child(joystick)
	action_bar = GridContainer.new()
	action_bar.name = "ActionButtons"
	action_bar.columns = 3
	action_bar.add_theme_constant_override("h_separation", 8)
	action_bar.add_theme_constant_override("v_separation", 8)
	root.add_child(action_bar)
	for id: String in ["interact", "jump", "sprint", "ride", "fly", "descend", "rotate", "place", "cancel", "continue", "camera", "undo", "ability"]:
		var button: Button = TOUCH_BUTTON.new()
		button.name = id.capitalize()
		button.text = id.capitalize()
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.held_changed.connect(func(held: bool): _button_changed(id, held))
		button.visible = false
		action_bar.add_child(button)
		buttons[id] = button
	_apply_button_styles()

func _apply_button_styles() -> void:
	if not is_instance_valid(action_bar): return
	var radius := int(button_size / 2.0)
	var font_sz := clampi(int(button_size * 0.22), 12, 22)
	for id: String in buttons:
		var button: Button = buttons[id]
		if not is_instance_valid(button): continue
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.size = Vector2(button_size, button_size)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", font_sz)
		
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.10, 0.20, 0.16, 0.88)
		normal_style.border_color = Color(0.78, 0.70, 0.45, 0.85)
		normal_style.set_border_width_all(2)
		normal_style.set_corner_radius_all(radius)
		normal_style.content_margin_left = 4
		normal_style.content_margin_right = 4
		normal_style.content_margin_top = 4
		normal_style.content_margin_bottom = 4
		button.add_theme_stylebox_override("normal", normal_style)
		
		var pressed_style := normal_style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = Color(0.85, 0.72, 0.35, 0.95)
		pressed_style.border_color = Color(1.0, 0.96, 0.75, 1.0)
		button.add_theme_stylebox_override("pressed", pressed_style)
		
		var hover_style := normal_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.16, 0.30, 0.24, 0.92)
		hover_style.border_color = Color(0.92, 0.82, 0.52, 0.95)
		button.add_theme_stylebox_override("hover", hover_style)
		
		var disabled_style := normal_style.duplicate() as StyleBoxFlat
		disabled_style.bg_color = Color(0.12, 0.14, 0.13, 0.45)
		disabled_style.border_color = Color(0.35, 0.35, 0.35, 0.35)
		button.add_theme_stylebox_override("disabled", disabled_style)
		
		var focus_style := normal_style.duplicate() as StyleBoxFlat
		button.add_theme_stylebox_override("focus", focus_style)

func _reflow() -> void:
	if not is_instance_valid(root): return
	if enabled and get_window().content_scale_size != _mobile_scale_size():
		get_window().content_scale_size = _mobile_scale_size()
		_reflow.call_deferred()
		return
	var new_size := get_viewport().get_visible_rect().size
	if _size != new_size: release_all()
	_size = new_size
	var rect := safe_rect()
	var pad_size := 160.0 if rect.size.x < 700 else 176.0
	joystick.size = Vector2.ONE * pad_size
	joystick.position = Vector2(rect.position.x + 4, rect.end.y - pad_size - 4)
	_position_actions.call_deferred()
	_context_signature = ""
	layout_changed.emit()

func _mobile_scale_size() -> Vector2i:
	# Keep touch targets the same physical size when a phone rotates.
	return Vector2i(540, 960) if get_window().size.x < get_window().size.y else Vector2i(960, 540)

func _build_rotation_notice() -> void:
	_rotation_notice = Control.new()
	_rotation_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotation_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rotation_notice)
	var background := ColorRect.new()
	background.color = Color("172d27")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotation_notice.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotation_notice.add_child(center)
	var text := Label.new()
	text.text = "Rotate your phone\n\nWildbound plays in landscape.\nTurn sideways to continue."
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 28)
	text.add_theme_color_override("font_color", Color("f1eedf"))
	center.add_child(text)
	_rotation_notice.hide()

func _update_orientation_gate() -> bool:
	var portrait := (enabled or OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios")) and is_instance_valid(_bootstrap) and get_window().size.x <= get_window().size.y
	if OS.has_feature("web") and is_instance_valid(_bootstrap):
		portrait = bool(JavaScriptBridge.eval("window.wildbound && window.wildbound.orientationBlocked === true"))
	if portrait != _orientation_blocked:
		_orientation_blocked = portrait
		_set_pause_reason("orientation", portrait)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("document.getElementById('canvas').dataset.gamePaused = '%s'" % str(get_tree().paused))
	# Browser chrome supplies the notice before the engine starts as well.
	_rotation_notice.visible = portrait and not OS.has_feature("web")
	return portrait

func _position_actions() -> void:
	if not is_instance_valid(action_bar): return
	action_bar.size = action_bar.get_combined_minimum_size()
	var rect := safe_rect()
	var pos_x := rect.end.x - action_bar.size.x - action_margin_x
	var pos_y := rect.end.y - action_bar.size.y - action_margin_y
	pos_x = clampf(pos_x, rect.position.x, rect.end.x - action_bar.size.x)
	pos_y = clampf(pos_y, rect.position.y, rect.end.y - action_bar.size.y)
	action_bar.position = Vector2(pos_x, pos_y)

func _process(_delta: float) -> void:
	if _update_orientation_gate() or _application_suspended:
		_set_context("", null)
		return
	if not enabled or not is_instance_valid(_bootstrap) or not is_instance_valid(_bootstrap.active_scene):
		_set_context("", null)
		return
	if _bootstrap.is_transitioning:
		_set_context("", null)
		return
	var scene: Node = _bootstrap.active_scene
	var exploration: Node = scene.get_node_or_null("Exploration")
	if exploration == null:
		_set_context("battle", null)
		return
	var next_context := "explore"
	if "dialogue_panel" in scene and is_instance_valid(scene.dialogue_panel) and scene.dialogue_panel.visible:
		next_context = "dialogue"
	elif exploration.is_legacy_overlay_open() or not exploration.hud.current_modal.is_empty():
		next_context = "menu"
	elif not exploration.build_recipe.is_empty():
		next_context = "build"
	elif not exploration.player.movement_enabled:
		next_context = ""
	elif exploration.player.is_flying():
		next_context = "flying"
	elif exploration.player.is_mounted():
		next_context = "riding"
	_set_context(next_context, exploration)
	if next_context == "flying" and exploration.player.has_method("get_landing_status"):
		var landing: Dictionary = exploration.player.get_landing_status()
		buttons["fly"].disabled = not landing.get("safe", false) and not exploration.player._landing_requested
		buttons["fly"].text = "Stop land" if exploration.player._landing_requested else "Land"

func _set_context(next_context: String, exploration: Node) -> void:
	var flying: bool = exploration != null and exploration.player.is_flying()
	var mounted: bool = exploration != null and exploration.player.is_mounted()
	var ride_ready: bool = exploration != null and exploration.homestead.has_upgrade("saddle")
	var fly_ready: bool = exploration != null and exploration.homestead.has_upgrade("glider_harness")
	var undo_ready: bool = exploration != null and exploration.has_method("can_undo_build") and exploration.can_undo_build()
	var signature := "%s:%s:%s:%s:%s:%s" % [next_context, flying, mounted, ride_ready, fly_ready, undo_ready]
	if _context_signature == signature: return
	_context_signature = signature
	if context != next_context:
		release_all()
	context = next_context
	root.visible = enabled and context in ["explore", "riding", "flying", "build", "dialogue"]
	joystick.visible = context in ["explore", "riding", "flying", "build"]
	joystick.tooltip_text = "Move placement target" if context == "build" else "Move"
	for id: String in buttons:
		buttons[id].visible = false
		buttons[id].disabled = false
	var actions: Array[String] = []
	if context == "explore":
		actions = ["interact", "jump", "sprint", "ability"]
		if ride_ready: actions.append("ride")
		if fly_ready: actions.append("fly")
		if undo_ready: actions.append("undo")
	elif context == "riding":
		actions = ["interact", "jump", "ride", "sprint", "ability"]
		if fly_ready: actions.append("fly")
	elif context == "flying":
		actions = ["jump", "descend", "fly"]
	elif context == "build":
		actions = ["rotate", "place", "cancel"]
	elif context == "dialogue":
		actions = ["continue"]
	for id: String in actions:
		buttons[id].visible = true
	buttons["jump"].text = "Rise" if flying else "Jump"
	buttons["ride"].text = "Dismount" if mounted and not flying else "Ride"
	buttons["fly"].text = "Land" if flying else "Fly"
	buttons["interact"].text = "Interact"
	_position_actions.call_deferred()

func _steer(direction: Vector2) -> void:
	var exploration := _get_exploration()
	if exploration != null and exploration.has_method("set_mobile_build_direction"):
		exploration.set_mobile_build_direction(direction if enabled and context == "build" else Vector2.ZERO)
	if not enabled or context not in ["explore", "riding", "flying"]:
		direction = Vector2.ZERO
	var strengths := [maxf(0, -direction.x), maxf(0, direction.x), maxf(0, -direction.y), maxf(0, direction.y)]
	for index: int in range(DIRECTIONS.size()):
		var action: String = DIRECTIONS[index]
		if strengths[index] > 0.0:
			Input.action_press(action, strengths[index])
			_movement[action] = true
		elif _movement.has(action):
			Input.action_release(action)
			_movement.erase(action)

func _button_changed(id: String, held: bool) -> void:
	if held and (not enabled or not root.visible or not buttons[id].visible or buttons[id].disabled): return
	if id == "ability":
		if held:
			var exploration := _get_exploration()
			if exploration != null: exploration.hud.open_abilities()
		return
	if id == "undo":
		var exploration := _get_exploration()
		if held and exploration != null and exploration.has_method("undo_last_build"):
			exploration.undo_last_build()
		return
	if id == "sprint":
		if held:
			_sprinting = not _sprinting
			buttons[id].text = "Sprint on" if _sprinting else "Sprint"
			_dispatch_key(KEY_SHIFT, _sprinting)
			_position_actions.call_deferred()
		return
	var keys := {"interact": KEY_E, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "ride": KEY_R, "fly": KEY_F, "descend": KEY_CTRL, "rotate": KEY_T, "place": KEY_ENTER, "cancel": KEY_ESCAPE, "continue": KEY_E, "camera": KEY_F2}
	_dispatch_key(int(keys[id]), held)

func _dispatch_key(key: int, pressed: bool) -> void:
	if pressed:
		if _keys.has(key): return
		# A tapped navigation button can keep GUI focus. Space/Enter from
		# gameplay must jump/place, rather than activate that old menu button.
		get_viewport().gui_release_focus()
		_keys[key] = true
	elif not _keys.has(key):
		return
	else:
		_keys.erase(key)
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func release_all() -> void:
	_sprinting = false
	if buttons.has("sprint"): buttons["sprint"].text = "Sprint"
	for key: int in _keys.keys():
		_dispatch_key(key, false)
	for action: String in _movement.keys():
		Input.action_release(action)
	_movement.clear()
	if is_instance_valid(joystick): joystick.reset()
	for button: Button in buttons.values(): button.reset()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release_all()
	if OS.has_feature("android") or OS.has_feature("ios"):
		if what == NOTIFICATION_APPLICATION_PAUSED:
			set_application_suspended(true)
		elif what == NOTIFICATION_APPLICATION_RESUMED:
			set_application_suspended(false)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()

func _get_exploration() -> Node:
	if not is_instance_valid(_bootstrap) or not is_instance_valid(_bootstrap.active_scene): return null
	return _bootstrap.active_scene.get_node_or_null("Exploration")

func _set_pause_reason(reason: String, active: bool) -> void:
	if active:
		if _pause_reasons.has(reason): return
		if _pause_reasons.is_empty(): _previous_pause = get_tree().paused
		_pause_reasons[reason] = true
		release_all()
		get_tree().paused = true
	else:
		if not _pause_reasons.has(reason): return
		_pause_reasons.erase(reason)
		if _pause_reasons.is_empty(): get_tree().paused = _previous_pause
	_context_signature = ""

func set_application_suspended(suspended: bool) -> void:
	# Save once before pausing; Bootstrap rejects battle/transition scenes and
	# SaveManager keeps the previous valid save until replacement succeeds.
	if _application_suspended == suspended: return
	_application_suspended = suspended
	release_all()
	if suspended and is_instance_valid(_bootstrap) and not _bootstrap.is_transitioning and _get_exploration() != null:
		if not _bootstrap.save_progress():
			_get_exploration().hud.toast("Progress could not be saved. Retry Save in the menu after returning.", 8.0)
	_set_pause_reason("background", suspended)
	if not suspended: refresh_context()

func handle_back() -> bool:
	if _orientation_blocked or _application_suspended: return true
	var exploration := _get_exploration()
	if exploration == null: return true # Battles keep their explicit Run/back commands.
	release_all()
	var scene: Node = exploration.zone
	for property: String in ["system_menu_ui", "backpack_ui"]:
		if property in scene:
			var menu: Control = scene.get(property)
			if is_instance_valid(menu) and menu.visible:
				if menu.has_method("handle_back"): menu.handle_back()
				else: menu.close()
				return true
	if "dialogue_panel" in scene and is_instance_valid(scene.dialogue_panel) and scene.dialogue_panel.visible:
		if scene.has_method("close_dialogue"): scene.close_dialogue()
	elif not exploration.hud.current_modal.is_empty():
		exploration.hud.close_modal()
	elif not exploration.build_recipe.is_empty():
		exploration.cancel_build()
	else:
		exploration.hud._open_legacy("menu")
	return true
