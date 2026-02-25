extends Control
## Main — Root scene. Sets up layout references and kicks off the game.
## Controls the core game loop: events → allocation → resolution → summary → next season.
## Uses signal callbacks instead of nested awaits (WASM web builds break on deep await chains).

@onready var hud_panel: PanelContainer = $HUDPanel
@onready var content_area: Control = $ContentArea
@onready var advisor_strip: PanelContainer = $AdvisorStrip
@onready var transition_rect: ColorRect = $TransitionRect
@onready var music_toggle: Button = $MusicToggle


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	ScreenManager.setup(content_area, hud_panel, advisor_strip, transition_rect)
	EventManager.season_events_complete.connect(_on_season_events_complete)
	ScreenManager.transition_complete.connect(_on_transition_complete)
	music_toggle.pressed.connect(_on_music_toggle)
	ScreenManager.switch_to(ScreenManager.Screen.INTRO)


func _unhandled_input(event: InputEvent) -> void:
	# DEBUG: F9 skips intro and jumps to allocation
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		print("[DEBUG] F9 — skip to allocation")
		GameState.phase = "ararat"
		GameState.year = 0
		GameState.season_idx = 0
		_phase = Phase.SWITCHING_TO_ALLOCATION
		ScreenManager.switch_to(ScreenManager.Screen.ALLOCATION)


func get_advisor_portraits() -> HBoxContainer:
	return $AdvisorStrip/VBoxContainer/HBoxContainer


func get_elders_label() -> Label:
	var label: Label = $AdvisorStrip/VBoxContainer/EldersLabel
	if label:
		label.add_theme_font_size_override("font_size", 22)
	return label


# ── Game loop state machine ──
# Instead of nested awaits, we track what phase we're in and react to signals.

enum Phase { IDLE, SWITCHING_TO_ALLOCATION, WAITING_CONFIRM, SWITCHING_TO_SUMMARY, WAITING_SUMMARY, SWITCHING_TO_EVENTS, SWITCHING_TO_GAME_OVER }
var _phase: Phase = Phase.IDLE
var _pending_summary: Dictionary = {}


func _on_season_events_complete() -> void:
	_reset_advisor_strip()
	# Small delay then show allocation
	get_tree().create_timer(0.5).timeout.connect(_after_events_delay, CONNECT_ONE_SHOT)


func _after_events_delay() -> void:
	var gs := GameState
	if gs.game_over:
		gs.state_changed.emit()
		_phase = Phase.SWITCHING_TO_GAME_OVER
		ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return
	_phase = Phase.SWITCHING_TO_ALLOCATION
	print("[Main] Switching to ALLOCATION")
	ScreenManager.switch_to(ScreenManager.Screen.ALLOCATION)


func _on_transition_complete() -> void:
	print("[Main] transition_complete, phase=%d" % _phase)
	match _phase:
		Phase.SWITCHING_TO_ALLOCATION:
			_phase = Phase.WAITING_CONFIRM
			var alloc_screen := ScreenManager.get_current_instance()
			if alloc_screen and alloc_screen.has_signal("allocation_confirmed"):
				print("[Main] Connecting allocation_confirmed")
				alloc_screen.allocation_confirmed.connect(_on_allocation_confirmed, CONNECT_ONE_SHOT)
			else:
				push_warning("[Main] No allocation screen or signal")

		Phase.SWITCHING_TO_SUMMARY:
			_phase = Phase.WAITING_SUMMARY
			var summary_screen := ScreenManager.get_current_instance()
			if summary_screen and summary_screen.has_signal("continue_pressed"):
				summary_screen.continue_pressed.connect(_on_summary_continue, CONNECT_ONE_SHOT)

		Phase.SWITCHING_TO_EVENTS:
			_phase = Phase.IDLE
			EventManager.run_season_events()

		Phase.SWITCHING_TO_GAME_OVER:
			_phase = Phase.IDLE

		_:
			pass  # IDLE or other phases — ignore


func _on_allocation_confirmed() -> void:
	print("[Main] allocation_confirmed received!")
	_phase = Phase.IDLE

	var summary: Dictionary = SeasonResolver.resolve_season()
	var gs := GameState

	if gs.game_over:
		gs.state_changed.emit()
		_phase = Phase.SWITCHING_TO_GAME_OVER
		ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	_pending_summary = summary
	_phase = Phase.SWITCHING_TO_SUMMARY
	ScreenManager.switch_to(ScreenManager.Screen.SEASON_SUMMARY, {"summary": summary})


func _on_summary_continue() -> void:
	print("[Main] Summary continue pressed")
	_phase = Phase.IDLE
	var gs := GameState

	_advance_season(gs)

	if gs.game_over:
		gs.state_changed.emit()
		_phase = Phase.SWITCHING_TO_GAME_OVER
		ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	gs.state_changed.emit()

	var valid := EventManager.get_valid_events()
	if not valid.is_empty():
		_phase = Phase.SWITCHING_TO_EVENTS
		ScreenManager.switch_to(ScreenManager.Screen.EVENT)
	else:
		_phase = Phase.SWITCHING_TO_ALLOCATION
		ScreenManager.switch_to(ScreenManager.Screen.ALLOCATION)


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
