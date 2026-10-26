class_name BurrowObstacle3D
extends StaticBody3D
## BurrowObstacle3D — Physical boulder or cave-in barrier that can be shattered by Ratelit's Burrow Breaker.

signal shattered(obstacle_id: String)

@export var obstacle_id: String = "rockfall_route_02"
@export var prompt_message: String = "Cracked rockfall blocks the passage. Ratelit could burrow through."

var _visual: Node3D
var _collision: CollisionShape3D

func _ready() -> void:
	add_to_group("burrow_obstacle")
	
	# Check if already cleared in ProgressionManager
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression != null and progression.is_milestone_completed("burrow_" + obstacle_id):
		queue_free()
		return
		
	_build_visuals()

func _build_visuals() -> void:
	if has_node("Visual"):
		_visual = $Visual
		return
		
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	
	# Boulder cluster
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.38, 0.32) # Rocky granite
	mat.roughness = 0.9
	
	# Crack highlight material
	var crack_mat := StandardMaterial3D.new()
	crack_mat.albedo_color = Color(0.25, 0.22, 0.18)
	
	for i in range(4):
		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.75 + (i * 0.15)
		sphere.height = 1.4 + (i * 0.2)
		mesh_inst.mesh = sphere
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(
			(i - 1.5) * 0.7,
			0.5 + (i % 2) * 0.3,
			((i * 2) % 3) * 0.3
		)
		mesh_inst.scale = Vector3(1.1, 0.85, 0.95)
		_visual.add_child(mesh_inst)
		
	# Collision box
	if not has_node("Collision"):
		var col := CollisionShape3D.new()
		col.name = "Collision"
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 2.0, 1.8)
		col.shape = box
		col.position = Vector3(0, 1.0, 0)
		add_child(col)
		_collision = col

func shatter(actor: Node3D = null) -> void:
	if bool(get_meta("cleared", false)):
		return
	set_meta("cleared", true)
	# Open the physical passage immediately; the rubble animation is decorative.
	collision_layer = 0
	collision_mask = 0
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression != null:
		progression.complete_milestone("burrow_" + obstacle_id)
		
	shattered.emit(obstacle_id)
	
	# Create shattering rock debris animation
	if is_instance_valid(_visual):
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3(1.3, 0.2, 1.3), 0.25).set_trans(Tween.TRANS_BOUNCE)
		tween.parallel().tween_property(_visual, "position:y", -0.5, 0.25)
		tween.tween_callback(queue_free)
	else:
		queue_free()
