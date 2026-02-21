extends Control
## Main — Root scene. Sets up layout references and kicks off the game.
## Also handles season-complete transitions (must live on a node that is never freed).

@onready var hud_panel: PanelContainer = $HUDPanel
@onready var content_area: Control = $ContentArea
@onready var advisor_strip: PanelContainer = $AdvisorStrip
@onready var transition_rect: ColorRect = $TransitionRect


func _ready() -> void:
	ScreenManager.setup(content_area, hud_panel, advisor_strip, transition_rect)
	EventManager.season_events_complete.connect(_on_season_events_complete)
	ScreenManager.switch_to(ScreenManager.Screen.INTRO)


func _on_season_events_complete() -> void:
	## Runs on Main (never freed) so the coroutine survives screen transitions.
	print("[Main] season_events_complete received")
	# Reset advisor portraits before leaving event screen
	_reset_advisor_strip()
	# Brief pause so the player can read the last effect text
	await get_tree().create_timer(0.5).timeout

	# Advance season AFTER events have fired
	var gs := GameState
	_advance_season(gs)

	if gs.game_over:
		print("[Main] Game over after season advance")
		gs.state_changed.emit()
		await ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	gs.state_changed.emit()
	print("[Main] Switching to CAMP_OVERVIEW (season now %d, year %d)" % [gs.season_idx, gs.year])
	await ScreenManager.switch_to(ScreenManager.Screen.CAMP_OVERVIEW)
	print("[Main] CAMP_OVERVIEW loaded")


func _advance_season(gs: Node) -> void:
	## Advances to the next season, handles year-end tick and game-over checks.
	if gs.season_idx == 3:
		_year_end_tick(gs)

	gs.season_idx += 1
	if gs.season_idx >= 4:
		gs.season_idx = 0
		gs.year += 1
		gs.reset_yearly_accumulators()

	# Check game over
	if gs.chain_integrity <= 0:
		gs.game_over = true
		gs.game_over_reason = "The chain is broken. The flame goes out."
	if gs.food <= 0:
		gs.flags["famine_turns"] = gs.flags.get("famine_turns", 0) + 1
		if gs.flags["famine_turns"] >= 2:
			gs.game_over = true
			gs.game_over_reason = "Famine. The people scatter."
	else:
		gs.flags["famine_turns"] = 0


func _year_end_tick(gs: Node) -> void:
	var pop := gs.total_bnei_brit
	var food_produced := pop * 3
	var food_consumed := pop * 2
	gs.food = max(0, gs.food + food_produced - food_consumed)
	gs.yearly_food_produced = food_produced
	gs.yearly_food_consumed = food_consumed

	var growth := int(gs.livestock * 0.05)
	gs.livestock += growth
	gs.yearly_livestock_growth = growth

	var has_teacher := false
	for a in gs.bc_assignments:
		if a.get("type", "") == "Teaching":
			has_teacher = true
			break
	if not has_teacher and gs.bc_count == 0:
		gs.chain_integrity = max(0, gs.chain_integrity - 1)


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
