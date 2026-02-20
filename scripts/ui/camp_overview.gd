extends Control
## CampOverview — Ararat camp screen. Shows milestones and a Continue button.
## Stats are now displayed in the persistent HUDPanel.

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var flags_label: RichTextLabel = $VBoxContainer/MilestonesPanel/FlagsText
@onready var continue_btn: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	_refresh()
	GameState.state_changed.connect(_refresh)


func setup(_data: Dictionary) -> void:
	pass


func _refresh() -> void:
	var gs := GameState

	header_label.text = "Camp — %s" % gs.phase.capitalize()

	# Show active flags
	var active: Array[String] = []
	for key in gs.flags:
		var val = gs.flags[key]
		if val != null and val != false and val != 0 and val != "":
			if val is bool:
				active.append("[color=#c9a962]%s[/color]" % key)
			else:
				active.append("[color=#c9a962]%s[/color] = %s" % [key, str(val)])

	if active.is_empty():
		flags_label.text = "[i]No flags set yet.[/i]"
	else:
		flags_label.text = "\n".join(active)

	# Update button text to show next season
	var next_idx := (gs.season_idx + 1) % 4
	var next_season: String = GameState.SEASONS[next_idx]
	var next_year := gs.year + (1 if gs.season_idx == 3 else 0)
	continue_btn.text = "Continue to %s — Year %d" % [next_season, next_year]


func _on_continue() -> void:
	# Prevent double-clicks
	continue_btn.disabled = true

	var gs := GameState

	# Year-end tick when wrapping from Summer (idx 3) to Autumn (idx 0)
	if gs.season_idx == 3:
		_year_end_tick(gs)

	# Advance to next season
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

	if gs.game_over:
		gs.state_changed.emit()
		ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	# Emit state_changed so HUD refreshes automatically
	gs.state_changed.emit()

	# Check if there are any events for this season before switching
	var valid := EventManager.get_valid_events()
	if valid.is_empty():
		# No events — stay on camp overview, just refresh
		_refresh()
		continue_btn.disabled = false
		return

	# Switch to event screen and fire events
	# Connect before switching — this instance gets freed during transition
	ScreenManager.transition_complete.connect(
		func(): EventManager.run_season_events(),
		CONNECT_ONE_SHOT
	)
	ScreenManager.switch_to(ScreenManager.Screen.EVENT)


func _year_end_tick(gs: Node) -> void:
	# Simplified Ararat year-end: food production, livestock growth, chain decay
	var pop := gs.total_bnei_brit
	var food_produced := pop * 3
	var food_consumed := pop * 2
	gs.food = max(0, gs.food + food_produced - food_consumed)
	gs.yearly_food_produced = food_produced
	gs.yearly_food_consumed = food_consumed

	# Livestock natural growth (+5%)
	var growth := int(gs.livestock * 0.05)
	gs.livestock += growth
	gs.yearly_livestock_growth = growth

	# Chain decay if no BC assigned to Teaching
	var has_teacher := false
	for a in gs.bc_assignments:
		if a.get("type", "") == "Teaching":
			has_teacher = true
			break
	if not has_teacher and gs.bc_count == 0:
		gs.chain_integrity = max(0, gs.chain_integrity - 1)
