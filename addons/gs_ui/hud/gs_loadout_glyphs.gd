class_name GSLoadoutGlyphs
extends RefCounted

## Drawn pictures for loadout slots that have no model to render: a medkit and a pill, in colours that
## read on the bar's pale icon well. Used by [GSLoadoutBar] for a slot's [code]"glyph"[/code] key.

const MEDKIT := &"medkit"
const PILLS := &"pills"

const _RED := Color(0.84, 0.1, 0.12)
const _WHITE := Color(0.97, 0.97, 0.98)
const _INK := Color(0.1, 0.12, 0.16)


## True for a glyph this class can draw.
static func known(glyph: StringName) -> bool:
	return glyph == MEDKIT or glyph == PILLS


## Draws [param glyph] fitted and centred in [param box], faded by [param alpha].
static func draw(canvas: CanvasItem, glyph: StringName, box: Rect2, alpha: float) -> void:
	var side := minf(box.size.x, box.size.y)
	var area := Rect2(box.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	if glyph == MEDKIT:
		_medkit(canvas, area, alpha)
	elif glyph == PILLS:
		_pills(canvas, area, alpha)


static func _medkit(canvas: CanvasItem, area: Rect2, alpha: float) -> void:
	var body := Rect2(area.position + Vector2(0.0, area.size.y * 0.18), Vector2(area.size.x, area.size.y * 0.82))
	canvas.draw_rect(body.grow(1.5), Color(_INK, alpha))
	canvas.draw_rect(body, Color(_RED, alpha))
	var handle := Rect2(area.position + Vector2(area.size.x * 0.32, 0.0), Vector2(area.size.x * 0.36, area.size.y * 0.18 + 1.0))
	canvas.draw_rect(handle.grow(1.5), Color(_INK, alpha))
	canvas.draw_rect(handle, Color(_RED.darkened(0.25), alpha))
	var arm := body.size.y * 0.5
	var thick := maxf(body.size.y * 0.2, 2.0)
	var c := body.get_center()
	canvas.draw_rect(Rect2(c - Vector2(arm * 0.5, thick * 0.5), Vector2(arm, thick)), Color(_WHITE, alpha))
	canvas.draw_rect(Rect2(c - Vector2(thick * 0.5, arm * 0.5), Vector2(thick, arm)), Color(_WHITE, alpha))


static func _pills(canvas: CanvasItem, area: Rect2, alpha: float) -> void:
	var r := area.size.x * 0.17
	var c := area.get_center()
	var along := Vector2(1.0, -1.0).normalized()
	var half := area.size.x * 0.24
	var a := c - along * half
	var b := c + along * half
	canvas.draw_line(a, b, Color(_INK, alpha), r * 2.0 + 3.0)
	canvas.draw_circle(a, r + 1.5, Color(_INK, alpha))
	canvas.draw_circle(b, r + 1.5, Color(_INK, alpha))
	canvas.draw_line(a, c, Color(_RED, alpha), r * 2.0)
	canvas.draw_line(c, b, Color(_WHITE, alpha), r * 2.0)
	canvas.draw_circle(a, r, Color(_RED, alpha))
	canvas.draw_circle(b, r, Color(_WHITE, alpha))
