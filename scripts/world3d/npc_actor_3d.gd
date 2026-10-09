class_name NPCActor3D extends Area3D
## NPCActor3D — Interactive 3D Overworld Actor for NPCs, Signposts, and Field Points.

signal interacted(npc_id: StringName)

@export var npc_id: StringName = &"generic"
@export var npc_name: String = "Ranger"
@export var prompt_text: String = "Talk"
@export var is_signpost: bool = false

var player_in_range: bool = false
var visual_root: Node3D
var prompt_label: Label3D
var _static_body: StaticBody3D
var _nearby_player: Node3D


func _ready() -> void:
	# Interaction trigger volume (2.5m radius sphere)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	col.shape = sphere
	add_child(col)

	# Physical obstacle collision so player doesn't clip through actor
	_static_body = StaticBody3D.new()
	var solid_col := CollisionShape3D.new()
	if is_signpost:
		var sign_box := BoxShape3D.new()
		sign_box.size = Vector3(0.5, 1.4, 0.5)
		solid_col.shape = sign_box
		solid_col.position.y = 0.7
	else:
		var human_capsule := CapsuleShape3D.new()
		human_capsule.radius = 0.3
		human_capsule.height = 1.4
		solid_col.shape = human_capsule
		solid_col.position.y = 0.7
	_static_body.add_child(solid_col)
	add_child(_static_body)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_build_visuals()

	# 3D Billboard Prompt Label
	prompt_label = Label3D.new()
	prompt_label.text = prompt_text if _touch_enabled() else "[E] " + prompt_text
	prompt_label.pixel_size = 0.005
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.position.y = 1.6 if not is_signpost else 1.3
	prompt_label.visible = false
	prompt_label.modulate = Color("#f4df82")
	prompt_label.outline_modulate = Color(0, 0, 0, 0.9)
	prompt_label.outline_size = 6
	add_child(prompt_label)
	var touch_controls := get_node_or_null("/root/MobileControls")
	if touch_controls != null:
		touch_controls.layout_changed.connect(func(): prompt_label.text = prompt_text if _touch_enabled() else "[E] " + prompt_text)

func _touch_enabled() -> bool:
	var touch_controls := get_node_or_null("/root/MobileControls")
	return touch_controls != null and touch_controls.enabled


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event.is_action_pressed("interact"):
		trigger_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			trigger_interaction()
			get_viewport().set_input_as_handled()


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _can_interact() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		trigger_interaction()
		get_viewport().set_input_as_handled()


func trigger_interaction() -> void:
	if not _can_interact():
		return
	interacted.emit(npc_id)

func _can_interact() -> bool:
	if not player_in_range or not is_instance_valid(_nearby_player):
		return false
	if not _nearby_player.movement_enabled:
		return false
	var exploration = get_parent().get_node_or_null("Exploration")
	return exploration == null or not exploration.blocks_legacy_input()


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_in_grass") or body.has_method("recover_to_safe_position"):
		_nearby_player = body
		player_in_range = true
		prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_in_grass") or body.has_method("recover_to_safe_position"):
		_nearby_player = null
		player_in_range = false
		prompt_label.visible = false


func _build_visuals() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

	if is_signpost:
		_build_signpost_visuals()
	else:
		_build_character_visuals()


func _build_signpost_visuals() -> void:
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color("#5a3c22")

	var mat_board := StandardMaterial3D.new()
	mat_board.albedo_color = Color("#8b623e")

	# Wooden Post
	var post := MeshInstance3D.new()
	post.mesh = BoxMesh.new()
	post.mesh.size = Vector3(0.14, 1.2, 0.14)
	post.material_override = mat_wood
	post.position.y = 0.6
	visual_root.add_child(post)

	# Sign Board Plaque
	var board := MeshInstance3D.new()
	board.mesh = BoxMesh.new()
	board.mesh.size = Vector3(0.9, 0.35, 0.08)
	board.material_override = mat_board
	board.position = Vector3(0, 0.95, 0.05)
	visual_root.add_child(board)


func _build_character_visuals() -> void:
	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color("#8d5524")

	var mat_clothes := StandardMaterial3D.new()
	if npc_id == &"healer":
		mat_clothes.albedo_color = Color("#3e8a71") # Medic clinic teal
	elif npc_id == &"researcher":
		mat_clothes.albedo_color = Color("#b3af9f") # Lab coat
	elif npc_id == &"trader":
		mat_clothes.albedo_color = Color("#a25b30") # Terracotta trader
	elif npc_id == &"guide":
		mat_clothes.albedo_color = Color("#4a705a") # River guide sage
	else:
		mat_clothes.albedo_color = Color("#3f5e42") # Savannah ranger green

	# Torso & Legs
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.mesh.radius = 0.25
	body.mesh.height = 0.85
	body.material_override = mat_clothes
	body.position.y = 0.45
	visual_root.add_child(body)

	# Head
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.2
	head.mesh.height = 0.4
	head.material_override = mat_skin
	head.position.y = 0.52
	body.add_child(head)

	# Hat / Headgear
	if npc_id != &"healer":
		var hat := MeshInstance3D.new()
		hat.mesh = CylinderMesh.new()
		hat.mesh.top_radius = 0.28
		hat.mesh.bottom_radius = 0.36
		hat.mesh.height = 0.08
		var mat_hat := StandardMaterial3D.new()
		mat_hat.albedo_color = Color("#d7b43e") if npc_id == &"ranger" else Color("#826c48")
		hat.material_override = mat_hat
		hat.position.y = 0.22
		head.add_child(hat)
