extends Node
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	for entry in [["sanctuary_town","acacia_outpost_3d","_on_backpack_pressed","_on_menu_pressed"],["route_01_3d","route_01_3d","toggle_backpack","toggle_system_menu"],["route_02_3d","route_02_3d","toggle_backpack","toggle_system_menu"]]:
		var zone = load("res://scenes/world3d/%s.tscn" % entry[1]).instantiate()
		add_child(zone)
		var exploration = preload("res://scripts/world3d/exploration_layer.gd").new()
		exploration.zone_id = entry[0]
		exploration.zone = zone
		exploration.player = zone.player
		zone.add_child(exploration)
		await get_tree().process_frame
		exploration.chapter.show_sequence("arrival", "arrival")
		zone.call(entry[2])
		check(zone.dialogue_panel.visible and not zone.backpack_ui.visible and exploration.chapter._page_index == 0, "%s backpack cannot interrupt chapter" % entry[0])
		zone.call(entry[3])
		check(zone.dialogue_panel.visible and not zone.system_menu_ui.visible and exploration.chapter._page_index == 0, "%s menu cannot interrupt chapter" % entry[0])
		check(not zone.player.movement_enabled, "%s movement stays disabled during chapter" % entry[0])
		exploration.hud.open_abilities()
		check(exploration.hud.current_modal.is_empty(), "%s abilities cannot interrupt chapter" % entry[0])
		while exploration.chapter.is_sequence_active(): zone.close_dialogue()
		check(not zone.dialogue_panel.visible and zone.player.movement_enabled, "%s final page restores movement" % entry[0])
		zone.call(entry[2])
		check(zone.backpack_ui.visible, "%s backpack opens after chapter sequence" % entry[0])
		zone.backpack_ui.close()
		zone.queue_free()
		await get_tree().process_frame
	print("Chapter input regression: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
