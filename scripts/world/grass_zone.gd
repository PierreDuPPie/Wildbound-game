class_name GrassEncounterZone
extends Area2D

@export var grass_color := Color(0.23, 0.42, 0.16, 0.88)

func _ready() -> void:
    queue_redraw()

func _draw() -> void:
    var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if shape_node == null or not (shape_node.shape is RectangleShape2D):
        return
    var rect_shape := shape_node.shape as RectangleShape2D
    var rect := Rect2(-rect_shape.size * 0.5, rect_shape.size)
    draw_rect(rect, grass_color)
    var spacing := 18
    for x in range(int(rect.position.x) + 8, int(rect.end.x), spacing):
        for y in range(int(rect.position.y) + 10, int(rect.end.y), spacing):
            draw_line(Vector2(x, y+5), Vector2(x+4, y-5), Color(0.56,0.66,0.25,0.9), 2)
            draw_line(Vector2(x, y+5), Vector2(x-4, y-3), Color(0.46,0.59,0.2,0.9), 2)
