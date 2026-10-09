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

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		config.set_value("controls", "mode", mode)
		var result := config.save(PREFERENCE_PATH)
		if result != OK: push_warning("Could not save control preference: " + error_string(result))
	_apply_mode()

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
	joystick.moved.connect(_steer)
	root.add_child(joystick)
	action_bar = GridContainer.new()
	action_bar.name = "ActionButtons"
	action_bar.columns = 3
	action_bar.add_theme_constant_override("h_separation", 8)
	action_bar.add_theme_constant_override("v_separation", 8)
	root.add_child(action_bar)
	for id: String in ["interact", "jump", "sprint", "ride", "fly", "descend", "rotate", "place", "cancel", "continue", "camera"]:
		var button: Button = TOUCH_BUTTON.new()
		button.name = id.capitalize()
		button.text = id.capitalize()
		button.clip_text = true
		button.custom_minimum_size = Vector2(108, 66)
		button.add_theme_font_size_override("font_size", 20 if id == "ride" else 21 if id == "sprint" else 22)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = root.theme.get_stylebox(state, "Button").duplicate()
			style.content_margin_left = 10
			style.content_margin_right = 10
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			button.add_theme_stylebox_override(state, style)
		button.held_changed.connect(func(held: bool): _button_changed(id, held))
		button.visible = false
		action_bar.add_child(button)
		buttons[id] = button

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
		if portrait:
			_previous_pause = get_tree().paused
			release_all()
			get_tree().paused = true
		else:
			get_tree().paused = _previous_pause
			_context_signature = ""
		if OS.has_feature("web"):
			JavaScriptBridge.eval("document.getElementById('canvas').dataset.gamePaused = '%s'" % str(get_tree().paused))
	# Browser chrome supplies the notice before the engine starts as well.
	_rotation_notice.visible = portrait and not OS.has_feature("web")
	return portrait

func _position_actions() -> void:
	if not is_instance_valid(action_bar): return
	action_bar.size = action_bar.get_combined_minimum_size()
	action_bar.position = safe_rect().end - action_bar.size - Vector2(4, 4)

func _process(_delta: float) -> void:
	if _update_orientation_gate():
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
		_set_context("", null)
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
	_set_context(next_context, exploration)

func _set_context(next_context: String, exploration: Node) -> void:
	var flying: bool = exploration != null and exploration.player.is_flying()
	var mounted: bool = exploration != null and exploration.player.is_mounted()
	var signature := "%s:%s:%s" % [next_context, flying, mounted]
	if _context_signature == signature: return
	_context_signature = signature
	if context != next_context:
		release_all()
	context = next_context
	root.visible = enabled and context in ["explore", "build", "dialogue"]
	joystick.visible = context in ["explore", "build"]
	for id: String in buttons:
		buttons[id].visible = false
	var actions: Array[String] = []
	if context == "explore":
		actions = ["interact", "jump", "sprint", "ride", "fly", "descend" if flying else "camera"]
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
	if not enabled or context not in ["explore", "build"]:
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
	if held and (not enabled or not root.visible or not buttons[id].visible): return
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
