class_name EncounterZone
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.set_in_grass(true)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.set_in_grass(false)
