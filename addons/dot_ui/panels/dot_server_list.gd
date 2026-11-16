class_name DotServerList
extends PanelContainer

## A server list a player can read on a phone and drive with a pad: a heading, a search,
## an address box, one focusable row per server and a Join button.
##
## [b]Rows are dictionaries, so this names nothing outside dot-core.[/b] dot-browser ships no
## window on purpose and says dot-ui gives its rows somewhere to go; this is that place.
## [code]DotBrowserEntry.to_row()[/code] makes exactly the keys read here: [code]address[/code],
## [code]name[/code], [code]map[/code], [code]players[/code], [code]max_players[/code],
## [code]ping_ms[/code], [code]status[/code] ("online" or anything else) and [code]secure[/code].
##
## [b]Selecting is not joining.[/b] A row press selects; Join (or [method join_selected])
## joins. A list where a tap joins is a list where a mis-tap leaves the menu.
##
## Rows are kept by address and updated in place, so a refresh that lands while a pad has a
## row focused leaves the focus where it was.

const CHANNEL := "ui.servers"

## The player asked to join [param address].
signal join_requested(address: String)

## The player asked for the list to be asked again.
signal refresh_requested()

## The player typed an address and pressed Add (or Enter).
signal address_added(address: String)

## The selected row changed. Empty when the selection went away.
signal selection_changed(address: String)

@export_group("Text")

@export var title: String = "Servers"
## The small line above the title. Empty hides it.
@export var eyebrow_text: String = "Play online"
@export var empty_text: String = "No servers answered yet. Refresh, or add an address."

@export_group("Layout")

## Show the address box and Add. Off for a game that only lists a site's servers.
@export var show_address_entry: bool = true

## Narrower than this (in this control's pixels), a row stacks the map, players and ping
## under the name instead of in columns. 0 never stacks.
@export_range(0.0, 4096.0, 1.0, "or_greater") var compact_below: float = 640.0

## Shorter than this, the address box joins the footer line so a landscape phone keeps room
## for rows. 0 never moves it.
@export_range(0.0, 4096.0, 1.0, "or_greater") var short_below: float = 480.0

## Rows drawn after filtering. 0 is all of them.
@export_range(0, 100000, 1, "or_greater") var max_rows: int = 0

## A row's least height, so a thumb can hit it.
@export_range(0.0, 200.0, 1.0, "or_greater") var row_height: float = 52.0

@export_group("Look")

## Dress the list in [DotUiGamespice]. Off, it inherits whatever Theme its parent has and a
## selected row is a pressed toggle.
@export var gamespice: bool = true

## Pings at or under this read as good, at or under [member fair_ping_ms] as fair, and
## anything slower as poor.
@export_range(0, 10000, 1, "or_greater") var good_ping_ms: int = 80
@export_range(0, 10000, 1, "or_greater") var fair_ping_ms: int = 160

var _rows: Array[Dictionary] = []
var _selected: String = ""
var _compact: bool = false
var _short: bool = false

## address -> Button, the rows on screen.
var _buttons: Dictionary = {}

var _title: Label = null
var _eyebrow: Label = null
var _search: LineEdit = null
var _address: LineEdit = null
var _add: Button = null
var _refresh: Button = null
var _join: Button = null
var _status: Label = null
var _empty: Label = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _box: VBoxContainer = null
var _entry: HBoxContainer = null
var _foot: HBoxContainer = null


func _init() -> void:
	name = "ServerList"


func _ready() -> void:
	if _list == null:
		_build()


## Replaces the rows. Order is kept (sort before calling); rows with no address are skipped.
func set_rows(rows: Array) -> void:
	_rows.clear()
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row := raw as Dictionary
		if str(row.get("address", "")).strip_edges().is_empty():
			continue
		_rows.append(row)
	if _list != null:
		_redraw()


## The rows as last given, before filtering.
func rows() -> Array[Dictionary]:
	return _rows


## How many rows are on screen after the search and [member max_rows].
func shown_count() -> int:
	return _buttons.size()


func selected_address() -> String:
	return _selected


## Selects the row for [param address]; an address not in the list clears the selection.
func select(address: String) -> void:
	var next := address if _find(address) >= 0 else ""
	if next == _selected:
		return
	_selected = next
	_restyle()
	_reveal(row_button(_selected))
	selection_changed.emit(_selected)


## Asks to join the selected row. False, and nothing emitted, when none is selected.
func join_selected() -> bool:
	if _selected.is_empty():
		return false
	join_requested.emit(_selected)
	return true


## The muted line under the list ("3 of 5 answering.").
func set_status(text: String) -> void:
	if _status == null:
		_build()
	_status.text = text


## Filters the rows by name, map or address, as typing in the search box does.
func search(text: String) -> void:
	if _list == null:
		_build()
	_search.text = text
	_redraw()


## Whether rows are stacked for a narrow width.
func is_compact() -> bool:
	return _compact


## The row Button for [param address], or null. For focus chains and checks.
func row_button(address: String) -> Button:
	return _buttons.get(address, null) as Button


## Focuses the selected row, else the first, else the search box. For a screen opening.
func focus_first() -> void:
	if _list == null:
		_build()
	var target: Control = row_button(_selected)
	if target == null and _list.get_child_count() > 0:
		target = _list.get_child(0) as Control
	if target == null:
		target = _search
	if target.is_inside_tree():
		target.grab_focus()
		_reveal(target)


## Whether the address box sits on the footer line, for a short height.
func is_short() -> bool:
	return _short


## Scrolls [param target] into view once layout has run; follow_focus alone misses a row
## focused before the list had a size.
func _reveal(target: Control) -> void:
	if target == null or _scroll == null or not target.is_inside_tree():
		return
	(func() -> void:
		if is_instance_valid(target) and _scroll.is_ancestor_of(target):
			_scroll.ensure_control_visible(target)
	).call_deferred()


func _build() -> void:
	if gamespice:
		theme = DotUiGamespice.theme()
		add_theme_stylebox_override("panel", DotUiGamespice.card())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_box = box
	_build_head(box)
	_build_list(box)
	_build_entry(box)
	_build_foot(box)

	resized.connect(_on_resized)
	_compact = _wants_compact()
	_place_entry()
	_redraw()


## The title row: eyebrow, title and the refresh button.
func _build_head(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	_eyebrow = DotUiGamespice.eyebrow(eyebrow_text) if gamespice else Label.new()
	_eyebrow.visible = not eyebrow_text.is_empty()
	if not gamespice:
		_eyebrow.text = eyebrow_text
	titles.add_child(_eyebrow)
	_title = Label.new()
	_title.text = title
	_title.theme_type_variation = &"DotHeading"
	titles.add_child(_title)
	_refresh = _button("Refresh", false)
	_refresh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_refresh.pressed.connect(func() -> void: refresh_requested.emit())
	head.add_child(_refresh)


## The search field and the scrolling list with its empty-state label.
func _build_list(box: VBoxContainer) -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "Search servers and maps"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = 44.0
	_search.text_changed.connect(func(_text: String) -> void: _redraw())
	box.add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(inner)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	inner.add_child(_list)
	_empty = Label.new()
	_empty.text = empty_text
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.theme_type_variation = &"DotDim"
	_empty.custom_minimum_size.y = 64.0
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(_empty)


## The row for typing an address by hand.
func _build_entry(box: VBoxContainer) -> void:
	var entry := HBoxContainer.new()
	_entry = entry
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 8)
	entry.visible = show_address_entry
	box.add_child(entry)
	_address = LineEdit.new()
	_address.placeholder_text = "host:port"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.custom_minimum_size.y = 44.0
	_address.text_submitted.connect(func(_text: String) -> void: _submit_address())
	entry.add_child(_address)
	_add = _button("Add", false)
	_add.pressed.connect(_submit_address)
	entry.add_child(_add)


## The status line and the Join button.
func _build_foot(box: VBoxContainer) -> void:
	var foot := HBoxContainer.new()
	_foot = foot
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.theme_type_variation = &"DotDim"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_status)
	_join = _button("Join", true)
	_join.custom_minimum_size.x = 120.0
	_join.pressed.connect(func() -> void: join_selected())
	foot.add_child(_join)


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44.0
	if gamespice:
		if primary:
			DotUiGamespice.primary(button)
		else:
			DotUiGamespice.ghost(button)
	return button


func _submit_address() -> void:
	var text := _address.text.strip_edges()
	if text.is_empty():
		return
	_address.text = ""
	address_added.emit(text)


func _wants_compact() -> bool:
	return compact_below > 0.0 and size.x > 0.0 and size.x < compact_below


func _wants_short() -> bool:
	return short_below > 0.0 and size.y > 0.0 and size.y < short_below


## The address box goes before Join on a short panel and back above the footer otherwise.
func _place_entry() -> void:
	_short = _wants_short()
	# A wrapping label squeezed beside the address box asks for a tall line and starves the rows.
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF if _short else TextServer.AUTOWRAP_WORD_SMART
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _short else TextServer.OVERRUN_NO_TRIMMING
	_status.clip_text = _short
	var parent: Node = _foot if _short else _box
	if _entry.get_parent() != parent:
		_entry.get_parent().remove_child(_entry)
		parent.add_child(_entry)
		parent.move_child(_entry, _join.get_index() if _short else _foot.get_index())


func _on_resized() -> void:
	if _wants_short() != _short:
		_place_entry()
	var want := _wants_compact()
	if want == _compact:
		return
	_compact = want
	for address in _buttons:
		_fill_row(_buttons[address] as Button, _rows[_find(address)])


## Brings the row Buttons in line with the filtered rows, reusing each by address so the
## focused one survives a refresh.
func _redraw() -> void:
	var shown := _filtered()
	var keep := {}
	for row in shown:
		keep[str(row["address"])] = true
	for address in _buttons.keys():
		if not keep.has(address):
			(_buttons[address] as Button).queue_free()
			_list.remove_child(_buttons[address] as Button)
			_buttons.erase(address)

	var at := 0
	for row in shown:
		var address := str(row["address"])
		var button := _buttons.get(address, null) as Button
		if button == null:
			button = Button.new()
			button.name = "Row%d" % _buttons.size()
			button.focus_mode = Control.FOCUS_ALL
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(func() -> void: select(address))
			_buttons[address] = button
			_list.add_child(button)
		_list.move_child(button, at)
		_fill_row(button, row)
		at += 1

	if not _selected.is_empty() and not _buttons.has(_selected):
		_selected = ""
		selection_changed.emit("")
	_empty.visible = _buttons.is_empty()
	_restyle()


func _filtered() -> Array[Dictionary]:
	var needle := _search.text.strip_edges().to_lower() if _search != null else ""
	var out: Array[Dictionary] = []
	for row in _rows:
		if max_rows > 0 and out.size() >= max_rows:
			break
		if not needle.is_empty():
			var hay := ("%s %s %s" % [row.get("name", ""), row.get("map", ""), row.get("address", "")]).to_lower()
			if not hay.contains(needle):
				continue
		out.append(row)
	return out


func _find(address: String) -> int:
	for i in _rows.size():
		if str(_rows[i]["address"]) == address:
			return i
	return -1


## One row's labels: name, map, players, ping in columns, or stacked when compact.
func _fill_row(button: Button, row: Dictionary) -> void:
	for child in button.get_children():
		button.remove_child(child)
		child.queue_free()

	var online := str(row.get("status", "online")) == "online"
	var label_name := str(row.get("name", ""))
	if label_name.is_empty():
		label_name = str(row["address"])
	var map := str(row.get("map", ""))
	var players := "%d/%d" % [int(row.get("players", 0)), int(row.get("max_players", 0))]
	var ping := int(row.get("ping_ms", -1))
	var ping_text := ("%d ms" % ping) if online and ping >= 0 else str(row.get("status", "offline"))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 7)
	button.add_child(pad)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 14)
	pad.add_child(line)

	var name_box := VBoxContainer.new()
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", 0)
	line.add_child(name_box)
	var title_label := _cell(label_name, false, 0.0)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	if gamespice:
		title_label.add_theme_font_override("font", DotUiGamespice.bold(0.4))
	name_box.add_child(title_label)

	if _compact:
		var bits := PackedStringArray([players])
		if not map.is_empty():
			bits.insert(0, map)
		var sub := _cell("  ·  ".join(bits), true, 0.0)
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.clip_text = true
		name_box.add_child(sub)
	else:
		var map_label := _cell(map, true, 150.0)
		map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		map_label.clip_text = true
		line.add_child(map_label)
		var count := _cell(players, false, 64.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(count)

	var ping_label := _cell(ping_text, false, 64.0)
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ping_label.add_theme_color_override("font_color", _ping_colour(ping, online))
	line.add_child(ping_label)

	button.modulate.a = 1.0 if online else 0.6
	button.tooltip_text = str(row["address"])
	button.custom_minimum_size.y = maxf(row_height, pad.get_combined_minimum_size().y)


func _cell(text: String, dim: bool, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = width
	if dim:
		label.theme_type_variation = &"DotDim"
	return label


func _ping_colour(ping: int, online: bool) -> Color:
	var tokens := DotUiGamespice.palette() if gamespice else DotUiTheme.dark()
	if not online or ping < 0:
		return tokens.text_dim
	if ping <= good_ping_ms:
		return tokens.good
	if ping <= fair_ping_ms:
		return tokens.highlight
	return tokens.danger


func _restyle() -> void:
	for address in _buttons:
		var button := _buttons[address] as Button
		var on: bool = str(address) == _selected
		if gamespice:
			DotUiGamespice.row_button(button, on)
		else:
			button.toggle_mode = true
			button.set_pressed_no_signal(on)
	if _join != null:
		_join.disabled = _selected.is_empty()
