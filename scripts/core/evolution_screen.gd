extends Control

signal evolutions_completed

@onready var bg_rect: ColorRect = $Background
@onready var visual_container: Control = $VisualContainer
@onready var dialog_panel: PanelContainer = $DialogPanel
@onready var dialog_label: Label = $DialogPanel/MarginContainer/Label
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

const CREATURE_VISUAL_SCENE = preload("res://scenes/battle/creature_visual.tscn")
var creature_visual: CreatureVisual

var pending_evolutions: Array[CreatureInstance] = []
var current_creature: CreatureInstance = null
var is_waiting_for_input: bool = false
var continue_button: Button

func _ready() -> void:
	dialog_panel.hide()
	bg_rect.color = Color(0.1, 0.1, 0.15, 1)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(180, 66)
	continue_button.add_theme_font_size_override("font_size", 24)
	continue_button.pressed.connect(_continue_evolution)
	add_child(continue_button)
	MobileControls.layout_changed.connect(_layout_mobile)
	_layout_mobile()

func _layout_mobile() -> void:
	if not is_instance_valid(continue_button): return
	continue_button.visible = MobileControls.enabled and is_waiting_for_input
	if MobileControls.enabled:
		var rect: Rect2 = MobileControls.safe_rect()
		dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		dialog_panel.position = Vector2(rect.position.x + 12, rect.end.y - 240)
		dialog_panel.size = Vector2(rect.size.x - 24, 144)
		dialog_label.add_theme_font_size_override("font_size", 24)
		continue_button.position = Vector2(rect.end.x - 192, rect.end.y - 76)
	else:
		dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_panel.offset_left = 64
		dialog_panel.offset_top = -180
		dialog_panel.offset_right = -64
		dialog_panel.offset_bottom = -32

func start_evolutions(creatures: Array[CreatureInstance]) -> void:
	pending_evolutions = creatures
	_process_next_evolution()

func _process_next_evolution() -> void:
	if pending_evolutions.is_empty():
		emit_signal("evolutions_completed")
		return
		
	current_creature = pending_evolutions.pop_front()
	_start_evolution_sequence()

func _start_evolution_sequence() -> void:
	var old_name = current_creature.nickname
	if old_name.is_empty():
		old_name = current_creature.species.display_name
	
	if creature_visual != null:
		creature_visual.queue_free()
		
	creature_visual = CREATURE_VISUAL_SCENE.instantiate()
	visual_container.add_child(creature_visual)
	creature_visual.position = visual_container.size / 2.0
	
	creature_visual.setup(current_creature.species, true)
	
	_show_message("What? %s is evolving!" % old_name)
	await get_tree().create_timer(1.5, false).timeout
	
	var tw = create_tween()
	for i in range(6):
		var time = 0.4 - (i * 0.05)
		tw.tween_property(creature_visual.sprite, "modulate", Color(2,2,2,1), time)
		tw.tween_property(creature_visual.sprite, "modulate", Color(0,0,0,1), time)
	
	await tw.finished
	
	var result = current_creature.evolve()
	var new_name = current_creature.species.display_name
	
	creature_visual.setup(current_creature.species, true)
	
	creature_visual.sprite.modulate = Color(5, 5, 5, 1)
	var tw2 = create_tween()
	tw2.tween_property(creature_visual.sprite, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_CUBIC)
	
	var sfx_path = "res://assets/audio/ui/level_up.wav"
	if ResourceLoader.exists(sfx_path):
		audio_player.stream = load(sfx_path)
		audio_player.play()
	
	_show_message("Congratulations! Your %s evolved into %s!" % [old_name, new_name])
	
	is_waiting_for_input = true
	_layout_mobile()

func _continue_evolution() -> void:
	if not is_waiting_for_input: return
	is_waiting_for_input = false
	continue_button.hide()
	dialog_panel.hide()
	_process_next_evolution()

func _input(event: InputEvent) -> void:
	if not is_waiting_for_input:
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		_continue_evolution()

func _show_message(text: String) -> void:
	dialog_panel.show()
	dialog_label.text = text
