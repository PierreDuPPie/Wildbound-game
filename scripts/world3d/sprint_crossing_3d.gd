class_name SprintCrossing3D
extends Area3D
## An optional marked traversal shortcut. Walkers use the longer normal route.
## destination_offset is local to this node, so rotate the pad to orient the leap.
@export var destination_offset: Vector3 = Vector3(0, 0, -6)
@export var crossing_name: String = "Savannah shortcut"

func _ready() -> void:
	add_to_group("sprint_crossing")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)
	for at in [Vector3.ZERO, destination_offset]:
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.8
		mesh.bottom_radius = 0.8
		mesh.height = 0.05
		marker.mesh = mesh
		marker.position = at + Vector3.UP * 0.05
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d8b14b")
		marker.material_override = material
		add_child(marker)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player3D and body.has_speed_surge():
		cross_with_sprint(body)

func cross_with_sprint(actor: Node3D) -> bool:
	if not actor is Player3D or not actor.has_speed_surge() or not actor.movement_enabled or actor.global_position.distance_to(global_position) > 3.0:
		return false
	var destination := to_global(destination_offset)
	# Check the whole crossing and the arrival capsule; no wall bypasses or water landings.
	if actor.test_move(actor.global_transform, destination - actor.global_position):
		return false
	var original := actor.global_position
	actor.global_position = destination + Vector3.UP * 0.1
	var landing: Dictionary = actor.get_landing_status()
	if not bool(landing["safe"]) or float(landing["altitude"]) > 1.0:
		actor.global_position = original
		return false
	actor.global_position = landing["position"] + Vector3.UP * 0.05
	actor.last_safe_position = actor.global_position
	actor.travel_feedback.emit("Savannah Sprint crossed %s." % crossing_name)
	return true
