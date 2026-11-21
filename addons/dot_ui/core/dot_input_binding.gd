@tool
class_name DotInputBinding
extends RefCounted

## One input binding as a short string, and back again: a thin forwarder to GameSpice Input.
##
## The implementation moved to [DotInputText] (event and text, pure) and [DotInputMap]
## (apply to [InputMap] actions) in GameSpice Input, where the rest of the input model
## lives. This class keeps the name every game already calls; new code names the GameSpice
## Input classes directly. Requires GameSpice Input (`addons/dot_input`).

const CHANNEL := DotInputMap.CHANNEL
const UNBOUND := DotInputText.UNBOUND
const MOUSE_NAMES := DotInputText.MOUSE_NAMES


static func to_text(event: InputEvent) -> String:
	return DotInputText.to_text(event)


static func mouse_text(button_index: int) -> String:
	return DotInputText.mouse_text(button_index)


static func from_text(text: String) -> InputEvent:
	return DotInputText.from_text(text)


static func is_bound(text: String) -> bool:
	return DotInputText.is_bound(text)


static func apply(action: StringName, text: String) -> String:
	return DotInputMap.apply(action, text)


static func ensure_action(action: StringName, text: String) -> String:
	return DotInputMap.ensure_action(action, text)


static func describe_action(action: StringName) -> String:
	return DotInputMap.describe_action(action)
