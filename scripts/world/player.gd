class_name Player
extends CharacterBody2D

const SPEED = 200.0

signal encounter_triggered

var _distance_in_grass: float = 0.0
var _in_grass: bool = false

func _physics_process(delta: float) -> void:
	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")
	
	# Explicitly check WASD in case project map doesn't have them
	if Input.is_key_pressed(KEY_A): dir_x -= 1.0
	if Input.is_key_pressed(KEY_D): dir_x += 1.0
	if Input.is_key_pressed(KEY_W): dir_y -= 1.0
	if Input.is_key_pressed(KEY_S): dir_y += 1.0
	
	var direction := Vector2(dir_x, dir_y).clamp(Vector2(-1, -1), Vector2(1, 1)).normalized()
	velocity = direction * SPEED
	
	var moved := velocity.length() * delta
	if moved > 0.0 and _in_grass:
		_distance_in_grass += moved
		if _distance_in_grass > 50.0:
			_distance_in_grass = 0.0
			if randf() < 0.10: # 10% chance every 50 pixels
				encounter_triggered.emit()
				
	move_and_slide()

func set_in_grass(state: bool) -> void:
	_in_grass = state
	if not _in_grass:
		_distance_in_grass = 0.0
