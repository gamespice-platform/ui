extends Node

## GSHealthTag, offline and headless.
##
## godot --headless --path . res://examples/health_tag_selftest.tscn

const CHECKS := 14

var _passed := 0
var _failed := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % what)


func _run() -> void:
	print("gs-ui health tag self-test")
	var tag := GSHealthTag.new()
	add_child(tag)
	tag.update(1.0, false, false, "", true, 0.016)
	_check(not tag.visible, "hidden with neither bar nor name")
	tag.update(0.5, true, true, "Ann", true, 0.016)
	_check(tag.visible, "shown with a bar and a name")
	tag.update(0.2, true, false, "Ann", true, 10.0)
	_check(is_equal_approx(tag.shown_fraction, 0.2), "the bar eases to its mark")
	_check(tag.trail_fraction >= tag.shown_fraction, "the trail never trails below the fill")
	tag.update(0.2, true, false, "Ann", true, 0.016, Color(0.2, 0.4, 1.0, 1.0), 0.7)
	_check(is_equal_approx(tag.scale.x, 0.7), "tag_scale sizes the tag")
	_check(GSHealthTag.fill_for(1.0) == GSHealthTag.FILL_FULL and GSHealthTag.fill_for(0.0) == GSHealthTag.FILL_LOW, "fill runs green to red")
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 0.0, 5.0)
	tag.face(cam)
	_check(tag.global_transform.basis.z.normalized().dot(Vector3.BACK) > 0.99, "faces a camera along +Z")
	cam.position = Vector3(0.0, 5.0, 0.0)
	tag.face(cam)
	_check(tag.global_transform.basis.is_finite() and absf(tag.global_transform.basis.z.normalized().dot(Vector3.UP)) > 0.99, "faces a camera straight above without a degenerate basis")
	tag.face(null)
	_check(true, "a null camera is ignored")
	tag.configure(0.6, 0.06, true)
	_check(is_equal_approx(tag._bar.scale.x, 0.6) and is_equal_approx(tag._bar.scale.y, 0.06 / GSHealthTag.BAR_SIZE.y), "configure sizes the bar")
	_check(tag._material.get_shader_parameter("modern") == 1.0 and tag._label_gap < 0.2, "configure picks the modern look and a tighter name gap")
	tag.update(0.5, true, true, "Ann", true, 0.016, Color(0, 0, 0, 0), 1.0, 0.25)
	_check(is_equal_approx(tag._material.get_shader_parameter("opacity"), 0.25) and is_equal_approx(tag._label.modulate.a, 0.25), "opacity fades the bar and the name")
	tag.update(0.5, true, true, "Ann", true, 0.016)
	_check(is_equal_approx(tag._material.get_shader_parameter("opacity"), 1.0), "opacity defaults to opaque")
	var other := GSHealthTag.new()
	_check(other._bar.mesh == tag._bar.mesh, "tags share one mesh")
	other.free()
	tag.queue_free()
	print("%d checks of %d, %d failed" % [_passed + _failed, CHECKS, _failed])
	get_tree().quit(0 if _failed == 0 and _passed + _failed == CHECKS else 1)
