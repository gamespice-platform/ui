extends "stack_checks.gd"

## The settings screen, key-binding and input-binding sections of the dot-ui selftest.


# --- Bindings --------------------------------------------------------------


func _test_settings_screen() -> void:
	_section("settings screen")

	var stack := DotScreenStack.new()
	stack.register_service = false
	stack.manage_mouse = false
	add_child(stack)
	stack.setup()

	# A bare DotConfig first: the screen has to work without dot-settings existing at all,
	# which is the case every project that has dot-ui and not dot-settings is in.
	var direct := TestConfig.new()
	var plain := DotSettingsScreen.new()
	plain.name = "PlainSettings"
	_check(plain.build(direct).ok, "a screen builds straight onto a DotConfig")
	stack.register(plain)
	stack.push(&"settings")
	await get_tree().process_frame
	await get_tree().process_frame

	# The one thing an assertion reaches about a Control, and this family has shipped a
	# 0 x 0 one twice.
	_check(plain.size.x > 0.0 and plain.size.y > 0.0, "and it has a size")
	var body := plain.get_node_or_null("Panel") as Control
	_check(body != null and body.size.y > 0.0, "and so does the panel inside it")
	_check(
		plain.get_node_or_null(plain.initial_focus) != null,
		"with a focus path that resolves, which get_path() before the tree does not"
	)

	# THE CHECK A PICTURE HAD TO FIND FIRST.
	#
	# A `DotSettingsPanel` is as tall as the document it was handed, and `DotUiConfig` alone
	# comes out around 600 pixels. Without a scroll container the column grew past the panel
	# and past the bottom of the SCREEN, taking Apply, Revert and Back with it -- a settings
	# screen a player can read and cannot save from or leave. Every assertion passed: the
	# screen had a size, the panel had a size, the editors existed, and Apply worked when
	# called in code.
	# A STRUCTURAL CHECK, DELIBERATELY, because the behavioural ones cannot fail here.
	#
	# The bug was the panel growing past the bottom of the window and taking Apply, Revert
	# and Back with it — a settings screen a player can read and cannot save from. Three
	# assertions were tried against it and all three passed with the bug in place:
	#
	#   "Apply is inside the panel"   — a PanelContainer GROWS to fit, so the button stays
	#                                   inside a panel that has itself left the window.
	#   "Apply is inside the screen"  — a headless viewport is 64 x 64, so every screen in
	#                                   this suite is 64 x 64 and nothing measured against
	#                                   one means anything. `plain.size.y > 0` passes at 64
	#                                   as happily as at 800.
	#   "a long and a short document  — at 64 x 64 the layout resolves the same either way.
	#    make the same-sized panel"
	#
	# Each was armed by replacing the ScrollContainer with a plain box and re-running; none
	# fired. So the guard is the structure plus the reason, and the actual guard is
	# `tools/screenshot.sh`. A check that reports its healthy case while blind is the shape
	# this family stopped reading `tools/check.sh` over, and shipping one here would have
	# been worse than shipping none.
	var apply_button := plain.get_node_or_null("Panel/Column/Buttons/Apply") as Control
	_check(apply_button != null, "the panel has an Apply button")

	_check(
		plain.get_node_or_null("Panel/Column/Scroll") is ScrollContainer,
		"and the rows are in a scroll container",
		"a DotSettingsPanel is as tall as the document it was handed; without this the "
		+ "column grows past the panel and past the bottom of the window, taking Apply, "
		+ "Revert and Back with it"
	)
	_check(
		panel_parent_of(plain) is ScrollContainer,
		"with the panel inside it and the buttons outside, so they stay reachable"
	)

	plain.panel._edited("port", 4242)
	plain.apply()
	_check(
		direct.port == 4242,
		"Apply writes straight through when the source IS the config (%d)" % direct.port
	)
	stack.pop()

	# And the two-step, which is the reason this screen exists. `to_config()` hands out a
	# SNAPSHOT: a screen that called only `panel.apply()` would report success and change
	# nothing, for ever, and every check above would still pass.
	var source := FakeSettingsSource.new()
	var screen := DotSettingsScreen.new()
	screen.name = "SourceSettings"
	# Its own id, because the stack registers by id and `plain` already holds the default.
	# A second screen under one name is refused or silently replaces the first, and the
	# menu button then opens the wrong document -- which is what this test did first.
	screen.id_override = &"player_settings"
	_check(screen.build(source).ok, "a screen builds onto a source that is not a config")
	_check(
		stack.register(screen).ok,
		"and registers beside the other one rather than replacing it"
	)

	var announced: Array[PackedStringArray] = []
	screen.applied.connect(func(keys: PackedStringArray) -> void: announced.append(keys))

	stack.push(&"player_settings")
	await get_tree().process_frame

	screen.panel._edited("port", 9001)
	screen.apply()
	_check(source.absorbed == 1, "Apply hands the snapshot back to the source")
	_check(
		int(source.stored["port"]) == 9001,
		"and the source has the new value (%s)" % source.stored["port"]
	)
	_check(
		announced.size() == 1 and Array(announced[0]) == ["port"],
		"announcing which keys changed, rather than that something did"
	)

	# Opened twice. The snapshot is taken at bind time, so a screen that did not re-read
	# would show whatever was true when it was built -- and Apply would put it back.
	stack.pop()
	source.stored["port"] = 7

	stack.push(&"player_settings")
	await get_tree().process_frame
	_check(
		(screen.config as TestConfig).port == 7,
		"re-opening re-reads the source rather than showing a stale snapshot (%d)"
			% (screen.config as TestConfig).port
	)

	var orphan := DotSettingsScreen.new()
	_check(not orphan.build(null).ok, "a screen with nothing to edit is refused")
	orphan.free()

	# The pause menu beside it, for the same reason: four games wrote the same forty lines.
	var pause := DotPauseScreen.new()
	pause.name = "Pause"
	_check(
		pause.build(PackedStringArray(["Resume", "Rock the vote", "Leave"])).ok,
		"a pause menu builds from a list of labels"
	)
	_check(
		Array(pause.ids()) == [&"resume", &"rock_the_vote", &"leave"],
		"whose ids are DERIVED from the labels, so two lists cannot disagree (%s)"
			% [pause.ids()]
	)
	_check(stack.register(pause).ok, "and registers")
	stack.push(&"pause")
	await get_tree().process_frame
	await get_tree().process_frame

	# THAT THE PUSH LANDED, which nothing asserted and a rendered frame is what found.
	#
	# `DotScreen`'s default id is the NODE NAME, so a screen called `Pause` registered as
	# `&"Pause"` and `push(&"pause")` answered "no such screen" -- reported, not fatal, so
	# the menu simply never opened. Every check below this line passed anyway: a registered
	# screen is sized and focusable whether or not it is on screen. A test that asserts
	# only the things that are true either way is a test that passes for the wrong reason.
	_check(stack.top_id() == &"pause", "and OPENS, rather than registering under its node name")
	_check(pause.visible, "so the screen is actually visible")

	_check(pause.size.x > 0.0 and pause.size.y > 0.0, "and it has a size")
	_check(
		pause.get_node_or_null(pause.initial_focus) != null,
		"with a focus path that resolves to the first button"
	)

	var pressed: Array[StringName] = []
	pause.chosen.connect(func(id: StringName) -> void: pressed.append(id))
	pause.button(&"rock_the_vote").pressed.emit()
	_check(
		pressed == [&"rock_the_vote"],
		"pressing one announces which, rather than which index"
	)
	_check(pause.button(&"nothing_like_this") == null, "and a button nobody made is null")

	var empty := DotPauseScreen.new()
	_check(
		not empty.build(PackedStringArray()).ok,
		"a pause menu with no buttons is refused, because it could not be left"
	)
	empty.free()

	stack.clear()
	stack.queue_free()
	_done()


## The node a settings screen's panel is parented to.
##
## A helper rather than a path, so the check reads as "the panel is inside a scroll" rather
## than as a string that silently stops matching when the tree changes shape.
func panel_parent_of(screen: DotSettingsScreen) -> Node:
	return screen.panel.get_parent() if screen.panel != null else null


func _test_bindings() -> void:
	_section("bindings")

	for action in [&"test_fire", &"test_jump", &"test_use"]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)

	var fire := InputEventKey.new()
	fire.physical_keycode = KEY_F
	InputMap.action_add_event(&"test_fire", fire)

	var jump := InputEventKey.new()
	jump.physical_keycode = KEY_SPACE
	InputMap.action_add_event(&"test_jump", jump)

	var panel := DotBindingsPanel.new()
	panel.config = DotUiConfig.new()
	panel.config.bindings_file = BINDINGS_FILE
	panel.prefix = "test_"
	add_child(panel)

	var built := panel.build()
	_check(built.ok and int(built.value) == 3, "a row per rebindable action",
		str(built.value))
	_check(
		panel.rebindable_actions().size() == 3,
		"and Godot's own ui_ actions are left out"
	)
	_check(
		panel.describe_binding(&"test_fire") == "F",
		"a binding reads back",
		panel.describe_binding(&"test_fire")
	)
	_check(
		panel.describe_binding(&"test_use") == "—",
		"and an unbound action says so"
	)

	# The conflict, detected before committing so a refusal changes nothing.
	var taken := InputEventKey.new()
	taken.physical_keycode = KEY_SPACE
	var clash := panel.bind_action(&"test_fire", taken)
	_check(not clash.ok, "binding a key another action has is refused")
	_check(
		panel.describe_binding(&"test_fire") == "F",
		"and the old binding is untouched"
	)
	_check(
		panel.conflicting_action(&"test_fire", taken) == &"test_jump",
		"with the conflicting action named"
	)

	var free_key := InputEventKey.new()
	free_key.physical_keycode = KEY_G
	_check(panel.bind_action(&"test_fire", free_key).ok, "a free key binds")
	_check(panel.describe_binding(&"test_fire") == "G", "and takes effect")

	panel.refuse_conflicts = false
	_check(
		panel.bind_action(&"test_fire", taken).ok,
		"conflicts can be permitted deliberately"
	)
	panel.refuse_conflicts = true
	panel.bind_action(&"test_fire", free_key)

	# Persistence, through DotPaths so a web build's IndexedDB is flushed.
	DotPaths.remove_tree(BINDINGS_FILE)
	_check(panel.save().ok, "bindings save")

	var restore := InputEventKey.new()
	restore.physical_keycode = KEY_Z
	panel.refuse_conflicts = false
	panel.bind_action(&"test_fire", restore)
	panel.refuse_conflicts = true
	_check(panel.describe_binding(&"test_fire") == "Z", "then are changed")

	var loaded := panel.load_saved()
	_check(loaded.ok, "and load back")
	_check(
		panel.describe_binding(&"test_fire") == "G",
		"restoring what was saved",
		panel.describe_binding(&"test_fire")
	)

	# The one that leaves a player stuck: a truncated or hand-edited file that gives
	# an action no events at all.
	DotPaths.write_json(
		BINDINGS_FILE, {"bindings": {"test_fire": []}}, true, true
	)
	panel.load_saved()
	_check(
		panel.describe_binding(&"test_fire") != "—",
		"an action a saved file leaves unbound is put back to its default",
		panel.describe_binding(&"test_fire")
	)

	# A garbage file must not be applied as though it were valid.
	DotPaths.write_json(BINDINGS_FILE, {"nonsense": 1}, true, true)
	_check(
		not panel.load_saved().ok,
		"a bindings file with no bindings is refused"
	)

	# Locked actions are never offered.
	panel.config.locked_actions = [&"test_fire"]
	_check(
		not panel.rebindable_actions().has(&"test_fire"),
		"a locked action is not rebindable"
	)

	panel.reset_all()
	panel.queue_free()
	remove_child(panel)

	for action in [&"test_fire", &"test_jump", &"test_use"]:
		InputMap.erase_action(action)

	# SORTED AS STRINGS, AND THE LABEL DROPS THE PREFIX.
	#
	# `Array.sort()` on a `StringName` compares interned POINTERS, so this method's own
	# "sorted" was whatever order the names happened to be created in -- and unstable
	# between builds, since it depends on which script interned each name first. It is the
	# same trap that gave two peers two different wire ids for one message type in dot-net.
	# A rendered frame of game-fatal-contact's rebinder is what showed it; nothing about the
	# CONTENTS of the array could.
	InputMap.add_action("probe_zulu")
	InputMap.add_action("probe_alpha")
	InputMap.add_action("probe_mike")

	var sorted_panel := DotBindingsPanel.new()
	sorted_panel.prefix = "probe_"
	add_child(sorted_panel)
	sorted_panel.build()

	var listed := PackedStringArray()
	for action in sorted_panel.rebindable_actions():
		listed.append(String(action))

	_check(
		Array(listed) == ["probe_alpha", "probe_mike", "probe_zulu"],
		"rebindable actions come out in alphabetical order (%s)" % [listed],
		"Array.sort() on a StringName compares interned pointers, not text"
	)

	# One HBox per action, named `Row_<action>`, with the label as its first child.
	var label_texts := PackedStringArray()

	for child in sorted_panel.get_children():
		var row := child as Control
		if row == null:
			continue
		var l := row.get_child(0) as Label if row.get_child_count() > 0 else null
		if l != null:
			label_texts.append(l.text)

	_check(
		Array(label_texts).has("Alpha") and not Array(label_texts).has("Probe Alpha"),
		"and the label drops the prefix, which is the part that is not information (%s)"
			% [label_texts]
	)

	# [b]A game's bindable actions are not all in one namespace.[/b] A first-person game's
	# movement is `dot_fps_*` and its chat key is its own `<game>_chat`; a panel filtered on
	# one prefix showed one of those and silently dropped the other, which is an action a
	# player cannot discover on any screen.
	InputMap.add_action("other_chat")

	var two_panel := DotBindingsPanel.new()
	two_panel.prefix = "probe_"
	two_panel.also_prefixed = PackedStringArray(["other_"])
	add_child(two_panel)
	two_panel.build()

	var both := PackedStringArray()
	for action in two_panel.rebindable_actions():
		both.append(String(action))

	_check(
		Array(both).has("other_chat") and Array(both).has("probe_alpha"),
		"a second prefix shows the actions the first one filtered out (%s)" % [both]
	)

	var two_labels := PackedStringArray()
	for child in two_panel.get_children():
		var row := child as Control
		if row == null or row.get_child_count() == 0:
			continue
		var l := row.get_child(0) as Label
		if l != null:
			two_labels.append(l.text)

	_check(
		Array(two_labels).has("Chat") and not Array(two_labels).has("Other Chat"),
		"and the prefix that MATCHED is the one stripped from the label (%s)" % [two_labels]
	)

	two_panel.queue_free()
	InputMap.erase_action("other_chat")

	sorted_panel.queue_free()
	for name_str in ["probe_zulu", "probe_alpha", "probe_mike"]:
		InputMap.erase_action(name_str)
	_done()


# --- The binding codec -----------------------------------------------------

func _test_input_binding() -> void:
	print("")
	_section("input binding text")

	var y := InputEventKey.new()
	y.physical_keycode = KEY_Y

	_check(DotInputBinding.to_text(y) == "Y", "a key is its own name")

	var back := DotInputBinding.from_text("Y") as InputEventKey
	_check(
		back != null and back.physical_keycode == KEY_Y,
		"and reads back as the same PHYSICAL key",
		"a keycode round-trip binds the wrong key on a non-QWERTY layout"
	)

	var shifted := InputEventKey.new()
	shifted.physical_keycode = KEY_A
	shifted.shift_pressed = true

	var shift_text := DotInputBinding.to_text(shifted)
	var shift_back := DotInputBinding.from_text(shift_text) as InputEventKey
	_check(
		shift_back != null and shift_back.physical_keycode == KEY_A and shift_back.shift_pressed,
		"a modifier survives the round trip (%s)" % shift_text
	)

	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	_check(DotInputBinding.to_text(mouse) == "Mouse 3", "a mouse button has a short form")
	_check(
		(DotInputBinding.from_text("Mouse 3") as InputEventMouseButton) != null,
		"and comes back as a mouse button"
	)

	# The wheel and the side buttons are written by name (API level 2). Godot numbers the
	# wheel 4 to 7, so "Mouse 4" was the wheel while a player reads it as the thumb button.
	var expected := {
		MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
		MOUSE_BUTTON_WHEEL_LEFT: "Wheel left", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel right",
		MOUSE_BUTTON_XBUTTON1: "Mouse back", MOUSE_BUTTON_XBUTTON2: "Mouse forward",
	}
	var written: Array[String] = []
	var read_back: Array[String] = []
	for index in expected:
		var named := InputEventMouseButton.new()
		named.button_index = index as MouseButton
		var text := DotInputBinding.to_text(named)
		if text != str(expected[index]):
			written.append("%d -> %s" % [index, text])
		var again := DotInputBinding.from_text(str(expected[index])) as InputEventMouseButton
		if again == null or again.button_index != index:
			read_back.append(str(expected[index]))
	_check(written.is_empty(), "the wheel and the side buttons are written by name", ", ".join(written))
	_check(read_back.is_empty(), "and every name reads back as its own button", ", ".join(read_back))
	var lower := DotInputBinding.from_text("  wheel DOWN ") as InputEventMouseButton
	_check(
		lower != null and lower.button_index == MOUSE_BUTTON_WHEEL_DOWN,
		"a name typed by hand in any case still reads"
	)

	# The old spelling. Every binding stored before the names says "Mouse 4" for the wheel
	# up; reading it as anything else rebinds a player's previous-weapon key on upgrade.
	var old_up := DotInputBinding.from_text("Mouse 4") as InputEventMouseButton
	var old_down := DotInputBinding.from_text("Mouse 5") as InputEventMouseButton
	_check(
		old_up != null and old_up.button_index == MOUSE_BUTTON_WHEEL_UP
			and old_down != null and old_down.button_index == MOUSE_BUTTON_WHEEL_DOWN,
		"the old \"Mouse 4\" / \"Mouse 5\" still read as the wheel",
		"a stored binding from before the names would move to another button"
	)
	_check(
		DotInputBinding.to_text(old_up) == "Wheel up",
		"and an old binding is written back under its new name"
	)
	_check(
		(DotInputBinding.from_text("Mouse 8") as InputEventMouseButton).button_index == MOUSE_BUTTON_XBUTTON1,
		"a numbered side button still reads"
	)
	_check(
		DotBindingsPanel.event_name(old_up) == "Wheel up",
		"the rebinding screen draws the same word as the settings file"
	)

	_check(DotInputBinding.from_text("") == null, "nothing is bound to nothing")
	_check(DotInputBinding.from_text("Qwerty") == null, "and so is a word that is not a key")
	_check(not DotInputBinding.is_bound("Qwerty"), "is_bound agrees")

	# The replacement rule. `action_add_event` on an action that already has one leaves
	# BOTH bound, so a rebound key still works on its old one — invisible until a player
	# rebinds crouch onto their forward key and both still fire.
	DotInputBinding.apply(&"probe_chat", "Y")
	DotInputBinding.apply(&"probe_chat", "T")

	_check(
		InputMap.action_get_events(&"probe_chat").size() == 1,
		"applying a binding twice leaves one binding, not two",
		"a rebound action that still answers to its old key"
	)
	_check(
		DotInputBinding.describe_action(&"probe_chat") == "T",
		"and it is the new one"
	)

	# ensure_action is the boot path: it must never overwrite what a player chose.
	DotInputBinding.ensure_action(&"probe_chat", "Y")
	_check(
		DotInputBinding.describe_action(&"probe_chat") == "T",
		"ensure_action leaves an action that already has a binding alone"
	)

	DotInputBinding.apply(&"probe_chat", "")
	_check(
		InputMap.has_action(&"probe_chat")
			and InputMap.action_get_events(&"probe_chat").is_empty(),
		"an empty binding unbinds the action rather than deleting it"
	)
	DotInputBinding.ensure_action(&"probe_chat", "Y")
	_check(
		DotInputBinding.describe_action(&"probe_chat") == "Y",
		"and ensure_action then gives an unbound action its default back"
	)

	_check(
		DotInputBinding.describe_action(&"probe_missing") == "",
		"an action that does not exist describes as nothing rather than erroring"
	)

	InputMap.erase_action(&"probe_chat")
	_done()
