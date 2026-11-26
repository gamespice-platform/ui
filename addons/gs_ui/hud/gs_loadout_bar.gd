@tool
class_name GSLoadoutBar
extends GSHudPiece

## The loadout, bottom right: one slot per weapon (or medkit, pill, anything the carrier keeps ready),
## laid out in a row, and the weight bar over them. Values in, never a game object.
##
## [b]Slot API[/b] ([method set_slots]; the inventory and healing work plugs in through it). Each slot is
## a Dictionary:
## [codeblock]
## {
##     "key": "1",                 # the key cap (String); "" for none
##     "icon": Texture2D,          # exactly one picture; null draws the slot's name instead
##     "name": "AK",               # shown only when there is no icon
##     "text": "30 / 120",         # the small line under the icon (ammo, count); "" for none
##     "selected": true,           # in hand
##     "low": false,               # the line in the low colour
##     "empty": false,             # nothing there: drawn faint (a vacant slot, a used-up kit)
##     "accent": Color(...),       # optional: the selected edge's colour (a medkit may be green)
##     "fill": 0.4,                # optional 0..1: a progress bar along the slot's foot (hold E to heal)
## }
## [/codeblock]
## Weapons first, then whatever else the host appends: the row grows to the left and stays anchored at the
## right. [method set_weight] feeds the bar above it; [method clear_weight] hides it.
##
## [b]Layouts[/b] ([method set_layout]). [constant Layout.ROW] is the above. [constant Layout.STACK] is a
## column down the right edge, one plate per slot (the key cap at the plate's right, the picture left of it,
## the selected slot's larger), the bottom slot's centre [member stack_foot] up from the bottom and the
## plates [member stack_pitch] apart: a host that has to squeeze the column sets the pitch and hands in only
## the slots that fit. [constant Layout.BUTTONS] is a centred row of square buttons for abilities: the key under
## each, a cooldown darkening it from the top with the seconds left, an [code]active[/code] gold edge and
## [code]pips[/code] over it. A button's extra keys: [code]"left"[/code] seconds of cooldown left,
## [code]"total"[/code] its length, [code]"active"[/code] bool, [code]"pips"[/code] and [code]"pips_max"[/code] ints.

const SLOT_W := 104.0
const SLOT_H := 66.0
const GAP := 8.0
const WEIGHT_H := 30.0
const MAX_SLOTS := 8
## Easing, per second, of a slot's selected lift and the weight bar's fill.
const EASE := 14.0
enum Layout { ROW, STACK, BUTTONS }
## STACK: the plate's width left of its key cap, and the gap between plates.
const STACK_BODY_W := 112.0
const STACK_GAP := 6.0
## BUTTONS: a button's side and the gap between buttons.
const BUTTON_SIDE := 56.0
const BUTTON_GAP := 14.0

## STACK: distance between the plates' centres (plate height is this minus [constant STACK_GAP]).
var stack_pitch: float = 40.0
## STACK: how far above the bottom the bottom plate's centre sits.
var stack_foot: float = 20.0
var layout_kind: Layout = Layout.ROW

var _slots: Array = []
var _lift: Array[float] = []
## Texture instance id -> its drawn rect (see [method _used_rect]).
var _used: Dictionary = {}

var _weight_on: bool = false
var _carried: float = 0.0
var _limit: float = 1.0
var _pack: int = 0
var _pack_max: int = 0
var _shown_share: float = 0.0


func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(MAX_SLOTS * (SLOT_W + GAP), SLOT_H + WEIGHT_H)


## Picks the layout; a host that sets [constant Layout.STACK] or [constant Layout.BUTTONS] sizes the control itself.
func set_layout(mode: Layout) -> void:
	if mode == layout_kind:
		return
	layout_kind = mode
	if mode != Layout.ROW:
		custom_minimum_size = Vector2.ZERO
	queue_redraw()


## STACK: the pitch of the plates; redraws only on a change.
func set_stack_pitch(pitch: float) -> void:
	if not is_equal_approx(pitch, stack_pitch):
		stack_pitch = pitch
		queue_redraw()


## Replaces the row. Equal rows redraw nothing.
func set_slots(slots: Array) -> void:
	if slots == _slots:
		return
	_slots = slots.duplicate()
	while _lift.size() < _slots.size():
		_lift.append(0.0)
	_lift.resize(_slots.size())
	queue_redraw()


func slot_count() -> int:
	return _slots.size()


func set_weight(carried: float, limit: float, pack: int = 0, pack_max: int = 0) -> void:
	_weight_on = true
	_carried = carried
	_limit = maxf(limit, 0.1)
	_pack = pack
	_pack_max = pack_max
	queue_redraw()


func clear_weight() -> void:
	if _weight_on:
		_weight_on = false
		queue_redraw()


## The weight line as drawn, for a check: "4.2 / 10.0" and the pack "PACK 2".
func weight_text() -> String:
	var out := "%.1f / %.1f" % [_carried, _limit]
	return out


func pack_text() -> String:
	return "PACK %d" % _pack if _pack_max > 0 else ""


func footprint() -> Rect2:
	if layout_kind == Layout.STACK:
		return _stack_footprint()
	if layout_kind == Layout.BUTTONS:
		return _buttons_footprint()
	if _slots.is_empty() and not _weight_on:
		return Rect2()
	var width := _row_width()
	var top := 0.0 if _weight_on else WEIGHT_H
	return Rect2(size.x - width, top, width, size.y - top)


func _row_width() -> float:
	var n := maxi(_slots.size(), 1)
	return float(n) * SLOT_W + float(n - 1) * GAP


func _process(delta: float) -> void:
	super._process(delta)
	var moving := false
	var step := 1.0 - exp(-EASE * delta)
	for i in _slots.size():
		var goal := 1.0 if bool((_slots[i] as Dictionary).get("selected", false)) else 0.0
		if absf(_lift[i] - goal) > 0.002:
			_lift[i] = lerpf(_lift[i], goal, step)
			moving = true
	var share := minf(_carried / _limit, 1.0) if _weight_on else 0.0
	if absf(_shown_share - share) > 0.002:
		_shown_share = lerpf(_shown_share, share, step)
		moving = true
	if moving:
		queue_redraw()


func _draw() -> void:
	if layout_kind == Layout.STACK:
		_draw_stack()
		return
	if layout_kind == Layout.BUTTONS:
		_draw_buttons()
		return
	var width := _row_width()
	var left := size.x - width
	var slots_top := size.y - SLOT_H
	if _weight_on:
		_draw_weight(Rect2(left, 0.0, width, WEIGHT_H - 8.0))
	for i in _slots.size():
		var rect := Rect2(left + float(i) * (SLOT_W + GAP), slots_top, SLOT_W, SLOT_H)
		_draw_slot(_slots[i], rect, _lift[i])


func _draw_weight(area: Rect2) -> void:
	var share := _carried / _limit
	var tone := colour(&"low") if share > 1.0 else (colour(&"highlight") if share > 0.8 else colour(&"good"))
	ink_text(Vector2(area.position.x, area.position.y + 12.0), "WEIGHT", 12, colour(&"dim"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	ink_text(Vector2(area.position.x + 62.0, area.position.y + 12.0), weight_text(), 13, tone, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	var pack := pack_text()
	if pack != "":
		ink_text(Vector2(area.position.x, area.position.y + 12.0), pack, 12, colour(&"dim"), HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, 4)
	var bar := Rect2(area.position.x, area.end.y - 6.0, area.size.x, 6.0)
	ink_plate(bar, Color(0.0, 0.0, 0.0, 0.5), 3, Color(0, 0, 0, 0), 0)
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(_shown_share, 0.0, 1.0), bar.size.y))
	if fill.size.x >= 3.0:
		ink_plate(fill, tone, 3, Color(0, 0, 0, 0), 0)


## The part of [param icon] that has pixels, so a thin knife fills the slot like a rifle does. Cached per texture.
func _used_rect(icon: Texture2D) -> Rect2:
	var id := icon.get_instance_id()
	if _used.has(id):
		return _used[id]
	var whole := Rect2(Vector2.ZERO, Vector2(icon.get_width(), icon.get_height()))
	var image := icon.get_image()
	if image != null and not image.is_empty() and not image.is_compressed():
		var box := image.get_used_rect()
		if box.size.x > 0 and box.size.y > 0:
			_used[id] = Rect2(box)
			return _used[id]
	# Not rendered yet (a viewport's first frames): the whole picture, and ask again next draw.
	return whole


func _draw_slot(slot: Dictionary, rect: Rect2, lift: float) -> void:
	var empty := bool(slot.get("empty", false))
	var alpha := 0.4 if empty else 1.0
	var accent: Color = slot.get("accent", colour(&"highlight"))
	rect.position.y -= 5.0 * lift
	# A lighter glass than the other plates: the weapon renders are dark metal and must read against it.
	var plate := Color(0.2, 0.24, 0.3, 0.74)
	plate = plate.lerp(Color(0.26, 0.31, 0.39, 0.9), lift * 0.7)
	var edge := colour(&"plate_edge").lerp(accent, lift)
	ink_plate(rect, Color(plate, plate.a * (0.6 + 0.4 * alpha)), 9, Color(edge, edge.a), 2 if lift > 0.5 else 1)

	var key := str(slot.get("key", ""))
	if key != "":
		var _w := ink_keycap(Vector2(rect.position.x + 7.0, rect.position.y + 14.0), key, 11, alpha)

	var icon: Texture2D = slot.get("icon", null)
	var picture := Rect2(rect.position + Vector2(8.0, 7.0), Vector2(rect.size.x - 16.0, rect.size.y - 29.0))
	if icon != null:
		var used := _used_rect(icon)
		var scale := minf(picture.size.x / used.size.x, picture.size.y / used.size.y)
		var drawn := used.size * scale
		var shade := Color(1.0, 1.0, 1.0, alpha * (0.8 + 0.2 * lift))
		var at := Rect2(picture.get_center() - drawn * 0.5, drawn)
		# Dark metal renders vanish on a dark plate: a pale rim under the picture keeps knives and pistols readable.
		var rim := Color(0.86, 0.92, 1.0, 0.55 * alpha)
		for offset in [Vector2(-1.5, 0.0), Vector2(1.5, 0.0), Vector2(0.0, -1.5), Vector2(0.0, 1.5)]:
			draw_texture_rect_region(icon, Rect2(at.position + offset, at.size), used, rim)
		draw_texture_rect_region(icon, at, used, shade)
	else:
		ink_text(Vector2(picture.position.x, picture.get_center().y + 5.0), str(slot.get("name", "")), 14,
			Color(colour(&"text"), alpha), HORIZONTAL_ALIGNMENT_CENTER, picture.size.x, 4)

	var fill := clampf(float(slot.get("fill", 0.0)), 0.0, 1.0)
	if fill > 0.0:
		var track := Rect2(rect.position.x + 8.0, rect.end.y - 5.0, rect.size.x - 16.0, 3.0)
		draw_rect(track, Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(track.position, Vector2(track.size.x * fill, track.size.y)), accent)

	var text := str(slot.get("text", ""))
	if text != "":
		var tone := colour(&"low") if bool(slot.get("low", false)) else colour(&"text").lerp(colour(&"dim"), 1.0 - lift)
		ink_text(Vector2(rect.position.x, rect.end.y - 8.0), text, 13, Color(tone, alpha), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)


# ---- STACK -------------------------------------------------------------------------------------------

func _stack_plate(slot: Dictionary, i: int) -> Rect2:
	var key := str(slot.get("key", ""))
	var cap_w := keycap_width(key, 12) if key != "" else 0.0
	var right := size.x + 4.0
	var left := right - 4.0 - cap_w - STACK_BODY_W
	var height := stack_pitch - STACK_GAP
	var centre := size.y - stack_foot - float(_slots.size() - 1 - i) * stack_pitch
	return Rect2(left, centre - height * 0.5, right - left, height)


func _stack_footprint() -> Rect2:
	if _slots.is_empty():
		return Rect2()
	var box := _stack_plate(_slots[0], 0)
	for i in range(1, _slots.size()):
		box = box.merge(_stack_plate(_slots[i], i))
	return box


## For a subclass: drawn behind a STACK slot's picture ([param at] is its left edge, centred on y), for a halo
## the host's icon style wants. Nothing by default.
func _stack_backdrop(_slot: Dictionary, _at: Vector2, _height: float, _alpha: float, _max_width: float) -> void:
	pass


func _draw_stack() -> void:
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var rect := _stack_plate(slot, i)
		var on := bool(slot.get("selected", false))
		var alpha := 1.0 if on else 0.72
		var accent: Color = slot.get("accent", colour(&"highlight"))
		ink_plate(rect, Color(colour(&"plate"), 0.8 if on else 0.6), 7,
			Color(accent, 0.85) if on else Color(colour(&"plate_edge"), 0.1), 2 if on else 1)
		var key := str(slot.get("key", ""))
		var cap_x := rect.end.x - 4.0
		if key != "":
			var cap_w := keycap_width(key, 12)
			cap_x -= cap_w
			var _w := ink_keycap(Vector2(cap_x, rect.get_center().y), key, 12, alpha)
		var icon: Texture2D = slot.get("icon", null)
		var height := minf(24.0 if on else 18.0, rect.size.y - 2.0)
		if icon != null:
			var s := icon.get_size()
			var w := minf(s.x * height / maxf(s.y, 1.0), 90.0)
			var h := w * s.y / maxf(s.x, 1.0)
			var at := Vector2(cap_x - 10.0 - w, rect.get_center().y - h * 0.5)
			_stack_backdrop(slot, Vector2(at.x, at.y + h * 0.5), height, alpha, 90.0)
			# A shadow first, so a white gun reads on a white wall.
			draw_texture_rect(icon, Rect2(at + Vector2(1.5, 1.5), Vector2(w, h)), false, Color(0, 0, 0, 0.55 * alpha))
			draw_texture_rect(icon, Rect2(at, Vector2(w, h)), false, Color(1, 1, 1, alpha))
		else:
			ink_text(Vector2(rect.position.x, rect.get_center().y + 5.0), str(slot.get("name", "")), 13,
				Color(colour(&"text"), alpha), HORIZONTAL_ALIGNMENT_RIGHT, cap_x - 10.0 - rect.position.x, 4)


# ---- BUTTONS -----------------------------------------------------------------------------------------

func _buttons_width() -> float:
	var n := _slots.size()
	return BUTTON_SIDE * float(n) + BUTTON_GAP * float(maxi(n - 1, 0))


## The buttons, the pips over them and the keys under them.
func _buttons_footprint() -> Rect2:
	if _slots.is_empty():
		return Rect2()
	var width := _buttons_width()
	return Rect2(size.x * 0.5 - width * 0.5, -14.0, width, 14.0 + BUTTON_SIDE + 2.0 + 22.0 + 2.0)


func _draw_buttons() -> void:
	var x := size.x * 0.5 - _buttons_width() * 0.5
	for slot in _slots:
		_draw_button(Rect2(x, 0.0, BUTTON_SIDE, BUTTON_SIDE), slot)
		x += BUTTON_SIDE + BUTTON_GAP


func _draw_button(rect: Rect2, b: Dictionary) -> void:
	var left := float(b.get("left", 0.0))
	var total := maxf(float(b.get("total", 1.0)), 0.001)
	var ready := left <= 0.0
	var active := bool(b.get("active", false))
	ink_plate(Rect2(rect.position + Vector2(0.0, 3.0), rect.size), Color(0, 0, 0, 0.4), 10, Color(0, 0, 0, 0), 0)
	# The dark theme draws a ready button as a deep slate edged in white and a charging one near black; a bright
	# theme (a high team_fill) as a saturated blue key.
	var bright := clampf((float(number(&"team_fill")) - 38.0) / 62.0, 0.0, 1.0)
	var fill := Color(0.11, 0.16, 0.26, 0.92).lerp(Color(0.2, 0.55, 0.95, 0.88), bright) if ready \
		else Color(0.04, 0.05, 0.08, 0.86).lerp(Color(0.16, 0.2, 0.3, 0.85), bright)
	var edge := colour(&"highlight") if active else Color(colour(&"text"), (0.7 if ready else 0.22) if bright < 0.5 else (0.55 if ready else 0.25))
	ink_plate(rect, fill, 10, edge, 3 if active else 2)
	ink_plate(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(rect.size.x - 6.0, rect.size.y * 0.42)),
		Color(1, 1, 1, lerpf(0.06, 0.14, bright) if ready else 0.04), 8, Color(0, 0, 0, 0), 0)
	var icon: Texture2D = b.get("icon", null)
	if icon != null:
		var side := BUTTON_SIDE * 0.62
		draw_texture_rect(icon, Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, 1.0 if ready else 0.45))
	else:
		ink_text(Vector2(rect.position.x, rect.get_center().y + 5.0), str(b.get("name", "")).substr(0, 5).to_upper(), 12, colour(&"text"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 3)
	if not ready:
		var cover := rect.size.y * clampf(left / total, 0.0, 1.0)
		ink_plate(Rect2(rect.position, Vector2(rect.size.x, cover)), Color(0.0, 0.0, 0.02, 0.5), 10, Color(0, 0, 0, 0), 0)
		ink_text(Vector2(rect.position.x, rect.get_center().y + 8.0), "%.1f" % left if left < 10.0 else "%d" % int(left), 20, colour(&"text"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 5)
	var pips_max := int(b.get("pips_max", 0))
	if pips_max > 0:
		var pips := int(b.get("pips", 0))
		var px := rect.get_center().x - 8.0 * float(pips_max - 1)
		for i in range(pips_max):
			var c := Vector2(px + 16.0 * float(i), rect.position.y - 9.0)
			draw_circle(c, 5.0, Color(0, 0, 0, 0.55))
			draw_circle(c, 3.8, colour(&"highlight") if i < pips else Color(1, 1, 1, 0.25))
	var key := str(b.get("key", ""))
	if key != "":
		var cap_w := keycap_width(key, 12)
		var _w := ink_keycap(Vector2(rect.get_center().x - cap_w * 0.5, rect.end.y + 2.0), key, 12)
