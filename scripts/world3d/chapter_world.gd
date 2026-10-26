extends Node3D
## Chapter set dressing and interactions. ProgressionManager owns every durable fact.
const ACTOR = preload("res://scripts/world3d/creature_actor_3d.gd")
const NPC = preload("res://scripts/world3d/npc_actor_3d.gd")
var exploration: Node3D
var markers: Array[Dictionary] = []
var obstacle: Node3D
var guest: CreatureInstance
var guest_visual: Node3D
var resonance_visual: MeshInstance3D
var _pages: Array = []
var _page_index := 0
var _finish_event := ""
var _pending_nuisance := false
var _audio: AudioStreamPlayer
var _pulse_time := 0.0

func _ready() -> void:
	name = "Chapter"
	if exploration.zone_id == "sanctuary_town":
		_add_marker("ranger", "Ranger Dan · Chapter 1", Vector3(-11,0,4), "ranger")
		_add_marker("resonance", "Inspect the resonance stone", Vector3(-12,0,12), "stone")
	elif exploration.zone_id == "route_02_3d":
		_add_marker("injury", "Help the injured Pangolet", Vector3(-10,0,6), "pangolet")
		_add_marker("tracks", "Inspect strange tracks", Vector3(10,0,6), "tracks")
		var clue = preload("res://scripts/world3d/scannable_clue_3d.gd").new()
		clue.clue_id = "chapter_tracks"
		clue.position = Vector3(10,0,6)
		add_child(clue)
		_add_marker("evidence", "Inspect damaged shelter", Vector3(18,0,-14), "shelter")
		obstacle = preload("res://scripts/world3d/burrow_obstacle_3d.gd").new()
		obstacle.obstacle_id = "chapter_rockfall"
		obstacle.position = Vector3(18,0,-9)
		add_child(obstacle)
		obstacle.shattered.connect(func(_id):
			exploration.save_progress()
			exploration.hud.refresh())
		guest = CreatureInstance.create(preload("res://data/creatures/ratelit.tres"),5)
		guest_visual = _creature("ratelit", Vector3(16,0,-7))
	elif exploration.zone_id == "route_01_3d":
		var crossing = preload("res://scripts/world3d/sprint_crossing_3d.gd").new()
		crossing.position = Vector3(-8,0,10)
		crossing.destination_offset = Vector3(0,0,6)
		add_child(crossing)
	ProgressionManager.chapter_changed.connect(_refresh)
	_refresh()

func _creature(species_id: String, pos: Vector3) -> Node3D:
	var actor = ACTOR.new()
	actor.species = PartyManager.species_lookup()[StringName(species_id)]
	actor.position = pos
	add_child(actor)
	actor.set_physics_process(false)
	actor.collision_layer = 0
	actor.collision_mask = 0
	return actor

func _add_marker(id: String, title: String, pos: Vector3, kind: String) -> void:
	var node := Node3D.new()
	node.name = id.capitalize()
	node.position = pos
	add_child(node)
	if kind == "ranger":
		var person = NPC.new()
		person.npc_name = "Ranger Dan"
		person.position = pos
		exploration.zone.add_child(person)
		person.interacted.connect(func(_id): interact("ranger"))
	elif kind == "pangolet":
		var creature := _creature("pangolet",pos)
		creature.scale = Vector3.ONE * 0.85
	elif kind == "shelter":
		var roof := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.2,0.18,2.5)
		roof.mesh = box
		roof.position.y = 0.7
		roof.rotation.z = 0.3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("705332")
		roof.material_override = mat
		node.add_child(roof)
	else:
		var object := MeshInstance3D.new()
		var stone := SphereMesh.new()
		stone.radius = 0.32 if kind == "stone" else 0.12
		stone.height = 0.5 if kind == "stone" else 0.08
		object.mesh = stone
		object.position.y = 0.22 if kind == "stone" else 0.05
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("6bc5d0") if kind == "stone" else Color("b49358")
		if kind == "stone":
			mat.emission_enabled = true
			mat.emission = Color("3c9cba")
			resonance_visual = object
		object.material_override = mat
		node.add_child(object)
		if kind == "tracks":
			for i in range(1,6):
				var print_mesh := object.duplicate()
				print_mesh.position = Vector3(i*0.25,0.05,-i*0.45)
				node.add_child(print_mesh)
	var label := Label3D.new()
	label.text = title
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.pixel_size = 0.006
	label.modulate = Color("e2bc76")
	node.add_child(label)
	markers.append({"id":id,"node":node,"label":label})

func _process(delta: float) -> void:
	_pulse_time += delta
	if not ProgressionManager.chapter_complete() and exploration.player.movement_enabled:
		ProgressionManager.chapter_play_seconds += delta
	for marker: Dictionary in markers:
		marker.label.visible = marker.node.visible and marker.node.global_position.distance_to(exploration.player.global_position) < 12.0
	if is_instance_valid(guest_visual):
		guest_visual.visible = ProgressionManager.can_access("guest_ratelit")
	if is_instance_valid(resonance_visual):
		resonance_visual.scale = Vector3.ONE * (1.0 + sin(_pulse_time*3.0)*0.07)
	if _pending_nuisance and exploration.player.movement_enabled and not exploration.is_legacy_overlay_open() and exploration.hud.current_modal.is_empty():
		_pending_nuisance = false
		show_sequence("nuisance")
		ProgressionManager.complete_milestone("chapter_nuisance_seen")

func _refresh() -> void:
	for marker: Dictionary in markers:
		if marker.id == "resonance":
			marker.node.visible = ProgressionManager.can_access("resonance") and not ProgressionManager.chapter_complete()
			for structure: Dictionary in HomesteadManager.get_structures_for_zone("sanctuary_town"):
				if structure.recipe_id == "creature_shelter":
					var p: Dictionary = structure.position
					# Place outside the building's collision footprint.
					marker.node.position = resonance_position(Vector3(p.x,0,p.z))
					break
	if exploration.zone_id == "route_01_3d" and ProgressionManager.has_chapter_event("first_bond") and not ProgressionManager.is_milestone_completed("chapter_nuisance_seen"):
		_pending_nuisance = true

func nearest_marker() -> Dictionary:
	var found: Dictionary = {}
	var distance := 2.7
	for marker: Dictionary in markers:
		if not marker.node.visible: continue
		var d: float = marker.node.global_position.distance_to(exploration.player.global_position)
		if d < distance:
			distance = d
			found = marker
	return found

func get_prompt() -> String:
	var marker := nearest_marker()
	if not marker.is_empty(): return "E  " + str(marker.label.text)
	if is_instance_valid(obstacle) and obstacle.global_position.distance_to(exploration.player.global_position) < 4.0:
		return "G  Abilities · Ratelit's Burrow Breaker" if ProgressionManager.can_access("guest_ratelit") else "Help the injured Pangolet beside the bridge first."
	return ""

func try_interact() -> bool:
	var marker := nearest_marker()
	if marker.is_empty(): return false
	interact(marker.id)
	return true

func interact(id: String) -> void:
	if not exploration.player.movement_enabled: return
	match id:
		"ranger":
			if not ProgressionManager.has_chapter_event("arrival"): show_sequence("arrival","arrival")
			elif ProgressionManager.get_stage().id == "report": show_sequence("report","report")
			elif ProgressionManager.chapter_complete(): show_sequence("complete")
			else: exploration.zone.show_dialogue("Ranger Dan",ProgressionManager.get_active_objective())
		"injury":
			if not ProgressionManager.has_chapter_event("arrival"):
				exploration.zone.show_dialogue("Field Notes","A frightened Pangolet. Speak to Ranger Dan at Acacia Outpost before investigating.")
			elif not ProgressionManager.has_chapter_event("injured_helped"): show_sequence("injury","injured_helped")
			else: exploration.zone.show_dialogue("Field Notes","The Pangolet is breathing steadily. Follow the tracks across the bridge.")
		"tracks":
			if not ProgressionManager.has_chapter_event("arrival"): return
			show_sequence("tracks","tracks")
		"evidence":
			if not ProgressionManager.has_chapter_event("injured_helped") or not ProgressionManager.has_chapter_event("tracks") or not ProgressionManager.can_access("shelter_evidence"):
				exploration.zone.show_dialogue("Field Notes","Help the injured creature, inspect the tracks and clear the rockfall before entering this unstable shelter.")
			else: show_sequence("evidence","evidence")
		"resonance":
			if ProgressionManager.can_access("resonance"):
				_play_resonance()
				show_sequence("resonance","resonance")

func show_sequence(id: String, finish_event: String = "") -> void:
	_pages = ProgressionManager.get_dialogue(id)
	_page_index = 0
	_finish_event = finish_event
	if not _pages.is_empty(): _show_page()

func _show_page() -> void:
	var page: Array = _pages[_page_index]
	exploration.zone.show_dialogue(str(page[0]),str(page[1]))
	exploration.zone.dialogue_hint_label.text = "%d / %d · Continue" % [_page_index+1,_pages.size()]

## Called before legacy close_dialogue. True keeps the dialogue open on next page.
func advance_dialogue() -> bool:
	if _pages.is_empty(): return false
	_page_index += 1
	if _page_index < _pages.size():
		_show_page()
		return true
	_pages.clear()
	if not _finish_event.is_empty():
		ProgressionManager.record_chapter_event(_finish_event)
		_finish_event = ""
		if not exploration.save_progress():
			exploration.hud.toast("Progress is in memory. Saving failed; keep the game open and retry Save.",8)
	exploration.hud.refresh()
	return false

func get_guest() -> CreatureInstance:
	if exploration.zone_id == "route_02_3d" and ProgressionManager.can_access("guest_ratelit") and is_instance_valid(obstacle) and obstacle.global_position.distance_to(exploration.player.global_position) < 5:
		return guest
	return null

func _play_resonance() -> void:
	# A locally generated quiet chime; no network or external asset dependency.
	if is_instance_valid(_audio): _audio.queue_free()
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(22050*2)
	for i in range(22050):
		var t := float(i)/22050.0
		samples.encode_s16(i*2,int(sin(t*TAU*220.0)*sin(t*TAU*3.0)*exp(-t*4.0)*2800))
	wav.data = samples
	_audio = AudioStreamPlayer.new()
	_audio.stream = wav
	add_child(_audio)
	_audio.play()

func is_sequence_active() -> bool:
	return not _pages.is_empty()

func resonance_position(home: Vector3) -> Vector3:
	var toward_center := Vector3(-signf(home.x),0,0) if absf(home.x) > absf(home.z) else Vector3(0,0,-signf(home.z))
	if toward_center == Vector3.ZERO: toward_center = Vector3.FORWARD
	var offsets: Array[Vector3] = [toward_center,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]
	for offset: Vector3 in offsets:
		var point := home + offset*4.2
		if absf(point.x) > 20.5 or absf(point.z) > 25.0: continue
		var shape := SphereShape3D.new()
		shape.radius = 0.4
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = point + Vector3.UP*0.8
		query.exclude = [exploration.player.get_rid()]
		query.collide_with_areas = false
		if get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(): return point
	# The shelter footprint was validated clear; use its open doorway if all
	# outer spots are occupied. A story marker never adds a physical collider.
	return home + Vector3(0,0,-2.1)
