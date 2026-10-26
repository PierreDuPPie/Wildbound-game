extends ScrollContainer
## Finger scrolling independent of hardware mouse-emulation quirks.
## Mouse wheel and desktop scrollbar behavior remain native.
var _finger := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _origin := Vector2.ZERO
var _dragging := false
var _velocity := Vector2.ZERO
var _suppress_mouse_until := 0

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_cancel()
		return
	if event is InputEventMouse and event.device == -1 and (_finger >= 0 or Time.get_ticks_msec() < _suppress_mouse_until):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
			_finger = event.index
			_start = event.position
			_last = event.position
			_origin = Vector2(scroll_horizontal,scroll_vertical)
			_velocity = Vector2.ZERO
			_dragging = false
		elif not event.pressed and event.index == _finger:
			if _dragging:
				propagate_notification(Control.NOTIFICATION_SCROLL_END)
				scroll_ended.emit()
				get_viewport().set_input_as_handled()
				_suppress_mouse_until = Time.get_ticks_msec()+120
			_finger = -1
			_dragging = false
	elif event is InputEventScreenDrag and event.index == _finger:
		var distance: Vector2 = event.position-_start
		var horizontal := horizontal_scroll_mode != SCROLL_MODE_DISABLED
		var vertical := vertical_scroll_mode != SCROLL_MODE_DISABLED
		if not _dragging and ((horizontal and absf(distance.x)>scroll_deadzone) or (vertical and absf(distance.y)>scroll_deadzone)):
			_dragging = true
			propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			scroll_started.emit()
		if _dragging:
			if horizontal: scroll_horizontal = roundi(_origin.x-distance.x)
			if vertical: scroll_vertical = roundi(_origin.y-distance.y)
			_velocity = -event.velocity.limit_length(1600)
			get_viewport().set_input_as_handled()
		_last = event.position

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_cancel()
		return
	if _finger >= 0 or _velocity.length()<8:
		return
	if horizontal_scroll_mode != SCROLL_MODE_DISABLED:
		scroll_horizontal += roundi(_velocity.x*delta)
	if vertical_scroll_mode != SCROLL_MODE_DISABLED:
		scroll_vertical += roundi(_velocity.y*delta)
	_velocity = _velocity.move_toward(Vector2.ZERO,3200*delta)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_cancel()

func _cancel() -> void:
	if _dragging: propagate_notification(Control.NOTIFICATION_SCROLL_END)
	_finger = -1
	_dragging = false
	_velocity = Vector2.ZERO
