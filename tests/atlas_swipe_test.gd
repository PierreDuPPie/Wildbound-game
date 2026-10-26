extends Node
var failed := 0
var passed := 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if ok: passed += 1
	else: failed += 1
func frames(n := 4) -> void:
	for i in range(n): await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	get_viewport().push_input(e, true)
	await frames(2)
func swipe(from: Vector2, to: Vector2) -> void:
	await touch(from,true)
	for i in range(1,9):
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = from.lerp(to,float(i)/8)
		e.relative = (to-from)/8
		e.velocity = (to-from)*5
		get_viewport().push_input(e, true)
		await frames(2)
	await touch(to,false)
	await frames(4)
func run() -> void:
	get_window().size = Vector2i(844,390)
	SaveManager.save_path = "res://.qa/swipe-test-%d.json" % Time.get_ticks_usec()
	MobileControls.set_mode("touch")
	var boot = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(boot)
	await frames(30)
	var hud = boot.active_scene.get_node("Exploration").hud
	hud.open_atlas()
	await frames(12)
	var list: ScrollContainer = hud._atlas_list_scroll
	check(list.visible and not hud._atlas_detail_panel.visible,"Phone starts with an unobstructed species list")
	check(list.size.y > 60 and list.get_global_rect().end.y <= 540,"Species list fits the phone viewport")
	var selected: String = hud._atlas_selected_id
	var rect := list.get_global_rect()
	await swipe(rect.position+Vector2(rect.size.x*0.5,rect.size.y-12),rect.position+Vector2(rect.size.x*0.5,12))
	check(list.scroll_vertical > 20,"Genuine finger drag scrolls species content")
	check(hud._atlas_selected_id == selected,"Swiping across species buttons does not select a creature")
	# Tap the first visible species and confirm dossier opens.
	list.scroll_vertical = 0
	await frames()
	var button: Button = list.get_node("AtlasListVBox").get_child(1)
	var center := button.get_global_rect().get_center()
	await touch(center,true)
	await touch(center,false)
	check(hud._atlas_view == "dossier","A normal finger tap opens the selected dossier")
	await frames()
	check(hud._atlas_detail_panel.visible and not list.visible,"Dossier has the phone body to itself")
	var detail: ScrollContainer = hud._atlas_detail_box.get_parent()
	rect = detail.get_global_rect()
	check(rect.size.y > 100 and rect.end.y <= 540,"Dossier fits phone and leaves room for swiping")
	await swipe(rect.position+Vector2(rect.size.x*0.5,rect.size.y-20),rect.position+Vector2(rect.size.x*0.5,20))
	check(detail.scroll_vertical > 40,"Finger drag on dossier cards scrolls biological and combat details")
	hud._show_atlas_view("list")
	await frames()
	check(list.visible,"Creatures tab returns to list")
	var realm: ScrollContainer = hud._atlas_toolbar.get_child(0)
	rect = realm.get_global_rect()
	var realm_before: String = hud._atlas_realm
	await swipe(rect.position+Vector2(rect.size.x-20,rect.size.y/2),rect.position+Vector2(20,rect.size.y/2))
	check(realm.scroll_horizontal > 50,"Continent strip supports horizontal finger swipes")
	check(hud._atlas_realm == realm_before,"Swiping continent buttons does not change continent")
	hud.close_modal()
	MobileControls.set_mode("desktop")
	hud.open_atlas()
	await frames()
	check(hud._atlas_list_scroll.visible and hud._atlas_detail_panel.visible,"Desktop retains list and dossier together")
	check(hud._atlas_list_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,"Desktop retains normal scrollbar and wheel behavior")
	print("ATLAS SWIPE TEST: %d passed, %d failed" % [passed,failed])
	get_tree().quit(0 if failed == 0 else 1)
