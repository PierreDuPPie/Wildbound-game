extends Node3D
## A cosmetic presence proxy; it cannot collide, trigger encounters or mutate
## the local world. Only NetworkManager's host snapshots drive this object.

var _target: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _initialized: bool = false
var _name_label: Label3D

func _ready() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#76aab1")
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 0.95
	capsule.material = body_material
	body.mesh = capsule
	body.position.y = 0.8
	add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("#d9ad83")
	sphere.material = head_material
	head.mesh = sphere
	head.position.y = 1.46
	add_child(head)
	_name_label = Label3D.new()
	_name_label.position.y = 2.05
	_name_label.font_size = 32
	_name_label.pixel_size = 0.008
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.outline_size = 7
	_name_label.modulate = Color("#dbf2f4")
	add_child(_name_label)

func set_presence(player: Dictionary) -> void:
	_target = player.get("position", Vector3.ZERO)
	_target_yaw = float(player.get("yaw", 0.0))
	if _name_label:
		_name_label.text = str(player.get("name", "Friend"))
	if not _initialized or global_position.distance_to(_target) > 12.0:
		global_position = _target
		rotation.y = _target_yaw
		_initialized = true

func _process(delta: float) -> void:
	global_position = global_position.lerp(_target, 1.0 - exp(-14.0 * delta))
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-14.0 * delta))
