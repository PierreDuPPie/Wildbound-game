extends Control
var exploration: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(210, 165)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if exploration == null or exploration.player == null:
		return
	var area := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	draw_style_box(preload("res://scripts/ui/frontier_theme.gd").panel(Color("162b29")), Rect2(Vector2.ZERO, size))
	var bounds: Rect2 = exploration.homestead.ZONE_BOUNDS[exploration.zone_id]
	for i in range(1, 4):
		draw_line(Vector2(area.position.x + area.size.x * i / 4.0, area.position.y), Vector2(area.position.x + area.size.x * i / 4.0, area.end.y), Color("2a433b"))
		draw_line(Vector2(area.position.x, area.position.y + area.size.y * i / 4.0), Vector2(area.end.x, area.position.y + area.size.y * i / 4.0), Color("2a433b"))
	for entry: Dictionary in exploration.resource_nodes:
		if not exploration.homestead.is_node_collected(entry["id"]):
			draw_circle(_point(entry["position"], bounds, area), 3.0, Color("83b48c") if entry["resource"] != "crystals" else Color("92dbe0"))
	for structure: Dictionary in exploration.homestead.get_structures_for_zone(exploration.zone_id):
		var pos: Dictionary = structure["position"]
		draw_rect(Rect2(_point(Vector3(pos["x"], 0, pos["z"]), bounds, area) - Vector2(3,3), Vector2(6,6)), Color("e2bc76"))
	var player_pos: Vector2 = _point(exploration.player.global_position, bounds, area)
	draw_circle(player_pos, 5.0, Color("f3efdf"))
	draw_arc(player_pos, 9, 0, TAU, 24, Color("f3efdf"), 1.0, true)

func _point(pos: Vector3, bounds: Rect2, area: Rect2) -> Vector2:
	var normalized := (Vector2(pos.x, pos.z) - bounds.position) / bounds.size
	return area.position + normalized * area.size
