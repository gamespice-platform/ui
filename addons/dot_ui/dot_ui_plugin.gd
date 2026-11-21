@tool
extends EditorPlugin

## Editor entry point for GameSpice UI. Registers inspector types only.
##
## No autoload, for the family's reason: a process may run two windows or a server and
## a client at once, and a singleton screen stack makes that impossible.
## [GSScreenStack] registers itself in [GSRegistry] instead.

const _ICON := "res://addons/dot_ui/icon_placeholder.svg"

const _TYPES := [
	["GSScreenStack", "Control", "res://addons/dot_ui/core/dot_screen_stack.gd"],
	["GSScreen", "Control", "res://addons/dot_ui/core/dot_screen.gd"],
	["GSHud", "Control", "res://addons/dot_ui/hud/dot_hud.gd"],
	["GSStatBar", "Control", "res://addons/dot_ui/hud/dot_stat_bar.gd"],
	["GSCrosshair", "Control", "res://addons/dot_ui/hud/dot_crosshair.gd"],
	["GSFeedView", "Control", "res://addons/dot_ui/hud/dot_feed_view.gd"],
	["GSTableView", "Control", "res://addons/dot_ui/hud/dot_table_view.gd"],
	[
		"GSSettingsPanel",
		"VBoxContainer",
		"res://addons/dot_ui/panels/dot_settings_panel.gd",
	],
	[
		"GSBindingsPanel",
		"VBoxContainer",
		"res://addons/dot_ui/panels/dot_bindings_panel.gd",
	],
]


func _enter_tree() -> void:
	var icon: Texture2D = null
	if ResourceLoader.exists(_ICON):
		icon = load(_ICON) as Texture2D

	for entry in _TYPES:
		add_custom_type(entry[0], entry[1], load(entry[2]), icon)


func _exit_tree() -> void:
	for i in range(_TYPES.size() - 1, -1, -1):
		remove_custom_type(_TYPES[i][0])
