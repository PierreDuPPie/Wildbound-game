extends Node3D
class_name CameraRig

enum CameraMode { PERSPECTIVE, ORTHOGRAPHIC }

@export var target: Node3D
@export var follow_speed: float = 5.0
@export var camera_distance: float = 18.0
@export var camera_height: float = 10.0
@export var camera_angle: float = -48.0
@export var fov: float = 44.0
@export var camera_bounds: Rect2 = Rect2() # Optional (x_min, z_min, width, depth)

var _spring_arm: SpringArm3D
var _camera: Camera3D
var _current_mode: CameraMode = CameraMode.PERSPECTIVE

# Track faded meshes: Dictionary of MeshInstance3D -> float (target_alpha)
var _faded_meshes: Dictionary = {}

func _ready() -> void:
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = camera_distance
	_spring_arm.margin = 0.5
	# Mask 0 prevents foliage/props from violently snapping camera in
	_spring_arm.collision_mask = 0 
	add_child(_spring_arm)
	
	_camera = Camera3D.new()
	_camera.fov = fov
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.current = true
	_spring_arm.add_child(_camera)
	
	# Initial orientation
	_spring_arm.rotation_degrees.x = camera_angle
	position.y = camera_height / 10.0

func _process(delta: float) -> void:
	var controls_enabled := is_instance_valid(target) and bool(target.get("movement_enabled"))
	if controls_enabled and Input.is_action_just_pressed("camera_toggle"):
		_toggle_camera_mode()
		
	if is_instance_valid(target):
		var target_pos := target.global_position
		target_pos.y += (camera_height * 0.1) 
		
		# Clamp target position if camera bounds are defined
		if camera_bounds.size != Vector2.ZERO:
			target_pos.x = clampf(target_pos.x, camera_bounds.position.x, camera_bounds.position.x + camera_bounds.size.x)
			target_pos.z = clampf(target_pos.z, camera_bounds.position.y, camera_bounds.position.y + camera_bounds.size.y)
		
		global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))
		var speed_feedback := 0.0
		if target.has_method("is_sprinting") and target.call("is_sprinting"):
			speed_feedback = 2.5
		if target.has_method("is_flying") and target.call("is_flying"):
			speed_feedback += 3.0
			if "velocity" in target:
				var ascent_rate = clampf(target.velocity.y, 0.0, 5.0)
				speed_feedback += ascent_rate * 1.2
		_camera.fov = lerpf(_camera.fov, fov + speed_feedback, 1.0 - exp(-3.0 * delta))
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, camera_distance + speed_feedback * 0.45, 1.0 - exp(-3.0 * delta))
		
		# Orient spring arm to look down at correct angle
		_spring_arm.rotation_degrees.x = camera_angle
		if not _camera.global_position.is_equal_approx(global_position):
			_camera.look_at(global_position)
		
		_process_obstructions(delta)

func _process_obstructions(delta: float) -> void:
	if not is_instance_valid(target) or not _camera:
		return
		
	var space_state := get_world_3d().direct_space_state
	var from_pos := _camera.global_position
	var to_pos := target.global_position + Vector3(0, 0.7, 0) # Target player head
	
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var exclude_rids: Array[RID] = []
	if target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())
	query.exclude = exclude_rids
	
	var hit := space_state.intersect_ray(query)
	var currently_hit_meshes: Array[MeshInstance3D] = []
	
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node:
			currently_hit_meshes = _find_fadeable_meshes(collider as Node)
	
	# Mark hit meshes for fading (target 0.25 alpha)
	for mesh in currently_hit_meshes:
		if not _faded_meshes.has(mesh) and mesh.material_override is StandardMaterial3D:
			# Each occluded object needs its own material, even when scenery shares one.
			mesh.material_override = mesh.material_override.duplicate()
		_faded_meshes[mesh] = 0.25
	
	# Update all active faded meshes smoothly
	# An untyped list can retain freed dictionary keys until they are erased.
	var to_remove: Array = []
	for mesh in _faded_meshes.keys():
		if not is_instance_valid(mesh):
			to_remove.append(mesh)
			continue
			
		var target_alpha: float = 0.25 if currently_hit_meshes.has(mesh) else 1.0
		var mat = mesh.material_override
		if mat is StandardMaterial3D:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var current_a: float = mat.albedo_color.a
			mat.albedo_color.a = move_toward(current_a, target_alpha, delta * 3.5)
			
			if target_alpha == 1.0 and mat.albedo_color.a >= 0.98:
				mat.albedo_color.a = 1.0
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				to_remove.append(mesh)
				
	for rem in to_remove:
		_faded_meshes.erase(rem)

func _find_fadeable_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node.is_in_group("camera_fadeable") or _is_fadeable_name(node.name)):
		result.append(node as MeshInstance3D)
	
	# Stop before the world root: the old ascent faded every tree in the route.
	var root_entity: Node = node
	var world_root: Node = target.get_parent() if is_instance_valid(target) else get_tree().current_scene
	while root_entity and root_entity != world_root and root_entity != get_tree().current_scene:
		if root_entity.name == "Exploration":
			break
		_gather_fadeables(root_entity, result)
		if not result.is_empty() or root_entity.has_meta("recipe_id"):
			break
		root_entity = root_entity.get_parent()
	return result

func _gather_fadeables(node: Node, out_arr: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node.is_in_group("camera_fadeable") or _is_fadeable_name(node.name)):
		if not out_arr.has(node):
			out_arr.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather_fadeables(child, out_arr)

func _is_fadeable_name(n: String) -> bool:
	var lower := n.to_lower()
	return lower.contains("crown") or lower.contains("canopy") or lower.contains("leaf") or lower.contains("roof") or lower.contains("tree")

func _toggle_camera_mode() -> void:
	if _current_mode == CameraMode.PERSPECTIVE:
		_current_mode = CameraMode.ORTHOGRAPHIC
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = 23.0
	else:
		_current_mode = CameraMode.PERSPECTIVE
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = fov
