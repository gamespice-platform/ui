# dot-ui

Screens, HUD and menus for a Godot 4 game, with no art assets. A screen stack that works out z-order, input blocking and mouse mode from one place, a settings panel generated from any `DotConfig`, a rebinder with conflict detection, and data-driven HUD widgets.

## Install

1. Get [Godot 4.7](https://godotengine.org/download).
2. Either use [dot-bootstrap](https://github.com/modcommunity/dot-bootstrap), which clones every project and links the addons, or copy `addons/dot_ui/` and [dot-core](https://github.com/modcommunity/dot-core)'s `addons/dot_core/` into your project and enable both in *Project > Project Settings > Plugins*.

dot-core is the only dependency.

## Use

```gdscript
var stack := DotScreenStack.new()
add_child(stack)
stack.register(pause_menu)
stack.register(settings_screen)

hud.bind_stack(stack)

# A settings screen, from the config you already have.
settings_panel.bind(server_config)

# A health bar, from the health you already have.
health_bar.bind(func(): return health.health)
```

`DotScreenStack` derives z-order, input blocking, mouse capture and the back key from one stack whenever it changes, so you do not get a pause menu that is visible but not focused or an escape key that closes two screens.

dot-ui ships no textures, fonts or nine-patches and knows nothing about dot-match or dot-combat. The theme is generated from `StyleBoxFlat`s, the kill feed takes coloured string fragments and the scoreboard takes rows of dictionaries.

## What is in it

| Class | What it is |
| --- | --- |
| `DotScreenStack`, `DotScreen` | What is open, in what order, and who gets input. |
| `DotUiTheme` | A whole `Theme` from a palette and a scale. |
| `DotHud`, `DotHudWidget` | The always-on layer, and widgets that pull a value rather than being pushed. |
| `DotStatBar` | Health, armour, ammo. |
| `DotCrosshair` | Opens by the actual spread angle through the actual camera projection. |
| `DotStarfield` | A parallax starfield drawn into any `CanvasItem`. |
| `DotFeedView` | A self-expiring list of coloured fragments, for a kill feed or chat. |
| `DotChatWindow` | A chat box: a fading log, a line to type in, and a key that opens it. |
| `DotTableView` | Rows and columns: scoreboard, server browser, ban list. |
| `DotVitals`, `DotAmmoCounter`, `DotScoreStrip` | The glance HUD: health and armour, `magazine \| reserve`, the clock with optional score plates. |
| `DotHitMarker`, `DotDamageNumbers` | Hit ticks (red on a kill) and numbers that rise off where a hit landed. |
| `DotKeyPrompt`, `DotKeyHints` | "Open door [E]" and a column of keys, drawn from the player's binding. |
| `DotBallotPanel` | A dot-vote ballot on the HUD, by number key, click or both, with a countdown and voters' avatars. Emits `chosen`. |
| `DotSettingsPanel` | Builds itself from a `DotConfig`. Never shows a secret. |
| `DotBindingsPanel` | Rebinding with conflict detection, in a file that survives a restart. |
| `DotInputBinding` | One binding as text (`"Y"`, `"Shift+A"`, `"Mouse 1"`) and back. |

## Settings panel

`DotSettingsPanel` reads the `@export` annotations the config already has (keys, types, ranges, enum choices, groups) and builds the controls, so a screen never drifts from the config. It skips `sensitive_keys()`, since secrets end up in screenshots. Edits are held until `apply()`, and an invalid set is rolled back entirely.

## Chat window

It knows nothing about chat: it takes coloured fragments to draw and emits the string somebody typed. `open_action` is an `InputMap` action (`Y` by default), so players rebind it.

```gdscript
var chat := DotChatWindow.new()
chat.submitted.connect(func(text: String, _channel: StringName) -> void:
    link.send_chat(text))
chat.opened.connect(func(_c: StringName) -> void: controller.suspended = true)
chat.closed.connect(func() -> void: controller.suspended = false)
add_child(chat)
```

Connect `opened` and `closed` to whatever suspends your controller. A focused `LineEdit` keeps keys out of `_unhandled_input` but not out of `Input.is_action_pressed`, so without it typing "sw" walks the player backwards. Long lines wrap at word boundaries, and `max_lines` counts drawn rows, not messages.

## Widgets pull

A `DotHudWidget` holds a `Callable` that reads the value, by default ten times a second. A bar wired to a signal misses changes that happened before it existed, and fires repeatedly when several things change in one tick. There is an immediate path for anything where lateness would be wrong.

## Testing

Import the project once, then run `examples/ui_selftest.tscn` and `examples/form_selftest.tscn` headless with Godot. They run offline, render nothing and exit non-zero on failure. Further docs are in [docs/](docs/README.md).

## Credits

The one exception to "no art" is an optional weapon icon sheet. `DotIconSet` works without it; `DotWeaponIcons.stock()` adds it.

| Asset | Author / source | Licence |
| --- | --- | --- |
| Weapon icon sheet (18 kB) | Jestan, [The Ultimate Weapons Pack](https://jestan.itch.io/weapons-pack) | CC0 1.0 |

The itch.io page says CC0, and the author confirms in its comment thread that the licence file inside the zip is outdated. Details in `addons/dot_ui/icons/jestan/CREDITS.md`.

## Status and licence

Part of the TMC **dot-\*** family of Godot addons. Written with Claude Code and maintained by `gamemann`. Every addon has headless tests, but little of this has been played by real users yet, so expect rough edges and please [open an issue](https://github.com/modcommunity/dot-ui/issues) when you hit one.

MIT licence, see [LICENSE](LICENSE). The only closed part of the TMC platform is the web back end; you can use your own instead of TMC's.
