@tool
class_name DotChatWindow
extends Control

## A chat box: a log that fades, a line to type in, and a key that opens it.
##
## [b]Why this is in dot-ui and not in dot-chat.[/b] dot-chat is the decision layer — who
## hears a line, what it may contain, what name is drawn beside it — and it ships no art
## on purpose. But every game in this family then wrote the same chat box, or, more often,
## wrote no chat box at all and shipped a game whose players could receive a line and
## never send one. Four clients here could be talked to and could not talk back.
##
## So this is the window, and it knows nothing about chat: it takes coloured fragments to
## draw and it emits the string somebody typed. A game hands [signal submitted] to
## whatever its send path already is — [code]DotClientChat.send[/code],
## [code]DotChatClient.compose[/code], a bridge's `say` — and feeds arriving lines back in
## through [method add_message]. dot-ui still depends on dot-core and nothing else.
##
## [codeblock]
## var chat := DotChatWindow.new()
## chat.submitted.connect(func(text: String, _channel: StringName) -> void:
##     link.chat.send(text))
## chat.opened.connect(func(_c: StringName) -> void: controller.suspended = true)
## chat.closed.connect(func() -> void: controller.suspended = false)
## add_child(chat)
## [/codeblock]
##
## [b]It does not touch the mouse mode, and it does not stop the player moving.[/b] Both
## are the game's, and both differ per game — a first-person client captures the mouse, a
## top-down one does not. A focused [LineEdit] keeps typed keys out of
## [method Node._unhandled_input], but it cannot do a thing about [method Input.is_action_pressed],
## which is polled straight off the device and does not care what consumed the event. Every
## game here polls its movement. [b]So connect [signal opened] and [signal closed] to
## whatever suspends your controller[/b] — without that, typing "sw" walks you backwards.
##
## [b]The open key is an action, not a key.[/b] [member open_action] names an [InputMap]
## action so the binding is the player's, rebindable through [DotBindingsPanel] or stored
## in a settings document as text through [DotInputBinding]. A hardcoded [constant KEY_Y]
## is a key somebody cannot move, on a keyboard whose Y is somewhere else.

const CHANNEL := "ui.chat"

## Somebody pressed enter on a non-empty line. [param text] is raw and unsanitised.
##
## [b]Unsanitised on purpose.[/b] The server decides what a line may contain and its answer
## is the only one that counts; a window that filtered first would be a second filter that
## drifts from the real one, and it would teach players their text was accepted when the
## thing that accepts it has not seen it yet.
signal submitted(text: String, channel: StringName)

## The box opened on a channel. A game suspends its controller here.
signal opened(channel: StringName)

## The box closed, whether the line was sent or abandoned.
signal closed()

## The player moved to another channel while the box was open.
signal channel_changed(channel: StringName)

@export_group("Input")

## The action that opens the box. Created at the default binding if the project has none.
@export var open_action: StringName = &"chat_open"

## The action that opens it on [member team_channel]. Empty for a game with no teams.
@export var team_action: StringName = &"chat_open_team"

## The action that moves to the next channel while the box is open. Empty to disable.
@export var cycle_action: StringName = &"chat_cycle"

## Bindings used only when the project does not already declare the action.
##
## [b]Y, because that is where this genre has put it for twenty-five years[/b] and muscle
## memory from the genre is worth more than a tidier layout. U is team chat for the same
## reason. A game that disagrees sets these; a player who disagrees rebinds them, and a
## rebinding is what the project's own input map or a settings document then carries.
@export var default_open_binding: String = "Y"
@export var default_team_binding: String = "U"
@export var default_cycle_binding: String = ""

## Whether to create missing actions at the default bindings at all.
##
## [b]Off for a shipped game whose input map is the project's.[/b] On, this is what makes
## a chat box work in a game that has not been told about chat yet, which is every game
## in this family the day before it is wired up.
@export var register_actions: bool = true

@export_group("Behaviour")

## Whether the box can be opened at all.
##
## [b]The lines still arrive and are still drawn.[/b] A deployment that turns the box off
## because its players chat somewhere else — a web client embedded in a page that has its
## own chat, a relayed room — still wants the player to see what was said. Off means "you
## cannot type here", not "you are not in this conversation".
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not value and _open:
			close()

## Longest line the box will accept, in characters.
##
## The server has the real limit and refuses past it; this one is so a player finds out
## while typing rather than after sending.
@export_range(1, 1024, 1) var max_length: int = 127

## Rows drawn in the log, which is also what decides its height.
@export_range(1, 60, 1) var max_lines: int = 8

## Seconds a line stays on screen once the box is closed. Zero keeps them for ever.
@export_range(0.0, 120.0, 0.5) var lifetime_sec: float = 10.0

## How many sent lines the up arrow walks back through. Zero disables recall.
@export_range(0, 50, 1) var recall_limit: int = 12

@export_group("History")

## Rows kept after they have faded from the log, for reading back with the box open.
## Zero keeps none, and the open box shows only what the log still has.
##
## [b]Rows, not messages[/b], for the reason [member max_lines] is: a wrapped message is
## several, and the bound is on memory and on what a scroll walks through.
@export_range(0, 2000, 1) var history_limit: int = 200

## Rows drawn while the box is open. The closed log stays [member max_lines] tall, so a
## glance costs no more of the screen than it did; the open box grows upwards to show
## more, because opening it is asking to read.
@export_range(1, 60, 1) var history_lines: int = 12

## Rows one Page Up / Page Down moves. The mouse wheel moves a third of it.
@export_range(1, 60, 1) var history_page: int = 6

## What is drawn behind the log while the box is open. Transparent draws nothing.
##
## [b]Only while open.[/b] Closed, the log is outlined rather than panelled (see
## [DotFeedView]): a backing would be a dark rectangle in the corner of the view while
## nobody is talking. Open, the player is reading, the game behind it is not what they are
## looking at, and twelve rows of text over a busy floor want something under them.
@export var open_backdrop: Color = Color(0.0, 0.0, 0.05, 0.45)

@export_group("Layout")

## Anchor to the bottom left of the parent on ready.
##
## Off for a game that places the box itself, which is every game with a designed HUD.
## On is what makes this one line of setup.
##
## [b]Bottom left is also where health and armour usually go[/b], and a stat bar drawn
## through a line of chat is what the first picture of the two together showed. A game
## with anything in that corner places one of them.
@export var place_bottom_left: bool = true

## Inset from the left edge of the parent.
@export var margin_left: float = 16.0

## Inset from the bottom edge.
##
## [b]Separate from [member margin_left], because the thing in the way is never in both
## directions.[/b] A game with health and armour in the bottom-left corner needs the box
## lifted ABOVE them and still flush with the same left edge as everything else on the
## HUD; one margin for both would push it inwards to clear something below it.
@export var margin_bottom: float = 16.0
@export var width: float = 460.0
@export var entry_height: float = 26.0

## One drawn row.
##
## [b]Rows, not messages.[/b] A message too long for the box is wrapped across as many
## rows as it takes, so [member max_lines] bounds what is DRAWN — which is the number that
## has to agree with the height, because a log allowed more rows than it is tall draws the
## overflow straight through the entry field underneath it.
## Pixels of outline behind every line in the log. Zero draws none.
##
## Passed straight through to [DotFeedView]; see its own note for why an outline rather
## than a panel. A game over a bright map wants 4 or 5 and a game over a dark one can
## leave it off.
##
## [b]On by default[/b] since players on a pale map asked, in the chat itself, for a stroke
## around the text. A game over a dark world can still turn it off.
@export_range(0, 16, 1) var outline_size: int = 5

@export_range(8.0, 40.0, 1.0) var line_height: float = 18.0
@export_range(0.0, 20.0, 1.0) var line_gap: float = 2.0

## Channels the box can send on, in cycle order.
##
## `[{"id": StringName, "label": String, "colour": Color}]`. Dictionaries rather than
## [code]DotChatChannel[/code] for the reason [DotFeedView] takes them: dot-ui does not
## import dot-chat and does not know what a channel is. A game maps its own.
var channels: Array[Dictionary] = []

## Whether this box honours the player's own block list: `!sm` / `/sm` typed here run it and
## are never emitted, and [method add_said] drops a line from a muted player.
##
## [b]The one piece of chat this box knows, and why it is here.[/b] `sm` must never reach the
## server, or the muted player could be told; every game in the family sends what this box
## emits, by a different path each, so the only place that stops it in all of them is the
## place before [signal submitted]. The list itself is dot-chat's `DotChatSelfMute`, found
## by registry name or by path and duck-typed, so dot-ui still depends on dot-core alone.
@export var self_mute_enabled: bool = true

## The colour of what `sm` answers.
@export var self_mute_colour: Color = Color(0.72, 0.80, 0.90)

## The block list: anything with `claims_chat(text)`, `handle_chat(text)` and
## `is_muted(name)`. Null finds the shared one (registry `dot_self_mute`, else dot-chat's
## script by path) the first time it is needed.
var self_mute: Object = null

var _feed: DotFeedView = null
var _entry: LineEdit = null
var _prompt: Label = null
var _open: bool = false
var _channel: StringName = &""
var _sent: PackedStringArray = PackedStringArray()
var _recall: int = -1

## The view drawn while the box is open, over the history rather than the fading log.
var _history_view: DotFeedView = null

## Every row added, oldest first, bounded by [member history_limit]. Each is the parts
## array [DotFeedView] takes.
var _history: Array = []

## Rows scrolled up from the newest. Zero is following the conversation.
var _scroll: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if register_actions:
		DotChatParts.register_actions(self)

	if place_bottom_left:
		_place()

	_ensure_built()
	_apply_open_state()


## Builds the log and the entry, if they are not built yet.
##
## [b]Lazy rather than in [method Node._ready], and the difference is a line of chat.[/b]
## A host that creates this box and puts a line in it before the engine has readied it —
## a game announcing "connecting to %s", a fixture, anything built in
## [method SceneTree._initialize], where NOTHING is inside the tree yet — was writing into
## a log that did not exist, and the line vanished with nothing said. The screenshot that
## found this drew an empty box beside a kill feed with three lines in it.
##
## So every public method that needs the pieces asks for them first. Building children is
## safe outside the tree; only [method _place], which reads the parent, is not.
func _ensure_built() -> void:
	if _feed != null:
		return

	if channels.is_empty():
		channels = [{"id": &"all", "label": "Say", "colour": Color(0.88, 0.90, 0.94)}]

	if _channel == &"":
		_channel = StringName(str(channels[0].get("id", &"all")))

	_build()
	_apply_open_state()


func _place() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = margin_left
	offset_right = margin_left + width
	offset_top = -(_log_height() + entry_height + margin_bottom)
	offset_bottom = -margin_bottom


## How tall the log is: one row per line it is allowed to draw.
##
## Derived rather than exported beside [member max_lines]. Two numbers for one thing is
## two numbers that can disagree, and the way they disagree here is a log that draws
## through the field somebody is typing in.
func _log_height() -> float:
	return float(max_lines) * (line_height + line_gap)


## Keeps the newest row against the entry field as the log fills up.
func _relayout_log() -> void:
	if _feed == null:
		return

	var rows := clampi(_feed.line_count(), 1, max_lines)
	_feed.offset_top = -(float(rows) * (line_height + line_gap) + entry_height)


func _build() -> void:
	_feed = DotChatParts.make_feed(self, "Log", max_lines)
	_feed.lifetime_sec = lifetime_sec
	add_child(_feed)
	_feed.line_added.connect(func(_line: Dictionary) -> void: _relayout_log())
	_feed.line_expired.connect(func(_line: Dictionary) -> void: _relayout_log())

	# A second feed rather than the first one refilled: the closed log's lines carry the time
	# each arrived, which is what fades them, and refilling it would restart every clock.
	_history_view = DotChatParts.make_feed(self, "History", history_lines)
	_history_view.lifetime_sec = 0.0
	_history_view.hold = true
	_history_view.visible = false
	add_child(_history_view)
	_history_view.draw.connect(_draw_backdrop)

	var parts := DotChatParts.make_entry_row(self)
	add_child(parts["row"])
	_prompt = parts["prompt"]
	_entry = parts["entry"]
	_entry.text_submitted.connect(_on_submitted)
	_entry.gui_input.connect(_on_entry_gui_input)


# --- Opening and closing ---------------------------------------------------

## Opens the box on a channel, or on the current one.
func open(id: StringName = &"") -> void:
	_ensure_built()

	if not enabled or _open:
		return

	if id != &"" and _index_of(id) >= 0:
		_channel = id

	_open = true
	_recall = -1
	_scroll = 0
	_entry.text = ""
	_apply_open_state()

	# [b]Focus is grabbed a frame late, and that is not tidiness.[/b] The key that opened
	# the box is still being processed: focus it now and the same press can be delivered to
	# the LineEdit, which types the open key into the line. Every chat box that opens with
	# a "y" already in it has this bug.
	_entry.call_deferred("grab_focus")

	opened.emit(_channel)


## Closes the box. Anything typed is discarded.
func close() -> void:
	if not _open:
		return

	_open = false
	_entry.text = ""
	_entry.release_focus()
	_apply_open_state()
	closed.emit()


func toggle(id: StringName = &"") -> void:
	if _open:
		close()
	else:
		open(id)


func is_open() -> bool:
	return _open


## The channel the box would send on.
func channel() -> StringName:
	return _channel


## Moves to a channel by id. Ignored if the box does not have it.
func set_channel(id: StringName) -> void:
	if _index_of(id) < 0 or id == _channel:
		return

	_channel = id
	_apply_open_state()
	channel_changed.emit(_channel)


## Moves to the next channel in [member channels].
func cycle_channel() -> void:
	if channels.size() < 2:
		return

	var next := (_index_of(_channel) + 1) % channels.size()
	set_channel(StringName(str(channels[next].get("id", &"all"))))


func _apply_open_state() -> void:
	# The log holds its lines while the box is open: a message that fades out while you are
	# reading it is a message you have to ask somebody to repeat.
	if _feed != null:
		_feed.hold = _open
		_feed.visible = not _open or _history_view == null

	if _history_view != null:
		_history_view.visible = _open
		if _open:
			_show_history()

	if _prompt != null:
		_prompt.text = "%s: " % DotChatParts.label_of(channels, _channel)
		_prompt.add_theme_color_override("font_color", DotChatParts.colour_of(channels, _channel))

	if _entry != null:
		_entry.visible = _open
		_entry.editable = _open

	if _prompt != null:
		_prompt.visible = _open


func _index_of(id: StringName) -> int:
	return DotChatParts.index_of(channels, id)


# --- Input -----------------------------------------------------------------

## Opening. Runs only when nothing else wanted the key.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if _open:
		# A fallback, for a box that is open with the focus somewhere else — a player who
		# clicked the world behind it. Escape must always close this.
		if event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return

	if not enabled:
		return

	if _pressed(event, open_action):
		get_viewport().set_input_as_handled()
		open(DotChatParts.first_channel(channels))
		return

	if _pressed(event, team_action):
		get_viewport().set_input_as_handled()
		open(DotChatParts.team_channel(channels, _channel))


## The wheel scrolls the open history. In [method Node._input] rather than unhandled,
## because a game binds the wheel too (a weapon switch) and would otherwise act on the
## same notch the history did.
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventMouseButton):
		return

	var button := event as InputEventMouseButton

	if not button.pressed:
		return

	var notch := maxi(1, history_page / 3)

	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			scroll_history(notch)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			scroll_history(-notch)
			get_viewport().set_input_as_handled()


## True only for an action that exists. [method InputEvent.is_action_pressed] on an action
## the project does not have is an error per event, not a false — and a game that leaves
## [member register_actions] off has exactly that until it declares its own.
func _pressed(event: InputEvent, action: StringName) -> bool:
	if action == &"" or not InputMap.has_action(action):
		return false

	return event.is_action_pressed(action)


## Everything typed while the box is open, taken before the line edit sees it.
##
## [b]On the entry's own [signal Control.gui_input], not in [method Node._input].[/b]
## Godot delivers an event to [method Node._input] first, then to the focused control,
## then to shortcut and unhandled input. Consuming keys in `_input` to keep them away from
## the game therefore consumes them before the [LineEdit] — a chat box nobody can type in,
## which is what the first draft of this was. Here the box is already the focus owner, so
## what it does not accept is what the line edit gets.
func _on_entry_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return

	var key := event as InputEventKey

	match key.keycode:
		KEY_ESCAPE:
			close()
			_entry.accept_event()
			return
		KEY_UP:
			_recall_step(1)
			_entry.accept_event()
			return
		KEY_DOWN:
			_recall_step(-1)
			_entry.accept_event()
			return
		KEY_PAGEUP:
			scroll_history(history_page)
			_entry.accept_event()
			return
		KEY_PAGEDOWN:
			scroll_history(-history_page)
			_entry.accept_event()
			return
		KEY_TAB:
			# Tab is focus navigation everywhere else in a user interface, and focus
			# navigation out of a chat box is a box that stops taking letters with no
			# visible reason. It cycles the channel here, or it does nothing.
			if cycle_action == &"" or not InputMap.has_action(cycle_action):
				cycle_channel()
			_entry.accept_event()
			return

	if _pressed(event, cycle_action):
		cycle_channel()
		_entry.accept_event()


func _on_submitted(text: String) -> void:
	var trimmed := text.strip_edges()

	if trimmed != "":
		_remember(trimmed)
		if not _ran_locally(trimmed):
			submitted.emit(trimmed, _channel)

	close()


## Runs `!sm` / `/sm` here and says whether it did. A line it ran is never emitted.
func _ran_locally(text: String) -> bool:
	var mutes := _self_mute()
	if mutes == null or not mutes.has_method(&"claims_chat") or not bool(mutes.call(&"claims_chat", text)):
		return false
	var reply: Variant = mutes.call(&"handle_chat", text)
	if reply is PackedStringArray or reply is Array:
		for line in reply:
			add_text(str(line), self_mute_colour)
	return true


func _self_mute() -> Object:
	if not self_mute_enabled or Engine.is_editor_hint():
		return null
	if self_mute == null or not is_instance_valid(self_mute):
		self_mute = DotChatParts.find_self_mute()
	return self_mute


## Whether [param speaker] is on the player's block list.
func is_self_muted(speaker: String) -> bool:
	if speaker == "":
		return false
	var mutes := _self_mute()
	return mutes != null and mutes.has_method(&"is_muted") and bool(mutes.call(&"is_muted", speaker, ""))


func _remember(text: String) -> void:
	if recall_limit <= 0:
		return

	# Deduplicated at the head only: somebody saying "gg" twice in a row wants one entry,
	# and somebody who said it an hour ago wants their history in the order it happened.
	if _sent.size() > 0 and _sent[_sent.size() - 1] == text:
		return

	_sent.append(text)

	while _sent.size() > recall_limit:
		_sent.remove_at(0)


func _recall_step(direction: int) -> void:
	if _sent.is_empty():
		return

	_recall = clampi(_recall + direction, -1, _sent.size() - 1)

	if _recall < 0:
		_entry.text = ""
	else:
		_entry.text = _sent[_sent.size() - 1 - _recall]

	_entry.caret_column = _entry.text.length()


# --- Lines -----------------------------------------------------------------

## Adds a line built from coloured fragments, as [DotFeedView] takes them.
##
## Wrapped to the width of the box first. See [method _wrap].
func add_message(parts: Array) -> void:
	_ensure_built()

	if _feed == null:
		return

	var rows := _wrap(parts)

	for row in rows:
		_feed.add_line(row)
		_remember_row(row)

	if _open:
		# Somebody reading back keeps their place: the rows that just arrived went in
		# BELOW what they are looking at, so the offset from the newest grows with them.
		if _scroll > 0:
			_scroll = mini(_scroll + rows.size(), _max_scroll())
		_show_history()


## Splits one line into as many rows as it takes to fit the box; see [DotChatWrap].
##
## [b]Chat is the one feed that has to wrap, and it wraps rather than truncating[/b]: the
## text IS the content, and a player cannot ask the log to repeat itself. [DotFeedView]
## draws an entry as one run and does not clip it, which is right for a kill feed and
## wrong for a 127-character line in a 460-pixel box.
func _wrap(parts: Array) -> Array:
	var limit := _feed.size.x if _feed != null and _feed.size.x > 0.0 else width
	return DotChatWrap.wrap(parts, get_theme_default_font(), get_theme_default_font_size(), limit)



## Adds a one-colour line. What a system message is.
func add_text(text: String, colour: Color = Color(0.88, 0.90, 0.94)) -> void:
	add_message([{"text": text, "colour": colour}])


## Adds a line as a chat message usually arrives: a name, then what they said.
func add_said(
	speaker: String,
	text: String,
	speaker_colour: Color = Color(0.62, 0.78, 1.0),
	text_colour: Color = Color(0.88, 0.90, 0.94)
) -> void:
	_ensure_built()
	if _feed == null:
		return

	if speaker == "":
		add_text(text, text_colour)
		return

	# A player the reader muted (`sm`). Here as well as in dot-chat's client, because
	# some games draw a line without one.
	if is_self_muted(speaker):
		return

	add_message([
		{"text": "%s:" % speaker, "colour": speaker_colour},
		{"text": text, "colour": text_colour},
	])


func clear() -> void:
	_ensure_built()
	if _feed != null:
		_feed.clear()
	_history.clear()
	_scroll = 0
	if _history_view != null:
		_history_view.clear()


# --- History ---------------------------------------------------------------

func _remember_row(row: Array) -> void:
	if history_limit <= 0:
		return

	_history.append(row)

	while _history.size() > history_limit:
		_history.remove_at(0)


## The rows a reader can scroll through: the kept history, or what the log still holds
## when nothing is kept.
func _rows() -> Array:
	if history_limit > 0:
		return _history

	var out: Array = []
	if _feed != null:
		for line in _feed.lines():
			out.append(line["parts"])
	return out


func _max_scroll() -> int:
	return maxi(0, _rows().size() - history_lines)


## Moves the open view by [param rows]: positive is back in time. Returns where it ended,
## in rows up from the newest.
func scroll_history(rows: int) -> int:
	_ensure_built()
	_scroll = clampi(_scroll + rows, 0, _max_scroll())
	if _open:
		_show_history()
	return _scroll


## How far up the open view is scrolled, in rows. Zero is the newest.
func history_scroll() -> int:
	return _scroll


## Every row kept, oldest first, each the fragments it was drawn with.
func history() -> Array:
	return _rows().duplicate()


## Draws the window of the history the scroll position says.
func _show_history() -> void:
	if _history_view != null:
		DotChatParts.show_history(self, _history_view, _rows(), _scroll)


func _draw_backdrop() -> void:
	if _history_view == null or open_backdrop.a <= 0.0:
		return

	var top := -line_gap * 2.0
	var height := _history_view.size.y - top

	# On the view's own `draw` signal, which Godot emits BEFORE the view's `_draw` — so the
	# rectangle is under the text without a third node, and it is exactly as tall as the
	# rows drawn (the view is sized to them) and down through the entry.
	_history_view.draw_rect(Rect2(-6.0, top, _history_view.size.x + 12.0, height + entry_height), open_backdrop)


## The log, for a game that wants to tune it further.
func feed() -> DotFeedView:
	_ensure_built()
	return _feed


## The line being typed in, for a game that wants to theme it.
func entry() -> LineEdit:
	_ensure_built()
	return _entry


func line_count() -> int:
	_ensure_built()
	return 0 if _feed == null else _feed.line_count()


func describe() -> Dictionary:
	return {
		"enabled": enabled,
		"open": _open,
		"channel": String(_channel),
		"channels": channels.size(),
		"lines": line_count(),
		"open_binding": DotInputBinding.describe_action(open_action),
		"team_binding": DotInputBinding.describe_action(team_action),
		"recalled": _sent.size(),
		"history": _rows().size(),
		"scroll": _scroll,
	}


func describe_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var state := describe()

	for key in state:
		out.append("%s: %s" % [key, str(state[key])])

	return out
