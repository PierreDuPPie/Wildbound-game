extends Control
## Own one finger until release, including drags outside the thumb pad.
signal moved(direction: Vector2)
var finger: int = -1
var direction := Vector2.ZERO
var mouse_dragging: bool = false
var deadzone: float = 0.12

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func():
		if not is_visible_in_tree(): reset())

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		if get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_dragging:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and mouse_dragging:
		reset()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and finger == -1:
		mouse_dragging = event.pressed
		if mouse_dragging:
			_update_direction(get_global_mouse_position())
		else:
			reset()
		accept_event()

func _update_direction(point: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.36
	var offset := point - get_global_rect().get_center()
	var threshold := clampf(deadzone, 0.05, 0.30)
	var strength := clampf((offset.length() / radius - threshold) / (1.0 - threshold), 0.0, 1.0)
	direction = offset.normalized() * strength if offset.length() > 0.0 else Vector2.ZERO
	moved.emit(direction)
	queue_redraw()

func reset() -> void:
	finger = -1
	mouse_dragging = false
	direction = Vector2.ZERO
	moved.emit(direction)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.39
	draw_circle(center, radius, Color(0.06, 0.13, 0.11, 0.7))
	draw_arc(center, radius, 0, TAU, 64, Color(0.85, 0.74, 0.5, 0.75), 2.0, true)
	for arrow: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_circle(center + arrow * radius * 0.76, 3.0, Color(0.72, 0.8, 0.73, 0.65))
	draw_circle(center + direction * radius * 0.54, radius * 0.39, Color(0.29, 0.46, 0.37, 0.95))
	draw_arc(center + direction * radius * 0.54, radius * 0.39, 0, TAU, 32, Color("e2bc76"), 2.0, true)
