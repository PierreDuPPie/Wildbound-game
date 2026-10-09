extends Button
## Button with independent touch ownership: jump can be held while steering.
signal held_changed(held: bool)
var finger: int = -1

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(func():
		if finger == -1: held_changed.emit(true))
	button_up.connect(func():
		if finger == -1: held_changed.emit(false))
	visibility_changed.connect(func():
		if not is_visible_in_tree(): reset())

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		return
	# Godot sends the emulated mouse press before the original touch. Consume
	# that copy here; only the finger event may activate a gameplay button.
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		if get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index
			set_pressed_no_signal(true)
			held_changed.emit(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			reset()
			get_viewport().set_input_as_handled()

func reset() -> void:
	if finger != -1 or button_pressed:
		finger = -1
		set_pressed_no_signal(false)
		held_changed.emit(false)
