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


func _on_season_events_complete() -> void:
	## After narrative events finish, show the allocation screen.
	print("[Main] season_events_complete received")
	_reset_advisor_strip()
	await get_tree().create_timer(0.5).timeout

	var gs := GameState

	if gs.game_over:
		print("[Main] Game over after events")
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	# Show allocation screen
	await _show_allocation()


func _show_allocation() -> void:
	## Display the allocation screen and wait for the player to confirm.
	print("[Main] Switching to ALLOCATION")
	await ScreenManager.switch_to(ScreenManager.Screen.ALLOCATION)

	var alloc_screen := ScreenManager.get_current_instance()
	if alloc_screen and alloc_screen.has_signal("allocation_confirmed"):
		await alloc_screen.allocation_confirmed
	else:
		push_warning("[Main] Allocation screen missing or no signal")
		return

	# Resolve the season
	var summary: Dictionary = SeasonResolver.resolve_season()
	print("[Main] Season resolved, showing summary")

	var gs := GameState

	# Check for game over
	if gs.game_over:
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	# Show season summary
	await ScreenManager.switch_to(ScreenManager.Screen.SEASON_SUMMARY, {"summary": summary})
	var summary_screen := ScreenManager.get_current_instance()
	if summary_screen and summary_screen.has_signal("continue_pressed"):
		await summary_screen.continue_pressed

	# Advance to next season
	_advance_season(gs)

	if gs.game_over:
		print("[Main] Game over after season advance")
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	gs.state_changed.emit()
	print("[Main] Advanced to season %d, year %d" % [gs.season_idx, gs.year])

	# Check for events in the new season
	var valid := EventManager.get_valid_events()
	if not valid.is_empty():
		print("[Main] New season has %d events, firing" % valid.size())
		ScreenManager.transition_complete.connect(
			func(): EventManager.run_season_events(),
			CONNECT_ONE_SHOT
		)
		await ScreenManager.switch_to(ScreenManager.Screen.EVENT)
		# season_events_complete will fire → _on_season_events_complete → allocation again
	else:
		# No events — go straight to allocation
		print("[Main] No events for new season, showing allocation")
		await _show_allocation()


func _advance_season(gs: Node) -> void:
	## Advances to the next season. Year-end logic is now minimal
	## since SeasonResolver handles the economics.
	gs.season_idx += 1
	if gs.season_idx >= 4:
		gs.season_idx = 0
		gs.year += 1
		gs.reset_yearly_accumulators()

	# Game over check (living_fire already checked in resolver)
	if gs.living_fire <= 0:
		gs.game_over = true
		gs.game_over_reason = "The chain is broken. The flame goes out."


func _on_music_toggle() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(bus_idx)
	AudioServer.set_bus_mute(bus_idx, not muted)
	music_toggle.text = "♪" if muted else "—"
	music_toggle.modulate.a = 1.0 if muted else 0.4


func _reset_advisor_strip() -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/VBoxContainer/HBoxContainer")
	if not hbox:
		return
	for pname in ["ShemPortrait", "HamPortrait", "JaphethPortrait", "NaamahPortrait"]:
		var portrait := hbox.get_node_or_null(pname) as TextureRect
		if portrait:
			portrait.modulate = Color(1, 1, 1, 0.6)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if bubble:
		bubble.text = ""
