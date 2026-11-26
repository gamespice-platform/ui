extends "selftest_base.gd"

## The crosshair, stat bar and ids sections of ui_selftest.gd, split out to keep that file under the size gate.


func _crosshair_alive_checks() -> void:
	var c := GSCrosshair.new()
	add_child(c)
	_check(c.is_shown(), "a crosshair is shown by default")
	var alive := [false]
	c.alive_source = func() -> bool: return alive[0]
	c._process(0.016)
	_check(not c.is_shown(), "hidden while the alive source says dead")
	alive[0] = true
	c._process(0.016)
	_check(c.is_shown(), "shown again once alive")
	c.alive_source = Callable()
	c.set_alive(false)
	_check(not c.is_shown(), "set_alive(false) hides it")
	c.hide_when_dead = false
	_check(c.is_shown(), "hide_when_dead = false opts out")
	_check(c.describe().get("alive") == false, "describe reports alive")
	c.hold_progress = 2.0
	_close(c.hold_progress, 1.0, "hold_progress is clamped to 1")
	c.hold_progress = -1.0
	_close(c.hold_progress, 0.0, "and to 0")
	c.hold_progress = 0.5
	_close(float(c.describe().get("hold_progress", -1.0)), 0.5, "describe reports hold_progress")
	remove_child(c)
	c.free()


func _test_crosshair() -> void:
	_section("crosshair")
	_crosshair_alive_checks()

	var crosshair := GSCrosshair.new()
	crosshair.base_gap = 4.0
	crosshair.fov_degrees = 90.0
	crosshair.max_gap = 200.0
	crosshair.close_sec = 0.0
	crosshair.size = Vector2(1920.0, 1080.0)

	var spread := [0.0]
	crosshair.source = func() -> Variant: return spread[0]
	add_child(crosshair)
	crosshair.set_anchors_preset(Control.PRESET_TOP_LEFT)
	crosshair.size = Vector2(1920.0, 1080.0)

	_close(crosshair.gap_pixels(), 4.0, "zero spread sits at the base gap")

	spread[0] = 5.0
	crosshair.refresh()
	var wide := crosshair.gap_pixels()
	_check(wide > 4.0, "spread opens the crosshair", "%.1f" % wide)

	# The projection, not a made-up number: half the viewport height over the tangent
	# of half the field of view is the focal length in pixels.
	var focal := 540.0 / tan(deg_to_rad(90.0) * 0.5)
	_close(
		wide,
		4.0 + focal * tan(deg_to_rad(5.0)),
		"by the amount the camera projection actually gives",
		0.5
	)

	# A different field of view must give a different gap for the same spread. A
	# crosshair that assumes 90 is wrong at every other setting.
	crosshair.fov_degrees = 60.0
	var narrow := crosshair.gap_pixels()
	_check(
		narrow > wide,
		"a narrower field of view opens it further for the same angle",
		"%.1f vs %.1f" % [narrow, wide]
	)

	var ladder: Array[float] = []
	for deg: float in [0.5, 1.5, 3.5, 6.0]:
		spread[0] = deg
		crosshair.refresh()
		ladder.append(crosshair.gap_pixels())
	_check(ladder[0] < ladder[1] and ladder[1] < ladder[2] and ladder[2] < ladder[3], "the gap grows with every step of spread (still, walk, run, air)", str(ladder))

	spread[0] = 1.5
	crosshair.refresh()
	var usual := crosshair.gap_pixels()
	crosshair.gap_scale = 1.25
	_check(is_equal_approx(crosshair.gap_pixels(), minf(crosshair.max_gap, usual * 1.25)), "gap_scale multiplies the whole gap", "%.1f" % usual)
	crosshair.gap_scale = 1.0

	spread[0] = 80.0
	crosshair.refresh()
	_close(crosshair.gap_pixels(), 200.0, "and it is capped")

	_crosshair_ease_checks(crosshair)

	_crosshair_aim_checks(crosshair)

	_crosshair_cvar_checks(crosshair)

	crosshair.queue_free()
	remove_child(crosshair)
	_done()


func _crosshair_ease_checks(crosshair: GSCrosshair) -> void:
	crosshair.close_sec = 0.08
	crosshair.set_spread(1.0)
	crosshair.ease_spread(1.0)
	crosshair.set_spread(4.0)
	_close(crosshair.spread_shown(), 4.0, "a widening spread opens the gap at once (never tighter than the shots)")
	crosshair.set_spread(1.0)
	_close(crosshair.spread_shown(), 4.0, "a falling one does not snap shut")
	crosshair.ease_spread(0.08)
	_check(crosshair.spread_shown() > 1.0 and crosshair.spread_shown() < 2.5, "it closes about two thirds in close_sec", "%.2f" % crosshair.spread_shown())
	crosshair.ease_spread(1.0)
	_close(crosshair.spread_shown(), 1.0, "and lands on the spread")
	crosshair.close_sec = 0.0


func _crosshair_aim_checks(crosshair: GSCrosshair) -> void:
	# Aiming down the sights: the crosshair fades out, and back, never snaps.
	var aim := [0.0]
	crosshair.aim_source = func() -> float: return aim[0]
	crosshair.follow_aim(1.0)
	_close(crosshair.aim_opacity, 1.0, "at the hip the crosshair is all there")
	aim[0] = 1.0
	crosshair.follow_aim(0.016)
	_check(crosshair.aim_opacity > 0.0 and crosshair.aim_opacity < 1.0,
		"aiming fades it rather than snapping it off", "%.2f" % crosshair.aim_opacity)
	crosshair.follow_aim(1.0)
	_close(crosshair.aim_opacity, 0.0, "and fully aimed it is gone")
	_close(GSCrosshair.opacity_for_aim(0.25, 0.5), 0.5, "halfway to aim_hide_by it is half drawn")
	aim[0] = 0.0
	crosshair.follow_aim(0.016)
	_check(crosshair.aim_opacity < 1.0, "a released aim fades it back in too")
	crosshair.follow_aim(1.0)
	_close(crosshair.aim_opacity, 1.0, "and it returns whole")
	_close(GSCrosshair.opacity_for_aim(NAN), 1.0, "a NaN aim draws the crosshair rather than hiding it")


func _crosshair_cvar_checks(crosshair: GSCrosshair) -> void:
	var cvars := GSCrosshairCvars.new()
	cvars.target = crosshair
	var seen := {}
	var local := _FakeLocal.new(seen)
	_check(cvars.bind_console(local) and seen.has(&"cl_crosshair_gap") and seen.has(&"cl_crosshair_colour"), "every crosshair cvar is registered")
	(seen[&"cl_crosshair_gap"] as Callable).call("9")
	_close(crosshair.base_gap, 9.0, "a cvar reaches the widget")
	(seen[&"cl_crosshair_style"] as Callable).call("1")
	_check(not crosshair.top_arm, "style 1 is a T")
	(seen[&"cl_crosshair_style"] as Callable).call("2")
	_close(crosshair.length, 0.0, "style 2 is a dot")
	(seen[&"cl_crosshair_dynamic"] as Callable).call("0")
	crosshair.set_spread(5.0)
	_close(crosshair.gap_pixels(), 9.0, "a static crosshair ignores the spread")
	(seen[&"cl_crosshair_ease"] as Callable).call("0.2")
	_close(crosshair.close_sec, 0.2, "cl_crosshair_ease sets how the gap closes")
	(seen[&"cl_crosshair_colour"] as Callable).call("ff0000")
	_check(crosshair.colour.is_equal_approx(Color.RED), "colour is read from hex")
	var bad = (seen[&"cl_crosshair_size"] as Callable).call("x")
	_check(bad is GSResult and not (bad as GSResult).ok, "a bad value is refused")
	_hud_element_cvar_checks()


func _hud_element_cvar_checks() -> void:
	var cv := GSHudElementCvars.new()
	var seen := {}
	_check(cv.bind_console(_FakeLocal.new(seen)) and seen.has(&"cl_hud_show_perf") and seen.has(&"cl_hud_scale"), "every hud element cvar is registered")
	var panel := Control.new()
	var ammo := Control.new()
	_check(cv.attach(&"perf", panel) and cv.attach(&"ammo", ammo), "stock ids attach")
	_check(not cv.attach(&"bogus", ammo), "an unknown id is refused")
	_check(not panel.visible and ammo.visible, "perf is off by default, ammo on")
	(seen[&"cl_hud_show_perf"] as Callable).call("1")
	_check(panel.visible, "the cvar shows the perf panel")
	(seen[&"cl_hud_show_ammo"] as Callable).call("0")
	_check(not ammo.visible, "the cvar hides ammo")
	(seen[&"cl_hud_scale"] as Callable).call("9")
	_close(cv.scale, 2.0, "scale is clamped")
	var bad = (seen[&"cl_hud_show_wave"] as Callable).call("x")
	_check(bad is GSResult and not (bad as GSResult).ok, "a bad value is refused")
	panel.free()
	ammo.free()


class _FakeLocal:
	extends RefCounted
	var seen: Dictionary
	func _init(into: Dictionary) -> void:
		seen = into
	func add_var(name: StringName, _help: String, _get: Callable, set_it: Callable) -> void:
		seen[name] = set_it


func _test_stat_bar() -> void:
	_section("stat bar")

	var bar := GSStatBar.new()
	bar.max_value = 100.0
	bar.ease_sec = 0.0
	var health := [100.0]
	bar.source = func() -> Variant: return health[0]
	add_child(bar)

	_close(bar.fraction(), 1.0, "a full bar is full")

	health[0] = 25.0
	bar.refresh()
	_close(bar.fraction(), 0.25, "and follows the value")

	health[0] = -10.0
	bar.refresh()
	_close(bar.fraction(), 0.0, "a negative value clamps to empty")

	health[0] = 500.0
	bar.refresh()
	_close(bar.fraction(), 1.0, "and an overheal clamps to full")

	# A bar whose maximum changes: a magazine after a weapon switch.
	var magazine := [30.0]
	bar.max_source = func() -> Variant: return magazine[0]
	health[0] = 15.0
	bar.refresh()
	_close(bar.fraction(), 0.5, "a bound maximum is used")

	magazine[0] = 60.0
	bar.refresh()
	_close(bar.fraction(), 0.25, "and re-read when it changes")

	# The eased bar lags; the number must not.
	bar.ease_sec = 0.5
	health[0] = 60.0
	bar.refresh()
	_close(bar.fraction(), 1.0, "the reported fraction is the real value, not the eased one")

	bar.queue_free()
	remove_child(bar)
	_done()


func _registered_ids_checks() -> void:
	# registered_ids() must be alphabetical text, not StringName interning order.
	var order_stack := _make_stack()
	var made: Array[GSScreen] = []
	for n in ["zq_ids", "yq_ids", "xq_ids", "wq_ids", "vq_ids", "uq_ids", "tq_ids", "sq_ids"]:
		var sc := _make_screen(StringName(n))
		made.append(sc)
		order_stack.register(sc)
	var ids_listed := PackedStringArray()
	for sid in order_stack.registered_ids():
		ids_listed.append(String(sid))
	var ids_sorted := ids_listed.duplicate()
	ids_sorted.sort()
	_check(
		ids_listed == ids_sorted and ids_listed.size() == 8,
		"registered_ids() is sorted by text (%s)" % [ids_listed],
		"Array.sort() on StringNames orders by interning"
	)


func _test_icon_plate_and_status_lines() -> void:
	_section("weapon icon plate and status lines")

	var plate := _piece(GSWeaponIconPlate.new(), Rect2(0.0, 0.0, 400.0, 100.0)) as GSWeaponIconPlate
	_check(not plate.footprint().has_area(), "no sprite draws nothing")
	plate.show_icon(ImageTexture.create_from_image(Image.create(128, 32, false, Image.FORMAT_RGBA8)), &"rifle")
	_close(plate.icon_size().y, 37.5, "a wide sprite is capped by max_width, keeping its aspect")
	_check(is_equal_approx(plate.footprint().end.x, 400.0), "right-aligned to the control's edge")
	plate.show_icon(ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8)))
	_close(plate.icon_size().x, plate.icon_height, "a square sprite is icon_height wide")
	plate.clear()
	_check(not plate.footprint().has_area(), "clear() takes it down")

	var lines := _piece(GSStatusLines.new(), Rect2(0.0, 0.0, 300.0, 200.0)) as GSStatusLines
	lines.show_lines(["Down", {"text": "Haste x2  0:12", "colour": Color.RED}])
	_check(lines.texts() == PackedStringArray(["Down", "Haste x2  0:12"]), "strings and dictionaries both give words")
	_check(is_equal_approx(lines.footprint().size.y, 2.0 * lines.row_height), "a row per line")
	lines.align_right = true
	_check(is_equal_approx(lines.footprint().end.x, 300.0), "or to the right edge")
	lines.max_lines = 1
	lines.show_lines(["a", "b"])
	_check(lines.texts().size() == 1, "max_lines drops the rest")
	_check(GSStatusLines.effect_text("Haste", 2, 12.0) == "Haste x2  0:12", "a timed effect line")
	_check(GSStatusLines.effect_text("Haste", 1, -1.0) == "Haste  this round", "an endless one")
	lines.clear()
	_check(not lines.footprint().has_area(), "clear() takes the lines down")
	plate.queue_free()
	lines.queue_free()
	_done()


func _test_loadout_bar() -> void:
	_section("loadout bar")

	var tex := ImageTexture.create_from_image(Image.create(8, 4, false, Image.FORMAT_RGBA8))
	var bar := _piece(GSLoadoutBar.new(), Rect2(0.0, 0.0, 900.0, 120.0)) as GSLoadoutBar
	_check(bar.slot_count() == 0 and not bar.footprint().has_area(), "empty: nothing drawn")
	bar.set_slots([
		{"key": "1", "icon": tex, "text": "12 / 60", "selected": true},
		{"key": "2", "name": "KIT", "text": "2", "low": true, "accent": Color.GREEN, "fill": 0.4},
	])
	_check(bar.slot_count() == 2, "two slots in")
	var rect := bar.footprint()
	_close(rect.size.x, 2.0 * GSLoadoutBar.SLOT_W + GSLoadoutBar.GAP, "the row is two slots and a gap wide")
	_close(rect.end.x, bar.size.x, "the row stays anchored at the right")
	_close(rect.size.y, bar.size.y - GSLoadoutBar.WEIGHT_H, "no weight bar: the footprint skips its band")

	var picked := [{"key": "1", "selected": true}]
	bar.set_slots(picked)
	var kept: Array = bar._slots
	bar.set_slots([{"key": "1", "selected": true}])
	_check(bar._slots == kept, "an equal row is a no-op")
	_check(bar._lift.size() == 1, "one eased lift per slot")

	bar.set_weight(4.2, 10.0, 2, 3)
	_check(bar.weight_text() == "4.2 / 10.0" and bar.pack_text() == "PACK 2", "weight and pack lines")
	_close(bar.footprint().size.y, bar.size.y, "the weight band is part of the footprint")
	bar.set_weight(1.0, 0.0)
	_check(bar.weight_text() == "1.0 / 0.1", "a zero limit is held above zero")
	_check(bar.pack_text() == "", "no pack max, no pack line")
	bar.clear_weight()
	_close(bar.footprint().size.y, bar.size.y - GSLoadoutBar.WEIGHT_H, "clear_weight hides the band")

	bar._process(0.5)
	_check(bar._lift[0] > 0.9, "a selected slot lifts")
	bar.set_slots([])
	_check(bar.slot_count() == 0 and not bar.footprint().has_area(), "an empty row clears it")
	bar.queue_free()
	# STACK: plates up from the bottom, anchored right.
	var col := _piece(GSLoadoutBar.new(), Rect2(0.0, 0.0, 160.0, 202.0)) as GSLoadoutBar
	col.set_layout(GSLoadoutBar.Layout.STACK)
	col.set_slots([{"key": "1", "name": "A"}, {"key": "2", "name": "B", "selected": true}, {"key": "3", "name": "C"}])
	var stack := col.footprint()
	_close(stack.end.x, col.size.x + 4.0, "stack: plates end 4 past the control's right edge")
	_close(stack.size.y, 2.0 * col.stack_pitch + col.stack_pitch - GSLoadoutBar.STACK_GAP, "stack: three plates at the pitch")
	_close(stack.end.y, col.size.y - col.stack_foot + (col.stack_pitch - GSLoadoutBar.STACK_GAP) * 0.5, "stack: the bottom plate sits on the foot")
	col.set_stack_pitch(30.0)
	_close(col.footprint().size.y, 2.0 * 30.0 + 30.0 - GSLoadoutBar.STACK_GAP, "stack: a tighter pitch squeezes the column")
	col.set_slots([])
	_check(not col.footprint().has_area(), "stack: no slots, no footprint")
	col.queue_free()

	# BUTTONS: a centred row, cooldowns and pips drawn from values.
	var row := _piece(GSLoadoutBar.new(), Rect2(0.0, 0.0, 380.0, 90.0)) as GSLoadoutBar
	row.set_layout(GSLoadoutBar.Layout.BUTTONS)
	row.set_slots([
		{"key": "C", "name": "slide"},
		{"key": "E", "name": "launch", "left": 5.5, "total": 8.0},
		{"key": "Space", "name": "walljump", "pips": 1, "pips_max": 3, "active": true},
	])
	var buttons := row.footprint()
	var want := 3.0 * GSLoadoutBar.BUTTON_SIDE + 2.0 * GSLoadoutBar.BUTTON_GAP
	_close(buttons.size.x, want, "buttons: three buttons and two gaps wide")
	_close(buttons.get_center().x, row.size.x * 0.5, "buttons: centred")
	row.set_slots([])
	_check(not row.footprint().has_area(), "buttons: none, no footprint")
	row.queue_free()
	_done()


func _test_icon_style() -> void:
	_section("weapon icon style: tags, cvars, filter")
	var icons := GSWeaponIconStyle.new()
	icons.overrides_path = "user://no_such_weapon_icons.json"
	icons.tags = {&"my_gun": &"pistol", &"my_fist": &""}
	_check(icons.texture(&"my_gun") is AtlasTexture and icons.texture(&"my_gun") == icons.icon_set().texture_for(&"pistol"), "a mapped id draws its tag's sprite")
	_check(icons.texture(&"unmapped_thing") == null, "an unmapped id has no sprite")
	_check(icons.set_style(&"silhouette") and icons.texture(&"my_gun") == null, "silhouette gives no sprite")
	_check(not icons.set_style(&"bogus") and icons.style == &"silhouette", "an unknown style is refused and keeps the old one")
	var _back := icons.set_style(&"pixel")
	var seen := {}
	var local := _FakeLocal.new(seen)
	_check(icons.bind_console(local) and seen.has(&"cl_weapon_icons") and seen.has(&"cl_weapon_icon_profile"), "bind_console registers both cvars")
	var res: Variant = (seen[&"cl_weapon_icons"] as Callable).call("flat")
	_check(icons.style == &"flat" and not (res is GSResult and not res.ok), "setting cl_weapon_icons switches the style")
	var bad: Variant = (seen[&"cl_weapon_icons"] as Callable).call("nope")
	_check(bad is GSResult and not bad.ok and icons.style == &"flat", "a bad cvar value fails with a GSResult and changes nothing")
	var canvas := Control.new()
	icons.set_style(&"pixel")
	icons.filter(canvas)
	var nearest := canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	icons.filter(canvas, false)
	_check(nearest and canvas.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "filter is nearest for a sprite and inherited for a rendered model")
	canvas.free()
	_done()
