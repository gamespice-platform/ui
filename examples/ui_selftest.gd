extends "selftest/settings_binding_checks.gd"

## Exercises everything in gs-ui, offline and headless.
##
## [codeblock]
## godot --headless --path . res://examples/ui_selftest.tscn
## [/codeblock]
##
## Exits non-zero on any failure, so it works as a smoke test as-is.
##
## Nothing is rendered — a headless run has no display — and nothing here depends on
## rendering. What is tested is the part that is actually hard: the four things a
## screen stack has to keep in agreement, a settings panel that must never show a
## secret, and a rebinder that must never leave an action bound to nothing.

const CHECKS := 532

## Sections entered against sections that ran to their last line, and against this. A
## runtime error inside a section aborts that function and nothing says so; a section that
## bailed out early after a failed guard is counted as not finished on purpose. The CHECKS
## total is the other half — see docs/testing.md.
const SECTIONS := 36


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	_run.call_deferred()


func _run() -> void:
	print("gs-ui self-test")
	print("")

	_test_theme()
	_test_screen_stack()
	_test_stack_visibility()
	_test_stack_input_blocking()
	_test_stack_refusal()
	_test_hud()
	_test_widget_throttle()
	_test_stat_bar()
	_test_crosshair()
	_test_feed()
	_test_table()
	_test_server_list()
	_test_settings_panel()
	_test_settings_apply()
	_test_bindings()
	_test_input_binding()
	_test_chat_window()
	_test_ballot_panel()
	_test_ballot_avatar_rows()
	await _test_pointer_recapture()
	_test_hud_piece()
	_test_hud_fit()
	_test_vitals()
	_test_ammo_counter()
	_test_score_strip()
	_test_hit_marker()
	_test_damage_numbers()
	_test_key_prompt_and_hints()
	_test_touch_buttons()
	_test_icon_plate_and_status_lines()
	_test_loadout_bar()
	_test_winner_reveal()
	_test_icon_set()
	_test_icon_style()
	await _test_settings_screen()
	await _test_scoreboard_screen()

	GSPaths.remove_tree(BINDINGS_FILE)

	print("")
	print("%d passed, %d failed" % [_passed, _failed])

	for line in _failures:
		print("  FAIL  %s" % line)

	print("%d of %d sections ran to their last line" % [_completed, _entered])
	if _entered != SECTIONS or _completed != _entered:
		print("ERROR: %d sections entered and %d completed, %d expected. One aborted or was skipped." % [
			_entered, _completed, SECTIONS
		])
		get_tree().quit(1)
		return
	# The total the section counter cannot be. A runtime error inside a section aborts
	# that function, and the counter is satisfied because the section had already
	# announced itself. See docs/testing.md.
	if _passed + _failed != CHECKS:
		print("ERROR: %d checks ran, %d expected. A section aborted part-way." % [
			_passed + _failed, CHECKS
		])
		get_tree().quit(1)
		return
	get_tree().quit(1 if _failed > 0 else 0)


# --- Assertions ------------------------------------------------------------

## The shared scoreboard: the game's rows and columns, an icon column, a title.
func _test_scoreboard_screen() -> void:
	_section("scoreboard screen")

	var stack := GSScreenStack.new()
	add_child(stack)
	var board := GSScoreboardScreen.new()
	board.title_text = "Course 3"
	var avatar := GradientTexture2D.new()
	board.columns = [
		{"key": &"avatar", "kind": &"icon", "width": 0.0, "size": 20.0},
		{"key": &"name", "title": "Player", "width": 3.0},
		{"key": &"points", "title": "Points", "align": HORIZONTAL_ALIGNMENT_RIGHT},
		{"key": &"ping", "title": "Ping", "align": HORIZONTAL_ALIGNMENT_RIGHT},
	]
	var rows := [
		{&"avatar": avatar, &"name": "Ada", &"points": 30, &"ping": 41, "highlight": true},
		{&"avatar": null, &"name": "Bo", &"points": 10, &"ping": 77},
	]
	board.row_fn = func() -> Array: return rows
	stack.register(board)
	var pushed := stack.push(&"scoreboard")
	await get_tree().process_frame

	_check(pushed.ok and stack.top_id() == &"scoreboard", "a game registers it and pushes it by its id")
	_check(not board.blocks_input, "and it does not stop the player moving")
	_check(board.table.row_count() == 2 and board._title.text == "Course 3",
		"it shows the game's rows under the game's title")
	var first_row := board.table._grid.get_child(1)
	_check(first_row.get_child(0) is TextureRect and (first_row.get_child(0) as TextureRect).texture == avatar,
		"an icon column draws the row's picture")
	var second_row := board.table._grid.get_child(2)
	_check(second_row.get_child(0) is TextureRect and (second_row.get_child(0) as TextureRect).texture == null,
		"and a player with none keeps the column's width")

	stack.queue_free()
	_done()


func _test_icon_set() -> void:
	_section("icon set: tags, aliases, overrides, flat")

	var set := GSWeaponIcons.stock()
	var pistol := set.texture_for(&"pistol") as AtlasTexture
	_check(pistol != null and pistol.region.size.x > 0.0 and pistol.region.size.x <= 48.0, "a stock tag is a trimmed sprite")
	_check(set.texture_for(&"nonsense") == null and not set.has_icon(&"nonsense"), "an unknown id has no icon, so the caller draws the name")
	_check(set.texture_for(&"zz", &"shotgun") != null, "an unknown id falls back to its type tag")
	set.alias(&"sidearm", &"revolver")
	_check(set.texture_for(&"sidearm") == set.texture_for(&"revolver"), "an alias draws what its target draws")
	var plain := GradientTexture2D.new()
	set.override(&"sidearm", plain)
	_check(set.texture_for(&"sidearm") == plain, "an override beats the stock sprite")
	var mine := GradientTexture2D.new()
	set.override(&"sidearm", mine, &"retro")
	_check(set.texture_for(&"sidearm") == plain, "another profile's override is not used")
	set.profile = &"retro"
	_check(set.texture_for(&"sidearm") == mine, "the active profile's override wins over the shared one")
	set.profile = &""
	set.load_overrides({"knife": plain, "retro": {"pistol": mine}})
	_check(set.texture_for(&"knife") == plain, "a document's flat entry is a shared override")
	set.profile = &"retro"
	_check(set.texture_for(&"pistol") == mine, "a document's nested entry is that profile's")
	set.profile = &""
	set.flat = true
	set.flat_colour = Color(1.0, 0.5, 0.0)
	var flat := set.texture_for(&"smg")
	var image := flat.get_image()
	var lit := 0
	var other := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				if absf(c.r - 1.0) < 0.01 and absf(c.g - 0.5) < 0.01 and c.b < 0.01:
					lit += 1
				else:
					other += 1
	_check(lit > 20 and other == 0, "flat redraws every opaque pixel in one colour")
	var canvas := Control.new()
	GSIconSet.pixel_perfect(canvas)
	_check(canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel_perfect sets nearest filtering")
	canvas.free()
	_check(GSWeaponIcons.TAGS.size() == 30 and GSWeaponIcons.stock().texture_for(&"launcher") != null, "every stock tag is mapped")
	_done()


func _test_winner_reveal() -> void:
	_section("GSWinnerReveal: name, podium, its time, a skip, and reduced motion")
	var r := GSWinnerReveal.new()
	r.auto_process = false
	add_child(r)
	var ended: Array = []
	r.finished.connect(func(skipped: bool) -> void: ended.append(skipped))
	_check(not r.present([]).ok, "no entries is refused")
	var entries := [{"name": "Ada", "score": "25 kills"}, {"name": "Bo", "score": "19 kills"}]
	_check(r.present(entries).ok and r.visible and r.is_active(), "two entries are shown")
	_check(r.name_label.text == "Ada" and r.title_label.text == "WINNER" and r.subtitle_label.text == "25 kills",
		"the winner's name under the title, with the score")
	_check(r.name_label.visible_ratio == 0.0 and (r.places[0]["column"] as Control).size.y == 0.0,
		"at the start the name is hidden and the podium flat")
	_check((r.places[1]["name"] as Label).text == "Bo" and not (r.places[2]["column"] as CanvasItem).visible,
		"second place is Bo, and third, with nobody in it, is not drawn")
	r.advance(3.0)
	_check(r.name_label.visible_ratio == 1.0 and (r.places[0]["column"] as Control).size.y > (r.places[1]["column"] as Control).size.y,
		"three seconds in the name is out and first stands above second")
	r.advance(r.hold_seconds)
	_check(ended == [false] and not r.visible, "its time runs out by itself")
	var _again := r.present(entries)
	r.skip_button.pressed.emit()
	_check(ended == [false, true] and not r.is_active(), "the skip button ends it, skipped")
	r.reduced_motion = true
	var _still := r.present(entries)
	_check(r.name_label.visible_ratio == 1.0 and (r.places[0]["column"] as Control).size.y > 0.0 and r.title_label.scale == Vector2.ONE,
		"reduced motion: the final frame from the first, nothing to wait for")
	r.free()
	_done()


# --- The glance pieces -------------------------------------------------------


## Colours from the theme or the defaults, and what a piece does under a cover.
func _test_hud_piece() -> void:
	_section("hud piece: theme and cover")

	var vitals := _piece(GSVitals.new(), Rect2(0.0, 600.0, 380.0, 76.0)) as GSVitals
	vitals.show_vitals(60.0, 100.0)
	_check(vitals.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a piece never takes the click that fires the weapon")
	_check(vitals.colour(&"low") == GSHudPiece.DEFAULTS[&"low"], "with no theme a piece draws in the defaults")
	var palette := GSUiTheme.light()
	palette.danger = Color(0.7, 0.1, 0.6)
	vitals.theme = palette.build()
	_check(vitals.colour(&"low") == palette.danger, "with a theme, in the theme's colours")
	_check(vitals.colour(&"plate").a < 1.0, "and the plate is see-through, not a panel")
	vitals.theme = null

	# The default is the dark HUD (first play test, 2026-10-11): a dark plate, light words.
	_check(GSHudPiece.DEFAULTS[&"plate"].get_luminance() < 0.1 and GSHudPiece.DEFAULTS[&"plate"].a >= 0.7,
		"the default plate is deep and dark, and opaque enough to read on a white wall")
	_check(GSHudPiece.DEFAULTS[&"keycap"].get_luminance() < 0.3 and GSHudPiece.DEFAULTS[&"keycap_text"].get_luminance() > 0.8,
		"and a default key cap is a dark cap with a light letter, not a white tile")
	_check(vitals.number(&"team_fill") == GSHudPiece.DEFAULT_CONSTANTS[&"team_fill"],
		"a constant with no theme is the default")
	for key in GSHudPiece.COLOUR_KEYS:
		if not GSHudPiece.DEFAULTS.has(key):
			_check(false, "every colour key has a default: %s" % key)
	# A layer theme from colours: every piece and every plain Label under the node follows it.
	var layer := Control.new()
	layer.size = Vector2(800.0, 700.0)
	add_child(layer)
	var lit := GSHudPiece.theme_from({&"plate": Color(0.9, 0.9, 0.9, 0.8), &"text": Color(0.1, 0.1, 0.1), &"ink": Color(1, 1, 1, 0.9)}, {&"team_fill": 100})
	layer.theme = lit
	var under := GSVitals.new()
	layer.add_child(under)
	var words := Label.new()
	layer.add_child(words)
	_check(under.colour(&"plate") == Color(0.9, 0.9, 0.9, 0.8) and under.colour(&"text") == Color(0.1, 0.1, 0.1),
		"a layer theme reaches a piece under it")
	_check(under.colour(&"low") == GSHudPiece.DEFAULTS[&"low"], "and a colour it leaves out is still the default")
	_check(under.number(&"team_fill") == 100, "and its constants")
	_check(words.get_theme_color(&"font_color") == Color(0.1, 0.1, 0.1) and words.get_theme_constant(&"outline_size") > 0
		and words.get_theme_color(&"font_outline_color") == Color(1, 1, 1, 0.9),
		"and a plain Label under it takes the text colour, outlined in the ink")
	layer.theme = GSHudPiece.theme_from({&"plate": Color(0.02, 0.02, 0.04, 0.75)})
	_check(under.colour(&"plate") == Color(0.02, 0.02, 0.04, 0.75), "a new layer theme is followed at once, nothing rebuilt")
	layer.queue_free()
	var built := GSUiTheme.dark().build()
	vitals.theme = built
	_check(vitals.colour(&"keycap").get_luminance() < 0.4 and vitals.number(&"team_fill") < 100,
		"GSUiTheme's dark palette gives dark caps and tinted score plates")
	vitals.theme = GSUiTheme.light().build()
	_check(vitals.number(&"team_fill") == 100, "and its light one painted plates, the bright look")
	vitals.theme = null
	# The engine's own theme has a default font, which made `has_theme_font` true for every
	# name, so the pieces drew regular weight: the bold fallback is what no theme gives.
	_check(vitals.font() == GSHudPiece.bold_font() and vitals._theme_font() == null,
		"with no theme font on the type, a piece draws bold, not the engine's regular weight")
	var with_font := Theme.new()
	var chosen := SystemFont.new()
	with_font.set_font(&"font", GSHudPiece.THEME_TYPE, chosen)
	vitals.theme = with_font
	_check(vitals.font() == chosen, "and a font a theme sets on the type replaces it")
	vitals.theme = null

	_check(vitals.footprint().has_area(), "a piece says where it draws")
	vitals.refresh_cover()
	_check(not vitals.covered and vitals.self_modulate.a == 1.0, "nothing over it: drawn in full")

	# A ballot stand-in, in the group by its string, over the piece's plate.
	var cover := Control.new()
	cover.position = Vector2(100.0, 580.0)
	cover.size = Vector2(300.0, 200.0)
	cover.add_to_group("gs_hud_cover")
	add_child(cover)
	_check(GSHudPiece.covered_rect(vitals).has_area(), "the cover is found by its group, in the piece's own space")
	vitals.refresh_cover()
	_check(vitals.covered, "a cover over its footprint is seen")
	_close(vitals.self_modulate.a, vitals.cover_alpha, "and the piece dims under it, so the ballot reads")
	vitals.cover_mode = GSHudPiece.CoverMode.HIDE
	vitals.refresh_cover()
	_close(vitals.self_modulate.a, 0.0, "or hides, when told to")
	cover.visible = false
	vitals.refresh_cover()
	_check(not vitals.covered and vitals.self_modulate.a == 1.0, "a hidden cover covers nothing")
	cover.visible = true
	cover.position = Vector2(500.0, 580.0)
	vitals.refresh_cover()
	_check(not vitals.covered, "nor does one beside the footprint, inside the control's rect or not")
	cover.position = Vector2(100.0, 580.0)
	vitals.cover_mode = GSHudPiece.CoverMode.IGNORE
	vitals.refresh_cover()
	_check(not vitals.covered and vitals.self_modulate.a == 1.0, "IGNORE draws through it")

	var marker := GSHitMarker.new()
	_check(marker.cover_mode == GSHudPiece.CoverMode.IGNORE,
		"the crosshair's pieces ignore covers: their rect is the whole HUD, which always meets one")
	marker.free()

	cover.queue_free()
	vitals.queue_free()
	_done()


## The HUD scaled below the frame it was designed for, never laid out again.
func _test_hud_fit() -> void:
	_section("hud fit")

	_close(GSHud.fit_scale(Vector2(1280.0, 720.0)), 1.0, "1280x720 is drawn as designed")
	_close(GSHud.fit_scale(Vector2(1920.0, 1080.0)), 1.0, "a larger frame does not grow the HUD")
	_close(GSHud.fit_scale(Vector2(854.0, 480.0)), 480.0 / 720.0, "854x480 scales by the short side's share")
	_close(GSHud.fit_scale(Vector2(720.0, 1280.0)), 720.0 / 1280.0, "a portrait frame by its width")
	_close(GSHud.fit_scale(Vector2(320.0, 180.0)), 0.5, "never under half")

	var hud := GSHud.new()
	hud.config = GSUiConfig.new()
	hud.config.safe_area = 16.0
	hud.fit_design = Vector2(1280.0, 720.0)
	add_child(hud)
	hud.fit_to_frame(Vector2(854.0, 480.0))
	_close(hud.fit(), 480.0 / 720.0, "a HUD with a design frame scales itself")
	_close(hud.position.x + (hud.size.x + 16.0) * hud.fit(), 854.0, "and still fills the frame, inset included", 0.5)
	var ammo := GSAmmoCounter.new()
	ammo.position = Vector2(100.0, 100.0)
	ammo.size = Vector2(290.0, 70.0)
	hud.add_child(ammo)
	ammo.show_ammo("Rifle", 30, 90)
	var on_screen := ammo.get_global_transform() * ammo.footprint()
	_close(on_screen.size.x, ammo.footprint().size.x * hud.fit(), "a piece inside it is drawn at the HUD's scale", 0.5)
	hud.fit_to_frame(Vector2(1600.0, 900.0))
	_close(hud.fit(), 1.0, "and back at full size on a big frame")
	var fm := GSFireModeIndicator.new()
	fm.size = Vector2(200.0, 26.0)
	fm.show_modes([&"burst", &"auto"], &"auto")
	_check(fm.available == [&"auto", &"burst"] and fm.footprint().size.x == 88.0, "the fire-mode indicator draws only the modes on offer, in a fixed order")
	fm.show_modes([&"semi"], &"semi")
	_check(fm.footprint().size == Vector2.ZERO, "and nothing for a gun with one mode")
	fm.free()
	hud.user_scale = 0.8
	hud.fit_to_frame(Vector2(1600.0, 900.0))
	_close(hud.fit(), 0.8, "the player's HUD size multiplies the fit")
	_close(hud.position.x + (hud.size.x + 16.0) * hud.fit(), 1600.0, "and the HUD still reaches the frame's far edge", 0.5)
	hud.fit_to_frame(Vector2(854.0, 480.0))
	_close(hud.fit(), 0.8 * 480.0 / 720.0, "on a small frame too")
	hud.queue_free()

	# A plain Control as a HUD root (most games: a full-rect Control under a CanvasLayer).
	var root := Control.new()
	add_child(root)
	GSHud.fit_control(root, Vector2(1280.0, 720.0), 1.25)
	_close(root.scale.x, 1.25, "a plain HUD root is scaled")
	_close(root.size.x * root.scale.x, 1280.0, "and sized so its anchors still reach the frame's edges", 0.5)
	root.queue_free()
	_done()


func _test_vitals() -> void:
	_section("vitals")

	var v := _piece(GSVitals.new(), Rect2(0.0, 0.0, 380.0, 76.0)) as GSVitals
	# Under the 0.25 threshold: the state the low colour exists for.
	v.show_vitals(18.0, 100.0)
	_check(v.is_low() and v.number_text() == "18", "18 of 100 is low, and says 18")
	_close(v.shown_fraction(), 0.18, "the first value is drawn at once, not eased in from full")
	var plain := v.footprint()
	_check(plain.size.x > v.bar_end and plain.size.y == 56.0, "the plate reaches past the bar to the number")
	v.show_vitals(0.4, 100.0)
	_check(v.number_text() == "1", "0.4 is alive, and says 1, not 0")

	# The streak row: absent until asked for, then in the same plate.
	_check(not v.has_streak_row(), "no streak row until show_streak")
	var without := v.footprint().size.y
	v.show_streak(3, 10)
	_check(v.has_streak_row() and v.streak_text() == "Killstreak x3", "show_streak says its count")
	_check(v.footprint().size.y > without, "the streak row grows the plate, not a second widget")
	_close(v.shown_streak_fraction(), 0.3, "the first streak is drawn at once")
	v.show_streak(6, 10)
	v.advance(0.016)
	_check(v.shown_streak_fraction() > 0.3 and v.shown_streak_fraction() < 0.6, "a rising streak eases")
	v.advance(5.0)
	_close(v.shown_streak_fraction(), 0.6, "and arrives")
	v.streak_format = "Streak %d"
	_check(v.streak_text() == "Streak 6", "the words are the game's to set")
	v.show_streak(0, 0)
	_check(not v.has_streak_row(), "a full of 0 hides the row")

	v.show_vitals(100.0, 100.0)
	v.advance(10.0)
	v.show_vitals(50.0, 100.0)
	_check(v.number_text() == "50", "the number is the value at once")
	v.advance(0.03)
	_check(v.shown_fraction() < 1.0 and v.shown_fraction() > 0.5, "the bar slides toward it", "%.3f" % v.shown_fraction())
	v.advance(5.0)
	_close(v.shown_fraction(), 0.5, "and arrives")
	_check(not v.is_low(), "half is not low")

	v.show_vitals(50.0, 100.0, 40.0, 100.0, 20.0)
	_check(v.footprint().size.y == 72.0, "armour makes the plate taller for its bar")
	_close(v.bonus, 20.0, "a bonus is kept beside the real health")
	v.show_status("DOWN")
	_check(v.number_text() == "DOWN", "a status replaces the number")
	v.show_status("")
	_check(v.number_text() == "50", "and clearing it brings the number back")
	_check(int(v.describe().get("health", -1)) == 50, "describe() reports the health")
	v.queue_free()
	_done()


func _test_ammo_counter() -> void:
	_section("ammo counter")

	var a := _piece(GSAmmoCounter.new(), Rect2(0.0, 0.0, 290.0, 70.0)) as GSAmmoCounter
	_check(not a.footprint().has_area(), "nothing in hand draws nothing")
	a.show_ammo("Rifle", 12, 90)
	_check(a.count_text() == "12 | 90", "magazine | reserve")
	var full := a.footprint()
	_check(full.end.x <= a.size.x + 14.0 + 0.5 and full.size.y == 70.0, "right-aligned, on a plate for the name and the count")
	a.show_ammo("Pistol", 7, 0, false, true)
	_check(a.count_text() == "7 | ∞", "an endless reserve draws as one")
	a.show_ammo("Pistol", 7, -1)
	_check(a.count_text() == "7", "no reserve draws the magazine alone")
	a.show_ammo("Knife", -1, -1)
	_check(a.count_text() == "" and a.footprint().size.y == 32.0, "a weapon with no magazine shows its name alone")
	a.show_ammo("Rifle", 3, 90, true)
	_check(a.low, "the host says when it is low")
	a.clear()
	_check(not a.footprint().has_area(), "and clear() takes it down")
	a.queue_free()
	_done()


func _test_score_strip() -> void:
	_section("score strip")

	_check(GSScoreStrip.clock_text(0.0) == "0:00", "0:00 at the end")
	_check(GSScoreStrip.clock_text(59.2) == "1:00", "rounded up, so it never says 0:00 with time left")
	_check(GSScoreStrip.clock_text(61.0) == "1:01", "M:SS")
	_check(GSScoreStrip.clock_text(3661.0) == "1:01:01", "H:MM:SS from an hour")
	_check(GSScoreStrip.clock_text(-4.0) == "0:00", "never negative")

	var s := _piece(GSScoreStrip.new(), Rect2(0.0, 0.0, 520.0, 72.0)) as GSScoreStrip
	_check(not s.footprint().has_area(), "nothing handed over draws nothing")
	s.show_clock(GSScoreStrip.clock_text(95.0), false, "", "")
	var clock_only := s.footprint()
	_check(not s.sides and is_equal_approx(clock_only.size.x, GSScoreStrip.CLOCK_W), "a game with no scores gets the clock alone")
	_close(clock_only.get_center().x, 260.0, "centred on the control's middle")
	s.show_scores(12, 9, "BLUE", "RED", Color.BLUE, Color.RED)
	_check(s.sides and s.footprint().size.x > clock_only.size.x * 2.0, "two sides put the plates either side of it")
	s.show_clock("0:09", true, "First to 25", "Team deathmatch")
	_check(s.under_text() == "First to 25   ·   Team deathmatch", "what wins and the mode, under them")
	_check(s.footprint().size.y > GSScoreStrip.H, "and the footprint takes the line in")
	s.hide_scores()
	_check(not s.sides, "a mode with no sides takes the plates down")
	s.queue_free()
	_done()


func _test_hit_marker() -> void:
	_section("hit marker")

	var m := _piece(GSHitMarker.new(), Rect2(0.0, 0.0, 400.0, 300.0)) as GSHitMarker
	_check(m.alpha() == 0.0 and not m.footprint().has_area(), "nothing until a hit")
	m.flash()
	_close(m.alpha(), 1.0, "a confirmed hit flashes it")
	_close(m.footprint().get_center().x, 200.0, "round the middle, where the crosshair is")
	m.advance(m.hit_sec + 0.01)
	_close(m.alpha(), 0.0, "and it is gone after hit_sec")
	m.flash(true)
	m.advance(0.05)
	m.flash(false)
	_check(m.kill, "a pellet after the lethal one does not turn the kill marker white")
	_close(m.life, m.kill_sec, "and a kill holds longer than a hit")
	m.advance(m.kill_sec)
	m.flash(false, true)
	_check(not m.kill and m.headshot, "after it fades, the next hit is its own")
	m.queue_free()
	_done()


func _test_damage_numbers() -> void:
	_section("damage numbers")

	var d := _piece(GSDamageNumbers.new(), Rect2(0.0, 0.0, 400.0, 300.0)) as GSDamageNumbers
	d.add_at(7, 20.0, Vector2(200.0, 150.0))
	d.advance(0.1)
	d.add_at(7, 15.0, Vector2(200.0, 150.0), true)
	_check(d.texts() == PackedStringArray(["35"]), "a burst on one victim adds up into one number", str(d.texts()))
	_check(bool(d.entries[0]["headshot"]), "and a headshot in it marks the total")
	d.add_at(8, 9.0, Vector2(100.0, 150.0))
	_check(d.entries.size() == 2, "another victim gets a number of its own")
	_check(d.footprint().has_area(), "and they say where they draw")
	d.advance(d.merge_sec + 0.05)
	d.add_at(7, 5.0, Vector2(200.0, 150.0))
	_check(d.entries.size() == 3, "a hit after merge_sec is a new number")
	d.advance(d.life_sec + 0.01)
	_check(d.entries.is_empty(), "every number fades out")
	# A world point with no camera: headless, and a host that has not attached one yet.
	d.add(9, 10.0, Vector3(0.0, 1.0, -5.0))
	_check(not d.footprint().has_area(), "with no camera a world point is not drawn, and nothing fails")
	d.clear()
	_check(d.entries.is_empty(), "clear() empties it")
	d.queue_free()
	_done()


func _test_key_prompt_and_hints() -> void:
	_section("key prompt and hints")

	var p := _piece(GSKeyPrompt.new(), Rect2(0.0, 0.0, 400.0, 40.0)) as GSKeyPrompt
	p.show_prompt("Open door", "E")
	_check(p.visible and p.text() == "Open door  E", "a prompt says what and which key")
	_close(p.footprint().get_center().x, 200.0, "centred on its middle")
	var with_key := p.footprint().size.x
	p.show_prompt("Spent", "")
	_check(p.text() == "Spent" and p.footprint().size.x < with_key, "a prompt with no key is the words alone")
	p.clear()
	_check(not p.visible and not p.footprint().has_area(), "nothing to say hides it")

	var h := _piece(GSKeyHints.new(), Rect2(0.0, 0.0, 300.0, 200.0)) as GSKeyHints
	h.show_hints([["Scoreboard", "Tab"], ["Vote", "F3"], ["Chat", "Y"]])
	var left := h.footprint()
	_check(is_equal_approx(left.size.y, 3.0 * h.row_height), "a row per hint")
	_check(left.position.x == 0.0, "from the left edge by default")
	h.align_right = true
	_check(is_equal_approx(h.footprint().end.x, 300.0), "or to the right edge")
	h.clear()
	_check(not h.footprint().has_area(), "and clear() takes them down")
	p.queue_free()
	h.queue_free()
	_done()


func _test_touch_buttons() -> void:
	_section("touch buttons")

	GSPlatform.touch_override = 0
	var b := _piece(GSTouchButtons.new(), Rect2(0.0, 0.0, 390.0, 844.0)) as GSTouchButtons
	_check(not b.visible, "hidden where there is no touch screen")
	GSPlatform.touch_override = 1
	b.visible = true
	b.set_buttons(GSTouchButtons.fps_stock())

	var downs: Array[StringName] = []
	var ups: Array[StringName] = []
	b.button_down.connect(func(id: StringName) -> void: downs.append(id))
	b.button_up.connect(func(id: StringName) -> void: ups.append(id))
	var fire := b.centre_of(&"fire")
	var jump := b.centre_of(&"jump")
	_check(fire.x > 195.0 and fire.y > 422.0, "the fire button sits in the bottom-right quarter")
	_check(Rect2(Vector2.ZERO, b.size).encloses(b.footprint()), "and every button is on the screen")
	_check(b.contains_point(fire) and not b.contains_point(Vector2(40.0, 400.0)), "contains_point is true on a button and false on the stick side")

	b._input(_touch_event(0, fire, true))
	_check(downs == [&"fire"] and b.is_held(&"fire"), "a finger down on a button holds it")
	b._input(_touch_event(1, jump, true))
	_check(b.is_held(&"fire") and b.is_held(&"jump"), "a second finger holds a second button at once")
	b._input(_touch_event(0, fire, false))
	_check(ups == [&"fire"] and not b.is_held(&"fire") and b.is_held(&"jump"), "lifting one finger releases only its button")
	b._input(_touch_event(2, fire + Vector2(b.radius_of(&"fire") * 1.1, 0.0), true))
	_check(b.is_held(&"fire"), "a finger a little outside the circle still hits (slop)")
	b.set_buttons(GSTouchButtons.fps_stock())
	_check(not b.is_held(&"jump") and ups.size() == 3, "replacing the buttons releases whatever was held")
	GSPlatform.touch_override = -1
	b.queue_free()
	_done()


func _touch_event(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


# --- Theme -----------------------------------------------------------------

func _test_theme() -> void:
	_section("theme")

	var palette := GSUiTheme.dark()
	var theme := palette.build(1.0)

	_check(theme != null, "a theme is built from a palette alone")
	_check(
		theme.default_font_size == palette.font_size,
		"at the declared font size",
		str(theme.default_font_size)
	)
	_check(
		theme.has_stylebox("normal", "Button"),
		"with a button style"
	)
	_check(
		theme.is_type_variation(&"GSHeading", &"Label"),
		"and a heading variation, so a heading is not a hand-set font size"
	)

	var big := palette.build(2.0)
	_check(
		big.default_font_size == palette.font_size * 2,
		"scaling scales the font",
		str(big.default_font_size)
	)

	# A fresh Theme per call. Handing out one shared mutable object means a game that
	# tweaks one window tweaks both.
	_check(
		palette.build(1.0) != theme,
		"each build produces its own Theme rather than a shared one"
	)

	var light := GSUiTheme.light()
	_check(
		light.text.get_luminance() < light.surface.get_luminance(),
		"the light palette is actually light"
	)
	_done()


# --- Screen stack ----------------------------------------------------------

func _test_screen_stack() -> void:
	_section("screen stack")

	var stack := _make_stack()
	var menu := _make_screen(&"menu")
	var settings := _make_screen(&"settings")

	_check(stack.register(menu).ok, "a screen registers")
	_check(stack.register(settings).ok, "and another")
	_check(
		menu.get_parent() == stack,
		"registering reparents the screen, because z-order is sibling order"
	)
	_check(not menu.visible, "a registered screen starts hidden")

	# A Control built in code keeps zero size unless the screen is sized: invisible, and
	# nothing errors.
	_check(
		stack.size.x > 0.0 and stack.size.y > 0.0,
		"the stack fills its parent",
		"%.0f x %.0f" % [stack.size.x, stack.size.y]
	)
	_check(
		menu.size.is_equal_approx(stack.size),
		"and a screen fills the stack",
		"%.0f x %.0f" % [menu.size.x, menu.size.y]
	)

	# Two screens claiming the same id is a scene mistake that would otherwise show up
	# as one of them being unreachable.
	var clash := _make_screen(&"menu")
	_check(not stack.register(clash).ok, "two screens with one id is refused")
	clash.queue_free()

	_registered_ids_checks()

	_check(stack.push(&"menu").ok, "pushing opens a screen")
	_check(stack.top_id() == &"menu", "which is then on top")
	_check(menu.events == ["push"], "and was told", str(menu.events))
	_check(stack.any_open(), "the stack reports a menu is open")

	stack.push(&"settings")
	_check(stack.top_id() == &"settings", "pushing again stacks")
	_check(menu.events == ["push", "cover"], "and covers what was there", str(menu.events))
	_check(stack.depth() == 2, "to a depth of two")

	# The double-fire case. Pushing what is already open must not stack a second copy,
	# or one menu takes two escapes to close.
	stack.push(&"menu")
	_check(stack.depth() == 2, "pushing an open screen does not stack a second copy")
	_check(stack.top_id() == &"menu", "it is raised instead")

	stack.pop()
	_check(stack.top_id() == &"settings", "popping reveals what was underneath")

	stack.pop()
	_check(stack.depth() == 0, "and again empties the stack")
	_check(not stack.any_open(), "which is reported")

	# Popping from the middle rather than refusing: a screen closing itself in
	# response to a game event does not know what has been opened over it.
	stack.push(&"menu")
	stack.push(&"settings")
	_check(stack.pop(&"menu").ok, "a screen can be popped from under another")
	_check(stack.top_id() == &"settings", "leaving the top one alone")
	_check(stack.depth() == 1, "and the stack shorter")

	stack.clear()
	_check(stack.depth() == 0, "clearing empties it")

	# toggle and replace.
	stack.toggle(&"menu")
	_check(stack.is_open(&"menu"), "toggle opens")
	stack.toggle(&"menu")
	_check(not stack.is_open(&"menu"), "and closes")

	stack.push(&"menu")
	stack.replace(&"settings")
	_check(
		stack.depth() == 1 and stack.top_id() == &"settings",
		"replace swaps rather than stacking"
	)

	_check(not stack.push(&"nonexistent").ok, "pushing an unknown id fails")

	stack.queue_free()
	remove_child(stack)
	_done()


# --- HUD -------------------------------------------------------------------

func _test_hud() -> void:
	_section("hud")

	var stack := _make_stack()
	var hud := GSHud.new()
	hud.config = GSUiConfig.new()
	add_child(hud)

	_check(
		hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"a HUD never eats the click that should have fired the weapon"
	)

	var opaque := _make_screen(&"opaque")
	opaque.hides_below = true
	var overlay := _make_screen(&"overlay")

	stack.register(opaque)
	stack.register(overlay)
	hud.bind_stack(stack)

	stack.push(&"overlay")
	_check(hud.visible, "a transparent screen leaves the HUD up")

	stack.push(&"opaque")
	_check(not hud.visible, "an opaque one takes it down")

	stack.pop()
	_check(hud.visible, "and closing it brings it back")

	# The game's own hide is separate, so closing a menu does not undo it.
	hud.set_hidden_by_game(true)
	_check(not hud.visible, "a game can hide the HUD itself")
	stack.push(&"overlay")
	stack.pop()
	_check(not hud.visible, "and a menu opening and closing does not undo that")
	hud.set_hidden_by_game(false)
	_check(hud.visible, "until the game says otherwise")

	# The safe area, which is what stops an ammo counter under a camera cutout.
	hud.config.safe_area = 24.0
	hud.config.scale = 2.0
	hud._apply_safe_area()
	_close(hud.offset_left, 48.0, "the safe area is inset and scaled")
	_close(hud.offset_right, -48.0, "on both sides")

	hud.queue_free()
	remove_child(hud)
	stack.queue_free()
	remove_child(stack)
	_done()


func _test_widget_throttle() -> void:
	_section("hud widget")

	var widget := GSHudWidget.new()
	var reads: Array[int] = []
	var current := [7]

	widget.source = func() -> Variant:
		reads.append(1)
		return current[0]

	add_child(widget)

	_check(widget.value == 7, "a widget reads its source on ready")

	# Captured Arrays rather than counters: a GDScript lambda captures locals by
	# value, so an incremented int stays zero outside the lambda and the assertion
	# reports a failure for a callable that fired perfectly.
	var refreshes: Array[int] = []
	widget.refreshed.connect(func(_v: Variant) -> void: refreshes.append(1))

	current[0] = 9
	widget.refresh()
	_check(widget.value == 9, "and again when refreshed")
	_check(refreshes.size() == 1, "emitting once")

	widget.refresh_on_change = false
	widget.refresh_rate = 10.0
	current[0] = 11

	widget._process(0.05)
	_check(widget.value == 9, "the throttle holds a value back")
	widget._process(0.06)
	_check(widget.value == 11, "and lets it through on schedule")

	# Change-driven refresh, for anything where lateness is a lie.
	widget.refresh_on_change = true
	current[0] = 13
	widget._process(0.001)
	_check(widget.value == 13, "a change is picked up immediately when asked for")

	widget.queue_free()
	remove_child(widget)
	_done()


# --- Feed and table --------------------------------------------------------

func _test_feed() -> void:
	_section("feed")

	var feed := GSFeedView.new()
	feed.max_lines = 3
	feed.lifetime_sec = 5.0
	feed.fade_sec = 1.0
	add_child(feed)

	feed.add_text("one")
	feed.add_text("two")
	_check(feed.line_count() == 2, "lines are added")

	feed.add_text("three")
	feed.add_text("four")
	_check(feed.line_count() == 3, "and bounded", str(feed.line_count()))

	# Driven with an explicit clock rather than by waiting: a test that waits out six
	# real seconds is a test nobody runs.
	var now := Time.get_ticks_msec()
	_check(feed.expire(now) == 0, "nothing expires early")
	_check(feed.expire(now + 6000) == 3, "and everything does once it is due")
	_check(feed.line_count() == 0, "leaving the feed empty")

	var line := feed.add_text("fading")
	_close(feed.opacity_of(line, now), 1.0, "a fresh line is opaque")
	_close(
		feed.opacity_of(line, now + 4500),
		0.5,
		"and fades over the last of its life",
		0.05
	)
	_close(feed.opacity_of(line, now + 5000), 0.0, "to nothing")

	# Held lines never expire. A chat message that fades while you are reading it is
	# a message you have to ask someone to repeat.
	feed.hold = true
	feed.add_text("held")
	_check(feed.expire(now + 100000) == 0, "a held feed expires nothing")
	_close(feed.opacity_of(line, now + 100000), 1.0, "and stays opaque")

	feed.hold = false
	feed.clear()

	var kill := feed.add_kill(
		"Alice", Color.RED, "rifle", "Bob", Color.BLUE, true
	)
	var parts: Array = kill["parts"]
	_check(parts.size() >= 3, "a kill line is built from coloured fragments")
	_check(
		str((parts[0] as Dictionary)["text"]) == "Alice",
		"starting with the killer"
	)

	var world := feed.add_kill("", Color.RED, "fall", "Bob", Color.BLUE)
	var world_parts: Array = world["parts"]
	_check(
		str((world_parts[0] as Dictionary)["text"]).begins_with("["),
		"and a world death has no killer fragment"
	)

	feed.queue_free()
	remove_child(feed)
	_done()


## The Gamespice look and the server list: rows by address, selecting is not joining, the
## focused row survives a refresh, and a phone width stacks the columns.
func _test_server_list() -> void:
	_section("server list")

	var look := GSUiGamespice.theme()
	_check(look.is_type_variation(&"GSEyebrow", &"Label"), "the Gamespice theme has the eyebrow")
	_check(look.get_stylebox("focus", "Button") is StyleBoxFlat, "and a focus ring for keyboard and pad")
	_close(GSUiGamespice.fit_factor(Vector2(1280, 720), 1.0, Vector2(1280, 720), Vector2(460, 520), 16.0, 1.0), 1.0,
		"a desktop window keeps the layout it was drawn for")

	var list := GSServerList.new()
	add_child(list)
	var joined: Array[String] = []
	var picked: Array[String] = []
	list.join_requested.connect(func(address: String) -> void: joined.append(address))
	list.selection_changed.connect(func(address: String) -> void: picked.append(address))
	var rows: Array[Dictionary] = [
		{"address": "a:1", "name": "Alpha", "map": "dust", "players": 3, "max_players": 16, "ping_ms": 40, "status": "online"},
		{"address": "b:2", "name": "Bravo", "map": "orange", "players": 0, "max_players": 8, "ping_ms": 200, "status": "online"},
		{"address": "c:3", "name": "", "map": "", "players": 0, "max_players": 0, "ping_ms": -1, "status": "offline"},
		{"name": "no address"},
	]
	list.set_rows(rows)
	_check(list.rows().size() == 3, "a row with no address is skipped", str(list.rows().size()))
	_check(list.shown_count() == 3, "every row is on screen")
	_check(not list.join_selected() and joined.is_empty(), "Join with nothing selected does nothing")

	list.row_button("b:2").pressed.emit()
	_check(list.selected_address() == "b:2" and picked.size() == 1 and picked[0] == "b:2", "pressing a row selects it", str(picked))
	_check(joined.is_empty(), "and selecting is not joining")
	_check(list.join_selected() and joined.size() == 1 and joined[0] == "b:2", "Join joins the selected row", str(joined))

	var before := list.row_button("b:2")
	rows[1]["ping_ms"] = 30
	list.set_rows(rows)
	_check(list.row_button("b:2") == before, "a refresh keeps the same row Button, so a focused row stays focused")
	_check(before.get_combined_minimum_size().y >= list.row_height, "a row is at least a thumb high", str(before.get_combined_minimum_size()))

	list.search("DUST")
	_check(list.shown_count() == 1 and list.row_button("a:1") != null, "search filters by map, any case")
	_check(list.selected_address() == "", "a filtered-out selection is cleared rather than joined blind")
	list.search("")
	list.max_rows = 2
	list.set_rows(rows)
	_check(list.shown_count() == 2, "max_rows limits the rows drawn", str(list.shown_count()))

	list.size = Vector2(390, 600)
	_check(list.is_compact(), "a phone width stacks the columns")
	list.size = Vector2(1000, 600)
	_check(not list.is_compact(), "a desktop width keeps them")
	list.compact_below = 0.0
	list.size = Vector2(300, 600)
	_check(not list.is_compact(), "compact_below 0 never stacks")
	list.size = Vector2(844, 390)
	_check(list.is_short(), "a landscape phone puts the address box on the footer line")
	list.size = Vector2(844, 700)
	_check(not list.is_short(), "and a tall panel gives it its own line again")

	list.queue_free()
	_done()


func _test_table() -> void:
	_section("table")

	var table := GSTableView.new()
	add_child(table)

	table.set_columns(GSTableView.scoreboard_columns())
	_check(table.columns.size() == 6, "the standard scoreboard columns exist")

	var rows: Array[Dictionary] = []
	for index in range(10):
		rows.append({
			&"name": "Player %d" % index,
			&"kills": index,
			&"deaths": 10 - index,
			&"assists": 0,
			&"score": index * 2,
			&"ping": 30,
			"highlight": index == 3,
		})

	table.set_rows(rows)
	_check(table.row_count() == 10, "rows are held")
	_check(table.visible_row_count() == 10, "and all shown by default")

	# A 64-player server produces 64 rows of Labels for a scoreboard nobody scrolls.
	table.max_rows = 5
	table.set_rows(rows)
	_check(table.visible_row_count() == 5, "a row cap limits what is built")

	table.clear()
	_check(table.row_count() == 0, "clearing empties it")

	table.queue_free()
	remove_child(table)
	_done()


# --- Settings --------------------------------------------------------------

	# EVERY COLUMN GETS ROOM, which is what a rendered frame of a scoreboard found.
	#
	# An absent `width` used to mean `SIZE_FILL`, which reads as "take your content's
	# width" and is not: `clip_text` sets a Label's minimum size to ZERO, so a column with
	# no width collapsed to nothing. `scoreboard_columns()` gives a width only to `name`,
	# so every scoreboard and every server browser in this family drew ONE column -- no
	# kills, no deaths, no score, no ping -- with the data correct and `describe()`
	# agreeing. Armed by putting the `0.0` default back: this check fails, and nothing
	# about rows, columns or values does.
	var widths := GSTableView.new()
	add_child(widths)
	widths.set_columns(GSTableView.scoreboard_columns())
	widths.set_rows([{&"name": "somebody", &"kills": 3, &"deaths": 1, &"assists": 0,
		&"score": 3, &"ping": 40}])

	# A GridContainer, so the header is the first N children of the grid rather than a row
	# node of its own. Counted over that first row only: the data rows are built by the
	# same call and would double every number.
	# A VBox of HBoxes, so the header is the first row and its cells are that row's
	# children. It is an HBox rather than a `GridContainer` because a GridContainer gives
	# every column the SAME width whatever ratio a cell asks for -- see `_ensure_grid`.
	var grid := widths.get_node_or_null("Grid") as VBoxContainer
	var wanted := GSTableView.scoreboard_columns().size()
	var expanding := 0
	var ratios := PackedFloat32Array()

	if grid != null and grid.get_child_count() > 0:
		for cell in grid.get_child(0).get_children():
			var label := cell as Control
			if label == null:
				continue
			ratios.append(label.size_flags_stretch_ratio)
			if label.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
				expanding += 1

	_check(
		expanding == wanted,
		"every scoreboard column asks for room (%d of %d)" % [expanding, wanted],
		"a column with no width used to collapse to nothing, so only Player was drawn"
	)

	# AND THE RATIOS ARE HONOURED, which they were not for the life of this class.
	#
	# `size_flags_stretch_ratio` is read by a `BoxContainer` and by nothing else, so the
	# `GridContainer` this used to be gave every column the same width — `width` was
	# documented, set to 3.0 for the name column in `scoreboard_columns()`, and inert.
	# Measured before the fix: ratios 0.4, 3.0, 1.0, 1.0 came out 308 pixels each.
	_check(
		ratios.size() == wanted and is_equal_approx(ratios[0], 3.0),
		"and the name column asks for three times the share (%s)" % [ratios]
	)
	_check(
		grid.get_child(0) is HBoxContainer,
		"because a row is a BoxContainer, which is the only thing that reads a ratio"
	)

	widths.queue_free()


func _test_settings_panel() -> void:
	_section("settings panel")

	var config := TestConfig.new()
	var panel := GSSettingsPanel.new()
	add_child(panel)

	var res := panel.bind(config)
	_check(res.ok, "a panel builds itself from a config")
	_check(int(res.value) == 6, "with a control per editable key", str(res.value))

	# The one that matters: a secret must never end up in a screenshot or a pasted
	# bug report, which is the same reason GSConfig refuses them from argv.
	_check(
		panel.editor_for("rcon_password") == null,
		"and never one for a secret"
	)

	_check(panel.editor_for("friendly_fire") is GSFormToggle, "a bool is a toggle")
	_check(panel.editor_for("port") is LineEdit, "an int without a range is a number entry")
	_check(panel.editor_for("hostname") is LineEdit, "a string is a line edit")
	_check(
		panel.editor_for("difficulty") is OptionButton,
		"and an enum is an option button"
	)

	var spin := panel.editor_for("tick_rate") as GSFormSlider
	_check(spin != null, "a range hint becomes a slider")
	_close(spin.min_value, 1.0, "with the range's minimum")
	_close(spin.max_value, 240.0, "and its maximum")
	_close(spin.value, 64.0, "starting at the config's value")

	var options := panel.editor_for("difficulty") as OptionButton
	_check(
		options.get_item_text(options.selected) == "normal",
		"an enum starts on the config's value",
		options.get_item_text(options.selected)
	)

	# Group filtering.
	var filtered := GSSettingsPanel.new()
	filtered.only_groups = ["Gameplay"]
	add_child(filtered)
	var count := filtered.bind(config)
	_check(int(count.value) == 3, "a group filter narrows the panel", str(count.value))
	_check(filtered.editor_for("port") == null, "leaving the other group out")

	panel.queue_free()
	remove_child(panel)
	filtered.queue_free()
	remove_child(filtered)
	_done()


func _test_settings_apply() -> void:
	_section("settings panel: applying")

	var config := TestConfig.new()
	var panel := GSSettingsPanel.new()
	panel.live = false
	add_child(panel)
	panel.bind(config)

	panel.form.set_value("port", 27016)
	_check(panel.has_pending(), "an edit is held rather than written through")
	_check(config.port == 27015, "and the config is untouched")

	var applied: Array[int] = []
	panel.applied.connect(func() -> void: applied.append(1))

	_check(panel.apply().ok, "applying writes them")
	_check(config.port == 27016, "and the config has the new value")
	_check(applied.size() == 1, "and says so")
	_check(not panel.has_pending(), "with nothing left pending")

	# The rollback. Applying half of an invalid set leaves the config in a state
	# nobody chose, and the player cannot tell which half survived.
	var failures: Array[String] = []
	panel.apply_failed.connect(
		func(error: GSError) -> void: failures.append(error.message)
	)

	panel.form.set_value("port", 80)
	panel.form.set_value("hostname", "New name")

	var refused := panel.apply()
	_check(not refused.ok, "an invalid set is refused")
	_check(config.port == 27016, "the invalid value is rolled back")
	_check(
		config.hostname == "A server",
		"and so is the valid one that came with it",
		config.hostname
	)
	_check(failures.size() == 1, "and the failure is reported")

	panel.revert()
	_check(not panel.has_pending(), "reverting throws the edits away")
	_check(
		int(panel.form.values()["port"]) == 27016,
		"and puts the controls back"
	)

	# Live mode writes through.
	var live_panel := GSSettingsPanel.new()
	live_panel.live = true
	add_child(live_panel)
	live_panel.bind(config)
	live_panel.form.set_value("friendly_fire", true)
	_check(config.friendly_fire, "a live panel writes through immediately")

	panel.queue_free()
	remove_child(panel)
	live_panel.queue_free()
	remove_child(live_panel)
	_done()
