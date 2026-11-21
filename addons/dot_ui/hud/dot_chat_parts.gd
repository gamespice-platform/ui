class_name GSChatParts
extends RefCounted

## The nodes inside a [GSChatWindow], and the two views it draws them with. Kept out of the
## window so the window is the behaviour and this is the construction.
##
## [b]Every offset is set, and all four of them AFTER the anchors.[/b] Assigning
## `anchor_right` RECOMPUTES the offsets to preserve the control's current rectangle, and a
## control built in code has no rectangle yet, so `anchor_right = 1.0` on a fresh Control
## sets `offset_right` to minus the parent's width and the thing stays nought pixels wide.
## It then draws nothing while every property about it reads correctly.

const SELF_MUTE_SERVICE := &"dot_self_mute"
const SELF_MUTE_SCRIPT := "res://addons/dot_chat/runtime/dot_chat_self_mute.gd"


## Anchors to the bottom edge and then offsets, in that order.
static func anchor_bottom_strip(control: Control, top: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = top
	control.offset_right = 0.0
	control.offset_bottom = bottom


## A feed in the window's look, anchored above the entry and [param rows] tall.
static func make_feed(window: GSChatWindow, node_name: String, rows: int) -> GSFeedView:
	var feed := GSFeedView.new()
	feed.name = node_name
	feed.max_lines = rows
	feed.newest_last = true
	feed.alignment = HORIZONTAL_ALIGNMENT_LEFT
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.line_height = window.line_height
	feed.line_gap = window.line_gap
	feed.outline_size = window.outline_size
	var tall := float(rows) * (window.line_height + window.line_gap)
	anchor_bottom_strip(feed, -(tall + window.entry_height), -window.entry_height)
	return feed


## The prompt and the line being typed in, in one row along the bottom.
static func make_entry_row(window: GSChatWindow) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = "Entry"
	anchor_bottom_strip(row, -window.entry_height, 0.0)

	var prompt := Label.new()
	prompt.name = "Prompt"
	row.add_child(prompt)

	var entry := LineEdit.new()
	entry.name = "Line"
	entry.max_length = window.max_length
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.caret_blink = true
	row.add_child(entry)
	return {"row": row, "prompt": prompt, "entry": entry}


## Fills [param view] with the window of [param rows] the scroll position says.
##
## [b]Rebuilt, not shifted.[/b] A view of twelve rows is twelve `add_line` calls, which is
## nothing next to a frame, and a view built from the history every time cannot drift out
## of step with it.
static func show_history(window: GSChatWindow, view: GSFeedView, rows: Array, scroll: int) -> void:
	var end := rows.size() - scroll
	var start := maxi(0, end - window.history_lines)

	view.clear()

	for i in range(start, end):
		view.add_line(rows[i])

	# A reader scrolled back is told there is more below, in the last row.
	if scroll > 0 and view.line_count() > 0:
		var lines := view.lines()
		lines[lines.size() - 1] = {
			"parts": [{"text": "▼ %d newer — Page Down" % scroll, "colour": Color(0.70, 0.72, 0.78)}],
			"at_ms": Time.get_ticks_msec(),
		}

	# Sized to its rows: GSFeedView draws from its top edge, so a view twelve rows tall
	# holding five drew them at the top with a gap over the entry.
	var shown := maxi(view.line_count(), 1)
	view.offset_top = -(float(shown) * (window.line_height + window.line_gap) + window.entry_height)
	view.queue_redraw()


## The shared block list: registry `dot_self_mute`, else GameSpice Chat's script by path, else null.
static func find_self_mute() -> Object:
	var found: Object = GSRegistry.get_service(SELF_MUTE_SERVICE)

	if found == null and ResourceLoader.exists(SELF_MUTE_SCRIPT):
		var script: Variant = load(SELF_MUTE_SCRIPT)
		if script is Script and (script as Script).can_instantiate():
			var shared: Variant = (script as Script).call(&"shared")
			found = shared if shared is Object else null

	return found


const DEFAULT_COLOUR := Color(0.88, 0.90, 0.94)


static func index_of(channels: Array[Dictionary], id: StringName) -> int:
	for i in range(channels.size()):
		if StringName(str(channels[i].get("id", &""))) == id:
			return i
	return -1


static func label_of(channels: Array[Dictionary], id: StringName) -> String:
	var index := index_of(channels, id)
	return "Say" if index < 0 else str(channels[index].get("label", "Say"))


static func colour_of(channels: Array[Dictionary], id: StringName) -> Color:
	var index := index_of(channels, id)
	var colour: Variant = DEFAULT_COLOUR if index < 0 else channels[index].get("colour", DEFAULT_COLOUR)
	return colour if colour is Color else DEFAULT_COLOUR


## The first channel's id, or `all` for a box with none.
static func first_channel(channels: Array[Dictionary]) -> StringName:
	return &"all" if channels.is_empty() else StringName(str(channels[0].get("id", &"all")))


## The channel marked `"team": true`, or [param fallback] for a game with no teams.
static func team_channel(channels: Array[Dictionary], fallback: StringName) -> StringName:
	for entry in channels:
		if bool(entry.get("team", false)):
			return StringName(str(entry.get("id", &"all")))
	return fallback


## Creates the open, team and cycle actions the project lacks, at the window's default bindings.
static func register_actions(window: GSChatWindow) -> void:
	if window.open_action != &"":
		GSInputBinding.ensure_action(window.open_action, window.default_open_binding)
	if window.team_action != &"" and window.default_team_binding != "":
		GSInputBinding.ensure_action(window.team_action, window.default_team_binding)
	if window.cycle_action != &"" and window.default_cycle_binding != "":
		GSInputBinding.ensure_action(window.cycle_action, window.default_cycle_binding)

	# What the keys ENDED UP as, not what was asked for: ensure_action keeps a binding the
	# project or the player already has, so "Y does not open chat" is answered by this line.
	GSLog.debug(GSChatWindow.CHANNEL, "chat keys", {
		"open": GSInputBinding.describe_action(window.open_action),
		"team": GSInputBinding.describe_action(window.team_action),
		"cycle": GSInputBinding.describe_action(window.cycle_action),
	})
