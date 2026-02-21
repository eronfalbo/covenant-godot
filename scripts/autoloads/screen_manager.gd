extends Node
## ScreenManager — Controls which scene is shown in the content area.

enum Screen {
	INTRO,
	EVENT,
	CAMP_OVERVIEW,
	FESTIVAL,
	YEAR_SUMMARY,
	GAME_OVER,
}

signal screen_changed(new_screen: Screen)
signal transition_complete

var current_screen: Screen = Screen.INTRO
var _content_area: Control = null
var _current_instance: Node = null
var _hud_panel: Control = null
var _advisor_strip: Control = null
var _transition_rect: ColorRect = null

const SCREEN_SCENES := {
	Screen.INTRO: "res://scenes/intro/intro_sequence.tscn",
	Screen.EVENT: "res://scenes/event/event_screen.tscn",
	Screen.CAMP_OVERVIEW: "res://scenes/management/camp_overview.tscn",
	Screen.GAME_OVER: "res://scenes/ui/game_over_screen.tscn",
}

const FADE_DURATION := 0.3


func setup(content_area: Control, hud_panel: Control, advisor_strip: Control, transition_rect: ColorRect) -> void:
	_content_area = content_area
	_hud_panel = hud_panel
	_advisor_strip = advisor_strip
	_transition_rect = transition_rect
	# Clear stale reference from previous scene (e.g. after reload_current_scene)
	_current_instance = null


func switch_to(screen: Screen, data: Dictionary = {}) -> void:
	current_screen = screen

	# Fade out
	if _transition_rect:
		await _fade(_transition_rect, 0.0, 1.0)

	# Remove old scene
	if _current_instance and is_instance_valid(_current_instance):
		_current_instance.queue_free()
		_current_instance = null

	# Load and instantiate new scene
	var path: String = SCREEN_SCENES.get(screen, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("ScreenManager: no scene for screen %s" % Screen.keys()[screen])
		if _transition_rect:
			await _fade(_transition_rect, 1.0, 0.0)
		return

	var scene := load(path) as PackedScene
	_current_instance = scene.instantiate()

	_content_area.add_child(_current_instance)

	if _current_instance.has_method("setup"):
		_current_instance.setup(data)

	# Toggle HUD visibility
	_update_hud_visibility(screen)

	# Fade in
	if _transition_rect:
		await _fade(_transition_rect, 1.0, 0.0)

	screen_changed.emit(screen)
	transition_complete.emit()


func get_current_instance() -> Node:
	return _current_instance


func _update_hud_visibility(screen: Screen) -> void:
	# Show HUD for EVENT and CAMP_OVERVIEW, hide for INTRO and GAME_OVER
	match screen:
		Screen.EVENT, Screen.CAMP_OVERVIEW:
			if _hud_panel: _hud_panel.visible = true
			# Shrink content area to make room for HUD and advisor strip
			if _content_area: _content_area.offset_right = -280
			if _content_area: _content_area.offset_bottom = -110
			if _advisor_strip: _advisor_strip.offset_right = -280
		_:
			if _hud_panel: _hud_panel.visible = false
			# Expand content area to full width when HUD hidden
			if _content_area: _content_area.offset_right = 0
			if _content_area: _content_area.offset_bottom = 0
			if _advisor_strip: _advisor_strip.offset_right = 0

	# Advisor strip always visible except intro and game over
	if _advisor_strip:
		_advisor_strip.visible = screen != Screen.INTRO and screen != Screen.GAME_OVER


func _fade(rect: ColorRect, from: float, to: float) -> void:
	var tween := create_tween()
	rect.modulate.a = from
	rect.visible = true
	tween.tween_property(rect, "modulate:a", to, FADE_DURATION)
	await tween.finished
	if to == 0.0:
		rect.visible = false
