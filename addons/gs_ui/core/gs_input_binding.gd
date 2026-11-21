@tool
class_name GSInputBinding
extends RefCounted

## One input binding as a short string, and back again: a thin forwarder to GameSpice Input.
##
## The implementation moved to [GSInputText] (event and text, pure) and [GSInputMap]
## (apply to [InputMap] actions) in GameSpice Input, where the rest of the input model
## lives. This class keeps the name every game already calls; new code names the GameSpice
## Input classes directly. Requires GameSpice Input (`addons/gs_input`).

const CHANNEL := GSInputMap.CHANNEL
const UNBOUND := GSInputText.UNBOUND
const MOUSE_NAMES := GSInputText.MOUSE_NAMES


static func to_text(event: InputEvent) -> String:
	return GSInputText.to_text(event)


static func mouse_text(button_index: int) -> String:
	return GSInputText.mouse_text(button_index)


static func from_text(text: String) -> InputEvent:
	return GSInputText.from_text(text)


static func is_bound(text: String) -> bool:
	return GSInputText.is_bound(text)


static func apply(action: StringName, text: String) -> String:
	return GSInputMap.apply(action, text)


static func ensure_action(action: StringName, text: String) -> String:
	return GSInputMap.ensure_action(action, text)


static func describe_action(action: StringName) -> String:
	return GSInputMap.describe_action(action)
