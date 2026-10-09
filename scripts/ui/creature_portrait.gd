class_name CreaturePortrait
extends Control

var species_id: StringName = &"unknown"
var facing_left := true
var mood: StringName = &"idle"

func set_creature(id: StringName, face_left: bool) -> void:
	species_id = id
	facing_left = face_left
	queue_redraw()

func set_mood(value: StringName) -> void:
	mood = value
	queue_redraw()

func _draw() -> void:
	var flip := -1.0 if facing_left else 1.0
	var center := size * 0.5
	# Scale is approx 3.5x
	var s := 3.5
	draw_circle(center + Vector2(0, 34*s), 46.0*s, Color(0.08, 0.1, 0.08, 0.22))
	match species_id:
		&"ratelit": _draw_ratelit(center, flip, s)
		&"meerkit": _draw_meerkit(center, flip, s)
		&"pangolet": _draw_pangolet(center, flip, s)
		&"lionet": _draw_lionet(center, flip, s)
		&"cheetan": _draw_cheetan(center, flip, s)
		&"hyenox": _draw_hyenox(center, flip, s)
		&"elephunt": _draw_elephunt(center, flip, s)
		&"crocodyl": _draw_crocodyl(center, flip, s)
		&"jackalin": _draw_jackalin(center, flip, s)
		&"zebrafly": _draw_zebrafly(center, flip, s)
		&"warthusk": _draw_warthusk(center, flip, s)
		&"hippotam": _draw_hippotam(center, flip, s)
		&"ostrichy": _draw_ostrichy(center, flip, s)
		_: _draw_unknown(center, s)

func _draw_ratelit(c: Vector2, flip: float, s: float) -> void:
	var dark := Color("#24282a")
	var pale := Color("#d7d1bc")
	var accent := Color("#a86c36") if mood != &"defiance" else Color("#e8a842")
	draw_circle(c + Vector2(-10 * flip * s, 4 * s), 38 * s, dark)
	draw_circle(c + Vector2(28 * flip * s, -8 * s), 25 * s, dark)
	draw_polygon(PackedVector2Array([
		c+Vector2(5*flip*s, -24*s), 
		c+Vector2(42*flip*s, -28*s), 
		c+Vector2(30*flip*s, 0), 
		c+Vector2(-24*flip*s, -8*s)
	]), PackedColorArray([pale, pale, pale, pale]))
	draw_circle(c + Vector2(34 * flip * s, -12 * s), 4.5 * s, Color("#f4efdc"))
	draw_circle(c + Vector2(35 * flip * s, -12 * s), 2.2 * s, Color("#111111"))
	draw_circle(c + Vector2(53 * flip * s, -2 * s), 6 * s, Color("#111111"))
	draw_line(c+Vector2(8*flip*s, -17*s), c+Vector2(31*flip*s, -21*s), accent, 4 * s)
	draw_line(c+Vector2(-22*flip*s, 29*s), c+Vector2(-35*flip*s, 43*s), dark, 9 * s)
	draw_line(c+Vector2(6*flip*s, 34*s), c+Vector2(0*flip*s, 48*s), dark, 9 * s)
	if mood == &"defiance":
		draw_arc(c, 58 * s, 0, TAU, 32, Color(1.0, 0.68, 0.18, 0.75), 4 * s)

func _draw_meerkit(c: Vector2, flip: float, s: float) -> void:
	var tan_col := Color("#d9ad62")
	var dark := Color("#413326")
	draw_circle(c + Vector2(0, 10 * s), 31 * s, tan_col)
	draw_circle(c + Vector2(20 * flip * s, -24 * s), 24 * s, tan_col)
	draw_polygon(PackedVector2Array([
		c+Vector2(8*flip*s, -44*s),
		c+Vector2(14*flip*s, -65*s),
		c+Vector2(22*flip*s, -45*s)
	]), PackedColorArray([dark, dark, dark]))
	draw_polygon(PackedVector2Array([
		c+Vector2(28*flip*s, -45*s),
		c+Vector2(39*flip*s, -62*s),
		c+Vector2(42*flip*s, -38*s)
	]), PackedColorArray([dark, dark, dark]))
	draw_circle(c + Vector2(27*flip*s, -28*s), 6 * s, Color("#f5f0dc"))
	draw_circle(c + Vector2(28*flip*s, -28*s), 3 * s, dark)
	draw_line(c+Vector2(-22*flip*s, 25*s), c+Vector2(-42*flip*s, 55*s), dark, 8 * s)
	draw_line(c+Vector2(0, 35*s), c+Vector2(-2*flip*s, 55*s), dark, 7 * s)

func _draw_pangolet(c: Vector2, flip: float, s: float) -> void:
	var base := Color("#b89162")
	var plate := Color("#6f6659")
	draw_circle(c, 40 * s, base)
	for i in range(5):
		draw_arc(c+Vector2((-20+i*10)*flip*s, -8*s+i*4*s), (24-i*2)*s, -1.3, 1.4, 12, plate, 7 * s)
	draw_circle(c + Vector2(33*flip*s, -8*s), 20 * s, base)
	draw_circle(c + Vector2(39*flip*s, -12*s), 3.5 * s, Color("#171717"))
	draw_line(c+Vector2(48*flip*s, -2*s), c+Vector2(62*flip*s, 6*s), plate, 5 * s)
	draw_line(c+Vector2(-22*flip*s, 30*s), c+Vector2(-30*flip*s, 49*s), plate, 8 * s)

func _draw_lionet(c: Vector2, flip: float, s: float) -> void:
	var mane := Color("#e3a632")
	var body := Color("#c48b2b")
	draw_circle(c, 42 * s, mane)
	draw_circle(c, 30 * s, body)
	draw_circle(c + Vector2(10*flip*s, -5*s), 4*s, Color("#111111"))
	draw_circle(c + Vector2(24*flip*s, 5*s), 6*s, Color("#442211"))

func _draw_cheetan(c: Vector2, flip: float, s: float) -> void:
	var body := Color("#d6b265")
	var spots := Color("#2b2216")
	draw_circle(c + Vector2(0, 10*s), 30*s, body)
	draw_circle(c + Vector2(25*flip*s, -15*s), 22*s, body)
	draw_circle(c + Vector2(30*flip*s, -20*s), 3*s, spots)
	draw_circle(c + Vector2(-10*flip*s, 15*s), 4*s, spots)
	draw_circle(c + Vector2(5*flip*s, 25*s), 4*s, spots)
	draw_circle(c + Vector2(10*flip*s, 5*s), 4*s, spots)
	draw_circle(c + Vector2(40*flip*s, -10*s), 3*s, spots)

func _draw_hyenox(c: Vector2, flip: float, s: float) -> void:
	var body := Color("#968c78")
	var spots := Color("#36322b")
	draw_circle(c + Vector2(-5*flip*s, 15*s), 35*s, body)
	draw_circle(c + Vector2(20*flip*s, -10*s), 24*s, body)
	draw_circle(c + Vector2(32*flip*s, -12*s), 3*s, Color("#111111"))
	draw_line(c + Vector2(25*flip*s, 5*s), c + Vector2(40*flip*s, 10*s), spots, 4*s)
	draw_circle(c + Vector2(-10*flip*s, 10*s), 4*s, spots)
	draw_circle(c + Vector2(0, 25*s), 4*s, spots)

func _draw_elephunt(c: Vector2, flip: float, s: float) -> void:
	var skin := Color("#7e838c")
	var ear := Color("#696c73")
	draw_circle(c + Vector2(0, 5*s), 45*s, skin)
	draw_circle(c + Vector2(-10*flip*s, -5*s), 25*s, ear)
	draw_line(c + Vector2(25*flip*s, 15*s), c + Vector2(20*flip*s, 45*s), skin, 12*s)
	draw_circle(c + Vector2(20*flip*s, -5*s), 3*s, Color("#111111"))

func _draw_crocodyl(c: Vector2, flip: float, s: float) -> void:
	var scale_col := Color("#4f7547")
	draw_circle(c + Vector2(-10*flip*s, 10*s), 30*s, scale_col)
	draw_line(c + Vector2(10*flip*s, 10*s), c + Vector2(55*flip*s, 10*s), scale_col, 16*s)
	draw_circle(c + Vector2(25*flip*s, 2*s), 3*s, Color("#dcd339"))
	draw_line(c + Vector2(15*flip*s, 18*s), c + Vector2(50*flip*s, 18*s), Color("#e6e4d5"), 3*s)

func _draw_jackalin(c: Vector2, flip: float, s: float) -> void:
	var fur := Color("#b38c52")
	var dark := Color("#221c15")
	draw_circle(c + Vector2(-5*flip*s, 15*s), 28*s, fur)
	draw_circle(c + Vector2(22*flip*s, -15*s), 20*s, fur)
	draw_polygon(PackedVector2Array([
		c+Vector2(15*flip*s, -30*s), c+Vector2(10*flip*s, -55*s), c+Vector2(5*flip*s, -30*s)
	]), PackedColorArray([dark, dark, dark]))
	draw_circle(c + Vector2(28*flip*s, -18*s), 2.5*s, Color("#111111"))
	draw_line(c + Vector2(35*flip*s, -5*s), c + Vector2(45*flip*s, -2*s), dark, 4*s)

func _draw_zebrafly(c: Vector2, flip: float, s: float) -> void:
	var body := Color("#ffffff")
	var stripe := Color("#1a1a1a")
	draw_circle(c + Vector2(0, 10*s), 32*s, body)
	draw_circle(c + Vector2(24*flip*s, -15*s), 22*s, body)
	draw_circle(c + Vector2(28*flip*s, -18*s), 3*s, Color("#111"))
	draw_line(c + Vector2(-15*flip*s, -15*s), c + Vector2(-5*flip*s, 20*s), stripe, 5*s)
	draw_line(c + Vector2(5*flip*s, -20*s), c + Vector2(12*flip*s, 15*s), stripe, 4*s)
	draw_line(c + Vector2(20*flip*s, -32*s), c + Vector2(25*flip*s, -25*s), stripe, 3*s)

func _draw_warthusk(c: Vector2, flip: float, s: float) -> void:
	var skin := Color("#87766b")
	var tusk := Color("#e8e1cc")
	draw_circle(c + Vector2(-5*flip*s, 10*s), 35*s, skin)
	draw_circle(c + Vector2(25*flip*s, -5*s), 25*s, skin)
	draw_circle(c + Vector2(25*flip*s, -10*s), 2*s, Color("#111"))
	draw_line(c + Vector2(35*flip*s, 5*s), c + Vector2(45*flip*s, 10*s), skin, 12*s)
	draw_line(c + Vector2(40*flip*s, 10*s), c + Vector2(45*flip*s, -5*s), tusk, 4*s)

func _draw_hippotam(c: Vector2, flip: float, s: float) -> void:
	var skin := Color("#73697a")
	draw_circle(c + Vector2(-10*flip*s, 5*s), 40*s, skin)
	draw_circle(c + Vector2(25*flip*s, 0), 30*s, skin)
	draw_circle(c + Vector2(30*flip*s, -15*s), 2.5*s, Color("#111"))
	draw_circle(c + Vector2(45*flip*s, 5*s), 8*s, skin)

func _draw_ostrichy(c: Vector2, flip: float, s: float) -> void:
	var feather := Color("#2d2c33")
	var neck := Color("#e8b6b1")
	draw_circle(c + Vector2(-10*flip*s, 25*s), 30*s, feather)
	draw_line(c + Vector2(5*flip*s, 10*s), c + Vector2(15*flip*s, -30*s), neck, 8*s)
	draw_circle(c + Vector2(15*flip*s, -30*s), 10*s, neck)
	draw_circle(c + Vector2(18*flip*s, -32*s), 2*s, Color("#111"))
	draw_line(c + Vector2(22*flip*s, -30*s), c + Vector2(32*flip*s, -28*s), Color("#d18836"), 4*s)

func _draw_unknown(c: Vector2, s: float) -> void:
	draw_circle(c, 42 * s, Color("#777777"))
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-10*s, 8*s), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s), Color.WHITE)
