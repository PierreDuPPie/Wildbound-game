extends Node
## Keep the authored dialogue and desktop layout; make long phone text scroll.
var panel: PanelContainer
var text_label: Label
var name_label: Label
var hint_label: Label
var _box: Container
var _scroll: ScrollContainer
var _original_position: Vector2
var _original_size: Vector2
var _original_minimum: Vector2
var _original_hint: String
var _original_index: int
var _mobile: bool = false

func _ready() -> void:
	panel = get_parent().dialogue_panel
	name_label = get_parent().dialogue_name_label
	hint_label = get_parent().dialogue_hint_label
	text_label = get_parent().get("dialogue_text_label") if "dialogue_text_label" in get_parent() else get_parent().get("dialogue_label")
	_box = text_label.get_parent()
	_original_position = panel.position
	_original_size = panel.size
	_original_minimum = panel.custom_minimum_size
	_original_hint = hint_label.text
	_original_index = text_label.get_index()
	_scroll = ScrollContainer.new()
	_scroll.name = "DialogueScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	MobileControls.layout_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var touch: bool = MobileControls.enabled
	if touch != _mobile:
		_mobile = touch
		if touch:
			_box.add_child(_scroll)
			_box.move_child(_scroll, _original_index)
			text_label.reparent(_scroll)
			text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			text_label.reparent(_box)
			_box.move_child(text_label, _original_index)
			_box.remove_child(_scroll)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if touch else Control.MOUSE_FILTER_STOP
	name_label.add_theme_font_size_override("font_size", 26 if touch else 20)
	text_label.add_theme_font_size_override("font_size", 24 if touch else 18)
	hint_label.add_theme_font_size_override("font_size", 18 if touch else 13)
	hint_label.text = "Scroll to read · tap Continue" if touch else _original_hint
	if touch:
		var rect: Rect2 = MobileControls.safe_rect()
		var height := minf(rect.size.y * 0.6, 340.0)
		panel.custom_minimum_size = Vector2.ZERO
		panel.size = Vector2(rect.size.x - 24, height)
		panel.position = Vector2(rect.position.x + 12, rect.end.y - height - 88)
	else:
		panel.custom_minimum_size = _original_minimum
		panel.size = _original_size
		panel.position = _original_position

func _exit_tree() -> void:
	if is_instance_valid(_scroll) and not _scroll.is_inside_tree(): _scroll.free()
