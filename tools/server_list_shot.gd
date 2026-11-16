extends SceneTree

## Renders DotServerList at 1280x720, 390x844 and 844x390 over the Gamespice background to
## screenshots/server_list_<w>x<h>.png, one row selected and focused so the ring shows.
## Run through tools/server_list_shot.sh (xvfb-run, not --headless).

const OUT := "res://screenshots"
const SIZES := [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]


func _initialize() -> void:
	root.size = SIZES[0]
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var floor_rect := ColorRect.new()
	floor_rect.color = DotUiGamespice.BG
	floor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(floor_rect)

	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, 16)
	root.add_child(holder)
	var list := DotServerList.new()
	holder.add_child(list)
	list.set_rows(_fixture())
	list.set_status("5 of 6 answering.")
	list.select("203.0.113.7:27015")

	for size in SIZES:
		root.size = size
		await _frames(4)
		list.row_button("203.0.113.7:27015").grab_focus()
		await _shot("server_list_%dx%d" % [size.x, size.y])
	quit(0)


func _fixture() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names := [
		["Fatal Contact EU #1 | 16v16 CTF | fast respawn", "ctf_orange_x3", 28, 32, 34],
		["Gamespice Official", "dm_ashpit", 9, 16, 61],
		["PLAYLOT sandbox", "playlot_park", 4, 24, 118],
		["Late-night deathmatch", "dm_foundry", 12, 12, 190],
		["Local test", "dm_box", 0, 8, 2],
	]
	var at := 0
	for n in names:
		out.append({"address": "203.0.113.%d:27015" % (at + 5), "name": n[0], "map": n[1], "players": n[2],
			"max_players": n[3], "ping_ms": n[4], "status": "online"})
		at += 1
	out.append({"address": "198.51.100.9:27015", "name": "", "map": "", "status": "offline"})
	return out


func _shot(name: String) -> void:
	await _frames(4)
	var err := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("%s %s" % ["wrote" if err == OK else "FAILED", name])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
