# GameSpice UI

Screens, HUD and menus with no art assets: a screen stack that owns z-order, input, mouse mode and pause; pause, settings and scoreboard screens; a settings panel and a rebinder; HUD widgets (stat bar, crosshair, feed, table, chat box, ballot) and the glance pieces (vitals, ammo, score strip and clock, hit marker, damage numbers, key prompt and hints); and a theme generated from a palette.

Read the family [CLAUDE.md](../../CLAUDE.md) first; this file is only what is specific to the interface. The reasoning is in [docs/](docs/README.md). gs-menu builds the designed Escape menu and Tab scoreboard on top of this.

**Depends on GameSpice Core and GameSpice Input (`GSInputBinding` forwards to `GSInputText`/`GSInputMap`; link `addons/gs_input`), names nothing else outside them.** Input is an approved dependency (the owner moved input code into one addon so the key-name and `InputMap` code is not copied per addon). Widgets take strings, dictionaries and `Callable`s; a settings source is an untyped `Object`. A script that so much as mentions another addon's class fails to compile without it. [hud](docs/hud.md#ships-no-art-names-nothing-outside-gs-core)

Also requires **GameSpice Profile** (`GSProfileSet`, `GSProfile`, `GSProfileRuntime`, split from GameSpice Core): link `addons/gs_profile` next to `addons/gs_core`.

## Read before

| Read | Before |
| --- | --- |
| [docs/README.md](docs/README.md) | the index |
| [docs/screens.md](docs/screens.md) | the stack, screen ids, pause, the shared screens, the settings and bindings panels, `GSInputBinding` |
| [docs/hud.md](docs/hud.md) | the theme, widgets, crosshair, table, chat box, ballot, the glance pieces and which FC pieces moved, what is deliberately not here |
| [docs/testing.md](docs/testing.md) | adding a check, or believing one; the screenshots |
| [docs/history.md](docs/history.md) | the bugs, and how each looked |

## Layout

| Path | What |
| --- | --- |
| `addons/gs_ui/core/` | `GSScreen`, `GSScreenStack`, `GSUiTheme`, `GSInputBinding`, `GSUiGamespice` (opt-in Gamespice tokens and styleboxes shared with the web shell and GameSpice Menu, API 24) |
| `addons/gs_ui/hud/` | `GSHud`, `GSHudWidget`, `GSStatBar`, `GSCrosshair` (`dynamic`, `set_spread`), `GSCrosshairCvars` (`cl_crosshair_*` client cvars, API 10), `GSHudElementCvars` (`cl_hud_show_<element>`, `cl_hud_scale`; perf panel off by default; API 22), `GSFeedView`, `GSTableView`, `GSChatWindow`, `GSBallotPanel`, `GSStarfield`; the glance pieces on `GSHudPiece`: `GSVitals`, `GSAmmoCounter`, `GSScoreStrip`, `GSHitMarker`, `GSDamageNumbers`, `GSKeyPrompt`, `GSKeyHints`, `GSWeaponIconPlate`, `GSStatusLines`, `GSLoadoutBar` (one row of weapon/kit slots plus a weight bar; slot dictionaries key/icon/name/text/selected/low/empty/accent/fill, glyph from API 28; API 26; [hud](docs/hud.md#loadout-bar)), `GSHealthTag` (3D pill health bar and name over a player, API 23), `GSTouchButtons` (on-screen buttons for touch, `tools/touch_shot.sh`) |
| `addons/gs_ui/icons/` | `GSIconSet` (icons by id or tag, per-profile overrides, flat), `GSWeaponIcons.stock()` (Jestan's CC0 sheet, `jestan/CREDITS.md`; API 12), `GSWeaponIconStyle` (a game's tag table, `cl_weapon_icons`, halo, menu card; API 13); [hud](docs/hud.md#weapon-icons) |
| `addons/gs_ui/panels/` | `GSSettingsPanel`, `GSBindingsPanel`, `GSServerList` (rows from `GSBrowserEntry.to_row()` as dictionaries; select then Join; phone-width stacking; API 24; `tools/server_list_shot.sh`) |
| `addons/gs_ui/screens/` | `GSPauseScreen`, `GSSettingsScreen`, `GSScoreboardScreen`; `GSWinnerReveal`, the end-of-match winner and podium (its own layer, not a stack screen) |
| `addons/gs_ui/form/` | `GSUiForm` (schema-driven form), `GSFormTokens`, `GSFormSchema`, `GSFormRow`, `GSFormGroup`, `GSFormSlider`, `GSFormToggle`, `GSFormKeypad` (on-screen keyboard); [docs/form.md](docs/form.md), `examples/form_demo.tscn`, `examples/form_selftest.tscn`, `tools/form_screenshot.sh` |
| `addons/gs_ui/gs_ui_config.gd` | `GSUiConfig`, the interface's own settings document |
| `examples/ui_selftest.tscn` | the suite, offline |
| `tools/screenshot.sh` | renders pause, settings, HUD, chat, ballot, ballot-result and the three glance-piece frames (`hud_pieces*.png`: no theme, light theme, fitted to 854x480) to `screenshots/` through `xvfb-run` |

## Running and testing

- Link `addons/gs_core` once ([development setup](../../docs/development-setup.md)), then the family's two steps ([family CLAUDE.md](../../CLAUDE.md#validating-anything)) and `godot --headless --path . res://examples/ui_selftest.tscn`.
- **Every visual change wants `tools/screenshot.sh` run and the frame looked at.** A headless viewport is 64 × 64, so no assertion can say anything about layout relative to the window; most of this addon's bugs were found by a picture. [testing](docs/testing.md#what-a-headless-suite-cannot-see)
- Measure a size in a check, never a property. Pick fixtures that put a widget in the state its options exist for. [testing](docs/testing.md)

## Rules that bite

**The stack**

- Only `GSScreenStack._refresh()` touches `Input.mouse_mode`, `mouse_filter`, `visible` or `move_child` for a screen. `GSBallotPanel` is the one widget exception, and restores the mode it found. [screens](docs/screens.md#the-one-idea)
- `blocks_input` and `hides_below` are different flags. [screens](docs/screens.md#the-one-idea)
- Open screens go to the end of the child list, bottom first. [screens](docs/screens.md#open-screens-are-moved-to-the-end-of-the-child-list)
- Pushing an open screen raises it; popping from the middle is allowed. [screens](docs/screens.md#pushing-what-is-already-open-raises-it)
- A screen refusing `_can_pop` still consumes the key; use it sparingly. [screens](docs/screens.md#a-screen-that-refuses-to-close-still-consumes-the-key)
- A screen's id defaults to its NODE NAME; set one, and assert `stack.top_id()` after a push. A property named like a `GSScreen` method (`screen_id`) breaks the *using* file and hangs the scene: it is `id_override`. [screens](docs/screens.md#a-screens-id)
- `GSWinnerReveal` is timed by `advance`, never tweens, so a check steps it exactly; `reduced_motion` draws its last frame from the first and bursts nothing. [screens](docs/screens.md#the-winner-reveal)
- `allow_pause` defaults to off: pausing desyncs a networked client. [screens](docs/screens.md#allow_pause-defaults-to-off)

**Panels and screens**

- `GSSettingsScreen` applies in two steps (panel into the snapshot, snapshot into the source via `absorb_config`); a check must read the manager after Apply. [screens](docs/screens.md#the-pause-and-settings-screens)
- Pause button ids are derived from labels, never a parallel list. [screens](docs/screens.md#the-pause-and-settings-screens)
- `GSSettingsPanel` never shows a secret (`show_sensitive` off), commits text on submit/focus-out, and rolls back every edit on a failed `apply()`. [screens](docs/screens.md#gssettingspanel-must-never-show-a-secret)
- Bindings compare by physical keycode; an action left with no events resets to default; escape cancels capture; an absent `bindings` key is a failure; `ui_*` hidden. Sort `StringName`s as Strings. [screens](docs/screens.md#gsbindingspanel-three-things-a-naive-rebinder-gets-wrong)
- `GSInputBinding.apply` replaces, never adds; `ensure_action` never overwrites a player's choice; its vocabulary is `event_name`'s. A forwarder to GameSpice Input's `GSInputText`/`GSInputMap`, where the code lives. [screens](docs/screens.md#gsinputbinding-one-binding-as-a-short-string)
- The wheel and side buttons are written by name (`Wheel up`, `Mouse back`), and the old `Mouse 4` must keep reading as the wheel; a rename here is an API level. [screens](docs/screens.md#gsinputbinding-one-binding-as-a-short-string)

**Widgets**

- `GSUiTheme.build()` returns a fresh `Theme` every call. [hud](docs/hud.md#ships-no-art-names-nothing-outside-gs-core)
- Widgets pull on a throttle; `refresh_on_change` where lateness is a lie. A stat bar eases the bar, never the number, exponentially. [hud](docs/hud.md#widgets-pull-and-the-throttle-is-the-point)
- The crosshair gap is the real projection at the real FOV; `suppressed`, not `hidden` or `visible`. [hud](docs/hud.md#the-crosshair-does-the-real-projection)
- The crosshair fades out while aiming down sights through `aim_source` (the view model's aim fraction) or `set_aim`, never snapped; a game with its own dot uses `opacity_for_aim`. [hud](docs/hud.md#the-crosshair-fades-while-aiming-down-sights)
- `GSTableView` is boxes, never a grid; an absent width is an equal share, zero shrinks to content. [hud](docs/hud.md#gstableview)
- A control built in code: use `set_anchors_and_offsets_preset`, or set all four offsets after the anchors. [hud](docs/hud.md#the-chat-box)
- Never consume every key in `_input` (it starves a focused `LineEdit`); the ballot takes only its number keys, and none while a text field has focus. [hud](docs/hud.md#the-chat-box)
- An open key is an `InputMap` action, never a hardcoded key. [hud](docs/hud.md#the-chat-box)
- `GSChatWindow` runs `!sm` / `/sm` itself and never emits them; `add_said` drops a self-muted speaker. The list is found by registry name or path, never named. [hud](docs/hud.md#the-chat-box)
- A ballot's unconfirmed local click outranks a disagreeing server state for `PENDING_MS` on the same options; a closed result snaps the avatars. [hud](docs/hud.md#a-ballot-on-the-hud)
- A glance piece takes values, never a game object; its colours are theme colours on `GSHudPiece` with `DEFAULTS` behind them; it says where it draws in `footprint()`. [hud](docs/hud.md#the-glance-pieces)
- The default HUD is dark (deep plates, dark key caps, tinted score plates); the bright look is a theme, never the default. A layer's look is one `Theme` on its root (`GSHudPiece.theme_from`), replaced live, never a walk of the pieces; a game's accent theme sets `highlight`/`plate_edge` and leaves plate, text and ink to the theme. [hud](docs/hud.md#the-glance-pieces)
- A piece's font is a `font` a theme sets on the type `GSHudPiece`, looked up by name; never `has_theme_font`, which is true whenever any theme has a default font (the engine's does). [hud](docs/hud.md#the-glance-pieces)
- A piece tests each `gs_hud_cover` member on its own against its footprint, never the merged rect, and the full-rect pieces (hit marker, damage numbers) default to `IGNORE`. [hud](docs/hud.md#the-glance-pieces)
- `GSHud.fit_design` scales the whole HUD below the design frame and never lays it out again; zero keeps the full-rect anchoring. [hud](docs/hud.md#the-glance-pieces)
- A new piece or a new public method on one is an API level (`gs_ui_api.gd`): a delivered pack runs on the shell's GameSpice UI. [hud](docs/hud.md#the-glance-pieces)

## Where a game plugs in

| To change | Where |
| --- | --- |
| What the interface looks like | assign a `Theme`, or `GSUiTheme` with a palette |
| A screen | `GSScreen` subclass registered on a `GSScreenStack` |
| What a HUD number shows | a `Callable` on `GSHudWidget` / `GSStatBar` / `GSCrosshair` |
| The scoreboard's rows and columns | `GSScoreboardScreen.row_fn` / `columns`; `GSTableView.scoreboard_columns()` for the standard ones |
| Where settings come from | any `Object` with `to_config()` / `absorb_config()`, or a `GSConfig`, on `GSSettingsScreen` |
| What may be rebound | `GSBindingsPanel` (prefix filter, `ui_*` hidden) |
| One binding in a settings document | `GSInputBinding` |
| How chat is sent and received | `GSChatWindow.submitted` and `add_message`; `open_action`, `max_lines`, margins, `outline_size` |
| What a ballot choice does | `GSBallotPanel.chosen` |
| Health, ammunition, the clock and scores, hit feedback, key prompts | the glance pieces' `show_*` / `flash` / `add`; `cover_mode`; theme colours on `GSHudPiece` |
| Scaling a HUD on a small frame, or to the player's size | `GSHud.fit_design`, `fit_scale`, `fit_to_frame`; `user_scale`, `fit_control` |
| A whole HUD layer's colours, switched live | `GSHudPiece.theme_from` on the layer's root (GameSpice Menu's `follow_hud` does it per theme) |
| Keeping a game's HUD out from under a ballot | read the visible members of the `gs_hud_cover` group by that string ([hud](docs/hud.md#a-ballot-on-the-hud)) |

Deliberately not here: screen transitions (`transition_sec` and `GSUiConfig.reduced_motion` are read by nothing; `GSWinnerReveal` has its own `reduced_motion`), localisation, gamepad focus rings, a console, a server browser, textured styling, touch layouts. [hud](docs/hud.md#deliberately-not-here)
