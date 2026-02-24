extends Control
## Main — Root scene. Sets up layout references and kicks off the game.
## Controls the core game loop: events → allocation → resolution → summary → next season.

@onready var hud_panel: PanelContainer = $HUDPanel
@onready var content_area: Control = $ContentArea
@onready var advisor_strip: PanelContainer = $AdvisorStrip
@onready var transition_rect: ColorRect = $TransitionRect
@onready var music_toggle: Button = $MusicToggle


func _ready() -> void:
	ScreenManager.setup(content_area, hud_panel, advisor_strip, transition_rect)
	EventManager.season_events_complete.connect(_on_season_events_complete)
	music_toggle.pressed.connect(_on_music_toggle)
	ScreenManager.switch_to(ScreenManager.Screen.INTRO)


func get_advisor_portraits() -> HBoxContainer:
	## Centralized access point for advisor portrait container.
	## Used by event_screen.gd to avoid fragile hardcoded paths.
	return $AdvisorStrip/VBoxContainer/HBoxContainer


func get_elders_label() -> Label:
	var label: Label = $AdvisorStrip/VBoxContainer/EldersLabel
	# Enforce font size in code (in case tscn cache is stale)
	if label:
		label.add_theme_font_size_override("font_size", 22)
	return label


func _on_season_events_complete() -> void:
	_reset_advisor_strip()
	await get_tree().create_timer(0.5).timeout

	var gs := GameState

	if gs.game_over:
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	await _show_allocation()


func _show_allocation() -> void:
	await ScreenManager.switch_to(ScreenManager.Screen.ALLOCATION)

	var alloc_screen := ScreenManager.get_current_instance()
	if alloc_screen and alloc_screen.has_signal("allocation_confirmed"):
		# Timeout after 10 minutes to prevent infinite hang
		var timer := get_tree().create_timer(600.0)
		var result = await _await_with_timeout(alloc_screen.allocation_confirmed, timer.timeout)
		if result == "timeout":
			push_error("[Main] Allocation screen timed out")
			return
	else:
		push_warning("[Main] Allocation screen missing or no signal")
		return

	var summary: Dictionary = SeasonResolver.resolve_season()

	var gs := GameState

	if gs.game_over:
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	await ScreenManager.switch_to(ScreenManager.Screen.SEASON_SUMMARY, {"summary": summary})
	var summary_screen := ScreenManager.get_current_instance()
	if summary_screen and summary_screen.has_signal("continue_pressed"):
		await summary_screen.continue_pressed

	_advance_season(gs)

	if gs.game_over:
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	gs.state_changed.emit()

	var valid := EventManager.get_valid_events()
	if not valid.is_empty():
		ScreenManager.transition_complete.connect(
			Callable(EventManager, "run_season_events"),
			CONNECT_ONE_SHOT
		)
		await ScreenManager.switch_to(ScreenManager.Screen.EVENT)
	else:
		await _show_allocation()


func _advance_season(gs: Node) -> void:
	gs.season_idx += 1
	if gs.season_idx >= 4:
		gs.season_idx = 0
		gs.year += 1
		gs.reset_yearly_accumulators()
	print("[GAME] Y%d S%d" % [gs.year, gs.season_idx])

	if gs.living_fire <= 0:
		gs.game_over = true
		gs.game_over_reason = "The chain is broken. The flame goes out."


func _on_music_toggle() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(bus_idx)
	AudioServer.set_bus_mute(bus_idx, not muted)
	music_toggle.text = "♪" if muted else "—"
	music_toggle.modulate.a = 1.0 if muted else 0.4


func _await_with_timeout(sig: Signal, timeout: Signal) -> String:
	var result := ""
	sig.connect(func(): result = "done", CONNECT_ONE_SHOT)
	timeout.connect(func(): result = "timeout", CONNECT_ONE_SHOT)
	while result == "":
		await get_tree().process_frame
	return result


func _reset_advisor_strip() -> void:
	var hbox := get_advisor_portraits()
	if not hbox:
		return
	for pname in ["ShemPortrait", "HamPortrait", "JaphethPortrait", "NaamahPortrait"]:
		var portrait := hbox.get_node_or_null(pname) as TextureRect
		if portrait:
			portrait.modulate = UIConstants.PORTRAIT_RESET
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if bubble:
		bubble.text = ""
