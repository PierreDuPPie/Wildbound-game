class_name WildkeeperPlayer
extends CharacterBody2D

signal grid_step

@export var move_speed := 190.0
var movement_enabled := true
var _distance_since_step := 0.0
const WORLD_BOUNDS := Rect2(40, 40, 1520, 820)

func _ready() -> void:
    queue_redraw()

func _physics_process(_delta: float) -> void:
    if not movement_enabled:
        velocity = Vector2.ZERO
        return
    var direction := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1.0
    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    velocity = direction * move_speed
    var before := global_position
    move_and_slide()
    global_position.x = clampf(global_position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
    global_position.y = clampf(global_position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)
    _distance_since_step += before.distance_to(global_position)
    while _distance_since_step >= 32.0:
        _distance_since_step -= 32.0
        grid_step.emit()

func _draw() -> void:
    draw_circle(Vector2(0, 14), 14, Color(0.05,0.08,0.05,0.25))
    draw_rect(Rect2(-9,-12,18,24), Color("#315b72"))
    draw_circle(Vector2(0,-17), 9, Color("#d1a06d"))
    draw_rect(Rect2(-12,-28,24,7), Color("#d7b43e"))
    draw_line(Vector2(-6,12), Vector2(-7,22), Color("#222222"), 5)
    draw_line(Vector2(6,12), Vector2(7,22), Color("#222222"), 5)
