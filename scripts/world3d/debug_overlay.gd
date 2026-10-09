class_name DebugOverlay extends CanvasLayer

@export var player: Node3D
@export var ratelit: Node3D

var panel: PanelContainer
var vbox: VBoxContainer
var lbl_fps: Label
var lbl_player: Label
var lbl_state: Label
var lbl_zone: Label
var lbl_encounter: Label

func _ready() -> void:
	visible = false
	layer = 120
	
	panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(10, 10)
	
	vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	lbl_fps = Label.new()
	lbl_player = Label.new()
	lbl_state = Label.new()
	lbl_zone = Label.new()
	lbl_encounter = Label.new()
	
	vbox.add_child(lbl_fps)
	vbox.add_child(lbl_player)
	vbox.add_child(lbl_state)
	vbox.add_child(lbl_zone)
	vbox.add_child(lbl_encounter)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle") or (event is InputEventKey and event.keycode == KEY_F3 and event.pressed):
		visible = not visible

func _process(_delta: float) -> void:
	if not visible:
		return
		
	lbl_fps.text = "FPS: %d" % Engine.get_frames_per_second()
	
	if is_instance_valid(player):
		lbl_player.text = "Player pos: %.1f, %.1f, %.1f" % [player.global_position.x, player.global_position.y, player.global_position.z]
	else:
		lbl_player.text = "Player pos: N/A"
		
	if is_instance_valid(ratelit):
		var state_idx = ratelit.current_state
		var state_str = "UNKNOWN"
		if state_idx == 0: state_str = "IDLE"
		elif state_idx == 1: state_str = "SENTRY_LOOK"
		elif state_idx == 2: state_str = "FORAGE"
		elif state_idx == 3: state_str = "NOTICE"
		elif state_idx == 4: state_str = "STARE"
		elif state_idx == 5: state_str = "CURL"
		elif state_idx == 6: state_str = "CHARGE"
		elif state_idx == 7: state_str = "APPROACH"
		elif state_idx == 8: state_str = "KEEP_DISTANCE"
		elif state_idx == 9: state_str = "FLEE"
		elif state_idx == 10: state_str = "ENCOUNTERED"
		
		lbl_state.text = "Ratelit state: " + state_str
	else:
		lbl_state.text = "Ratelit state: N/A"
		
	lbl_zone.text = "Zone: route_01_3d"
	lbl_encounter.text = "Encounter: Ready"
