class_name HazardVolume3D extends Area3D

## Layer 2 World Bounds Defense
## Placed over water, pits, or out-of-bounds regions.
## Detects any player body entering and immediately recovers them to their last safe position.

@export var hazard_type: StringName = &"water"
@export var custom_respawn_point: Vector3 = Vector3.ZERO
@export var use_custom_respawn: bool = false

func _ready() -> void:
	# Ensure monitorable and monitoring are enabled
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body != null and body.has_method("recover_to_safe_position"):
		if use_custom_respawn and custom_respawn_point != Vector3.ZERO:
			body.global_position = custom_respawn_point
			if "velocity" in body:
				body.velocity = Vector3.ZERO
		else:
			body.recover_to_safe_position()
