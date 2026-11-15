extends "ballot_chat_checks.gd"

## The screen-stack sections of ui_selftest.gd (refusal, visibility, input blocking), split out to keep that file under the size gate.


func _test_stack_visibility() -> void:
	_section("screen stack: visibility")

	var stack := _make_stack()

	var menu := _make_screen(&"menu")
	var overlay := _make_screen(&"overlay")
	var opaque := _make_screen(&"opaque")

	overlay.hides_below = false
	opaque.hides_below = true

	stack.register(menu)
	stack.register(overlay)
	stack.register(opaque)

	stack.push(&"menu")
	stack.push(&"overlay")

	_check(menu.visible, "a transparent screen leaves what is below it visible")
	_check(overlay.visible, "and is visible itself")

	stack.push(&"opaque")
	_check(not menu.visible, "an opaque screen hides what is below it")
	_check(not overlay.visible, "all of it")
	_check(opaque.visible, "and is visible itself")

	stack.pop()
	_check(menu.visible, "and popping it brings them back")

	# Z-order is sibling order. A stack that did not maintain it would render a menu
	# under the screen that opened it.
	_check(
		stack.get_child(stack.get_child_count() - 1) == overlay,
		"the top screen is the last sibling",
		stack.get_child(stack.get_child_count() - 1).name
	)

	stack.queue_free()
	remove_child(stack)
	_done()


func _test_stack_input_blocking() -> void:
	_section("screen stack: input")

	var stack := _make_stack()

	var scoreboard := _make_screen(&"scoreboard")
	scoreboard.blocks_input = false
	scoreboard.hides_below = false

	var menu := _make_screen(&"menu")
	menu.blocks_input = true

	stack.register(scoreboard)
	stack.register(menu)

	stack.push(&"scoreboard")
	_check(
		scoreboard.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the top screen takes input"
	)

	# The distinction that matters: a scoreboard held down over a live game is visible
	# and must not stop the player moving, which is a different thing from being
	# invisible.
	_check(
		scoreboard.visible and not scoreboard.blocks_input,
		"a non-blocking screen is visible and does not block"
	)

	stack.push(&"menu")
	_check(
		scoreboard.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"a blocking screen above stops the one below receiving input"
	)

	stack.pop()
	_check(
		scoreboard.mouse_filter == Control.MOUSE_FILTER_STOP,
		"and popping gives it back"
	)

	stack.queue_free()
	remove_child(stack)
	_done()


func _test_stack_refusal() -> void:
	_section("screen stack: refusing to close")

	var stack := _make_stack()
	var modal := _make_screen(&"modal")
	modal.refuse_pop = true

	stack.register(modal)
	stack.push(&"modal")

	_check(not stack.pop().ok, "a screen can refuse to close")
	_check(stack.is_open(&"modal"), "and stays open")

	modal.refuse_pop = false
	_check(stack.pop().ok, "and closes once it stops refusing")

	var locked := _make_screen(&"locked")
	locked.closable = false
	stack.register(locked)
	stack.push(&"locked")
	_check(not stack.pop().ok, "an unclosable screen cannot be popped")

	# pop_to must not spin forever on a screen that will not close.
	stack.push(&"modal")
	var popped := stack.pop_to()
	_check(
		popped <= 1 and stack.is_open(&"locked"),
		"clearing stops at a screen that refuses rather than looping",
		"%d popped, depth %d" % [popped, stack.depth()]
	)

	locked.closable = true
	stack.clear()

	stack.queue_free()
	remove_child(stack)
	_done()
