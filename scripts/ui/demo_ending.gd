class_name DemoEnding
extends Control

signal continue_requested
signal new_game_requested
signal quit_requested

var sequence_step: int = 0
var dialogue_label: Label
var speaker_label: Label
var title_card: Label
var subtitle_label: Label
var buttons_container: HBoxContainer
var sequence_timer: Timer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	start_sequence()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0c120e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center_box := VBoxContainer.new()
	center_box.position = Vector2(100, 80)
	center_box.size = Vector2(760, 380)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 16)
	add_child(center_box)

	speaker_label = Label.new()
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.add_theme_color_override("font_color", Color("#e5cf7d"))
	center_box.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(720, 120)
	dialogue_label.add_theme_font_size_override("font_size", 19)
	dialogue_label.add_theme_color_override("font_color", Color("#f5efdc"))
	center_box.add_child(dialogue_label)

	title_card = Label.new()
	title_card.text = "WILDBOUND"
	title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_card.add_theme_font_size_override("font_size", 56)
	title_card.add_theme_color_override("font_color", Color("#f5c451"))
	title_card.visible = false
	center_box.add_child(title_card)

	subtitle_label = Label.new()
	subtitle_label.text = "0.1 DEMO COMPLETE"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color("#a2b794"))
	subtitle_label.visible = false
	center_box.add_child(subtitle_label)

	buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_theme_constant_override("separation", 16)
	buttons_container.visible = false
	center_box.add_child(buttons_container)

	var btn_continue := Button.new()
	btn_continue.text = "▶ Continue Exploring"
	btn_continue.custom_minimum_size = Vector2(200, 42)
	btn_continue.pressed.connect(func() -> void: continue_requested.emit())
	buttons_container.add_child(btn_continue)

	var btn_new := Button.new()
	btn_new.text = "↺ New Game"
	btn_new.custom_minimum_size = Vector2(160, 42)
	btn_new.pressed.connect(func() -> void: new_game_requested.emit())
	buttons_container.add_child(btn_new)

	var btn_quit := Button.new()
	btn_quit.text = "✖ Quit"
	btn_quit.custom_minimum_size = Vector2(130, 42)
	btn_quit.pressed.connect(func() -> void: quit_requested.emit())
	buttons_container.add_child(btn_quit)

	sequence_timer = Timer.new()
	sequence_timer.one_shot = false
	add_child(sequence_timer)
	sequence_timer.timeout.connect(_on_sequence_step)

func start_sequence() -> void:
	sequence_step = 0
	_advance_step()
	sequence_timer.start(2.2)

func _on_sequence_step() -> void:
	_advance_step()

func _advance_step() -> void:
	sequence_step += 1
	match sequence_step:
		1:
			speaker_label.text = "Ranger"
			dialogue_label.text = "“Good work, Wildkeeper. Most creatures need time before they’ll trust a human.”"
		2:
			speaker_label.text = ""
			dialogue_label.text = "[...a suspicious rattle comes from inside the supply hut...]"
		3:
			speaker_label.text = ""
			dialogue_label.text = "[A wild Ratelit walks out, casually dragging half the ranger's food supply.]"
		4:
			speaker_label.text = "Ranger"
			dialogue_label.text = "“...except that one.”"
		5:
			speaker_label.text = ""
			dialogue_label.text = "[Ratelit makes direct eye contact. ♪ suspicious honey badger sting ♪ Ratelit scurries off into the bush.]"
		6:
			speaker_label.text = "Ranger"
			dialogue_label.text = "“That's odd... the Resonance Band shouldn't react like that.”"
		7:
			speaker_label.visible = false
			dialogue_label.visible = false
			title_card.visible = true
			subtitle_label.visible = true
			buttons_container.visible = true
			sequence_timer.stop()
