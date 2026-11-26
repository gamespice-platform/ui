extends RefCounted

## GameSpice UI's API level. The rule for bumping it is on [GSAddonApi].
##
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning,
## because every pack built before that no longer compiles against this addon.

# 1: everything before this file existed (an absent file reads as 1).
# 2: GSInputBinding names the wheel and the side buttons ("Wheel up", "Mouse back";
#    MOUSE_NAMES, mouse_text) and still reads the old "Mouse 4". A game that wrote its own
#    "(wheel up)" beside a "Mouse 4" can ask for this level before dropping it.
# 3: GSChatWindow honours the player's own block list: self_mute, self_mute_enabled,
#    self_mute_colour, is_self_muted(); `!sm` / `/sm` are run and never emitted.
# 4: the glance pieces: GSHudPiece (theme colours, footprint, cover_mode, cover_rects,
#    covered_rect), GSVitals, GSAmmoCounter, GSScoreStrip, GSHitMarker,
#    GSDamageNumbers, GSKeyPrompt, GSKeyHints; GSHud.fit_design, fit_min, fit_scale,
#    fit, fit_to_frame; GSUiTheme.highlight and the GSHudPiece theme colours.
# 5: GSCrosshair fades out while aiming down sights: aim_source, set_aim(), aim_hide_by,
#    aim_fade_sec, aim_opacity, follow_aim(), opacity_for_aim().
# 6: the dark HUD and themes a game can switch live: GSHudPiece.theme_from(), number(),
#    COLOUR_KEYS, DEFAULT_CONSTANTS, the keycap_edge colour and the team_fill constant (the
#    defaults are now the dark HUD); GSHud.user_scale and fit_control().
# 7: the schema form kit: GSUiForm, GSFormTokens, GSFormSchema, GSFormRow, GSFormGroup,
#    GSFormSlider, GSFormToggle (addons/gs_ui/form/).
# 8: the form kit's list reorder (GSFormRow.move_item, the schema key `reorder`) and
#    gamepad text entry (GSFormKeypad, GSUiForm.open_keypad, keypad, gamepad_entry).
# 9: GSWinnerReveal, the end-of-match winner and podium (addons/gs_ui/screens/).
# 10: GSCrosshair.dynamic and set_spread(); GSCrosshairCvars (cl_crosshair_* client cvars).
# 11: GSFireModeIndicator (A / one bullet / three bullets for the held gun's fire modes).
# 12: GSIconSet (icons by id or tag from a sheet, per-profile overrides, flat recolour) and
#    GSWeaponIcons.stock(), Jestan's CC0 weapon sprites (addons/gs_ui/icons/).
# 13: GSWeaponIconStyle (a game's id-to-tag table, cl_weapon_icons / cl_weapon_icon_profile cvars, halo, menu card).
# 14: GSCrosshair hides while the viewer is dead: hide_when_dead, alive_source, set_alive(), is_shown().
# 15: GSCrosshair eases a closing gap: close_sec, ease_spread(), spread_shown(); cl_crosshair_ease.
# 16: GSUiForm.set_only_modified(), only_modified(): the Modified chip beside search.
# 17: GSVitals hosts the killstreak: show_streak(), streak_format, streak_icon, has_streak_row().
# 18: GSCrosshair.hold_progress, a ring round the crosshair that fills during a hold.
# 19: GSTouchButtons, round on-screen buttons for touch (button_down/up, contains_point, fps_stock).
# 20: GSUiForm conditional rows (`visible_if` in a schema) and vector2/vector3 fields (GSFormRow.type_component).
# 21: GSHitFeedback, the hit marker and damage numbers mounted and fed together (mount, confirm_hit).
# 22: GSHudElementCvars (cl_hud_show_<element>, cl_hud_scale; perf panel off by default).
# 23: GSHealthTag, the pill health bar and name over another player's head (update, face).
# 24: GSUiGamespice (Gamespice's tokens, card, focus ring, primary/ghost buttons, rows, fit_factor)
#     and GSServerList (a focusable, phone-width server list that takes rows as dictionaries).
# 25: GSHealthTag.configure (per-game name/bar visibility, hover reveal, opacity).
# 26: GSLoadoutBar, the bottom-right row of weapon and kit slots with a weight bar (set_slots, set_weight).
# 27: GSLoadoutBar.set_layout: STACK (a right-edge column of plates) and BUTTONS (ability buttons with cooldowns).
const LEVEL := 27
const OLDEST := 1
