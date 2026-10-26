class_name ScannableClue3D
extends Area3D
## ScannableClue3D — Hidden or subtle wildlife clues revealed by Meerkit's Sentry Scan.

signal inspected(clue_id: String)

@export var clue_id: String = "injured_tracks"
@export var clue_name: String = "Disturbed Tracks & Teal Residue"
@export var inspection_dialogue: String = "Deep claw furrows and faint teal crystal residue lead south toward the broken shelter."

var _beacon: MeshInstance3D
var _revealed: bool = false

func _ready() -> void:
	add_to_group("scannable_clue")
	
	# Default small ground indicator
	_build_visuals()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _build_visuals() -> void:
	# Small ground decal/marker
	var marker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	marker.mesh = quad
	marker.rotation_degrees.x = -90
	marker.position.y = 0.04
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 0.65, 0.35) # Faint teal
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	add_child(marker)
	
	# Vertical beacon (starts hidden until revealed by scan)
	_beacon = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.2
	cylinder.height = 2.5
	_beacon.mesh = cylinder
	_beacon.position.y = 1.25
	
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(0.2, 0.85, 0.75, 0.8)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(0.2, 0.85, 0.75)
	beacon_mat.emission_energy_multiplier = 3.0
	beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon.material_override = beacon_mat
	_beacon.visible = false
	add_child(_beacon)
	
	# Area collision
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	col.shape = sphere
	add_child(col)

func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	if is_instance_valid(_beacon):
		_beacon.visible = true
		var tween := _beacon.create_tween()
		tween.tween_property(_beacon, "scale:y", 1.2, 0.3).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(_beacon, "scale:y", 1.0, 0.2)

func inspect() -> Dictionary:
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression != null:
		progression.complete_milestone("clue_" + clue_id)
		
	inspected.emit(clue_id)
	return {"success": true, "message": inspection_dialogue}

func is_revealed() -> bool:
	return _revealed

func _on_body_entered(body: Node3D) -> void:
	if body is Player3D:
		add_to_group("active_inspectable")

func _on_body_exited(body: Node3D) -> void:
	if body is Player3D:
		remove_from_group("active_inspectable")
