extends Control
var exploration: Node3D
var _panel_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(210, 165)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = preload("res://scripts/ui/frontier_theme.gd").panel(Color("162b29"))

func _draw() -> void:
	if exploration == null or exploration.player == null:
		return
	if _panel_style == null:
		_panel_style = preload("res://scripts/ui/frontier_theme.gd").panel(Color("162b29"))
	var area := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
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
	var stage: Dictionary = ProgressionManager.get_stage()
	if stage.get("zone", "") == exploration.zone_id:
		var p: Array = stage.get("position", [0,0,0])
		var goal := Vector3(p[0],p[1],p[2])
		if is_instance_valid(exploration.chapter):
			for marker: Dictionary in exploration.chapter.markers:
				if marker.id == stage.get("target", ""): goal = marker.node.global_position
		var point := _point(goal, bounds, area)
		draw_circle(point,6,Color("e2bc76"))
		draw_arc(point,9,0,TAU,24,Color("e2bc76"),1,true)
	draw_circle(player_pos, 5.0, Color("f3efdf"))
	draw_arc(player_pos, 9, 0, TAU, 24, Color("f3efdf"), 1.0, true)

func _point(pos: Vector3, bounds: Rect2, area: Rect2) -> Vector2:
	var normalized := (Vector2(pos.x, pos.z) - bounds.position) / bounds.size
	return area.position + normalized * area.size
