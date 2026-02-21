extends Control
## CampOverview — Ararat camp screen. Shows milestones and a Continue button.
## Stats are now displayed in the persistent HUDPanel.

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var flags_label: RichTextLabel = $VBoxContainer/MilestonesPanel/FlagsText
@onready var continue_btn: Button = $VBoxContainer/ContinueButton

var _demo_complete := false


func _ready() -> void:
	print("[CampOverview] _ready — connecting button")
	continue_btn.pressed.connect(_on_continue)
	_refresh()
	GameState.state_changed.connect(_refresh)


func setup(_data: Dictionary) -> void:
	pass


func _refresh() -> void:
	if _demo_complete:
		return  # Don't overwrite demo-complete display

	var gs := GameState

	header_label.text = "%s — Year %d" % [gs.current_season, gs.year]

	# Show active flags as human-readable milestones
	var active: Array[String] = []
	for key in gs.flags:
		var val = gs.flags[key]
		if val != null and val != false and val != 0 and val != "":
			var display := _humanize_flag(key, val)
			if display != "":
				active.append("[color=#c9a962]%s[/color]" % display)

	if active.is_empty():
		flags_label.text = "[i]No milestones yet.[/i]"
	else:
		flags_label.text = "\n".join(active)

	# Update button text to show next season
	var next_idx := (gs.season_idx + 1) % 4
	var next_season: String = GameState.SEASONS[next_idx]
	var next_year := gs.year + (1 if gs.season_idx == 3 else 0)
	continue_btn.text = "Continue to %s — Year %d" % [next_season, next_year]


func _on_continue() -> void:
	print("[CampOverview] Continue clicked — season_idx=%d, year=%d" % [GameState.season_idx, GameState.year])
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
		print("[CampOverview] Game over")
		gs.state_changed.emit()
		ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	gs.state_changed.emit()

	# Check for events
	var valid := EventManager.get_valid_events()
	var remaining := EventManager.has_remaining_events()
	print("[CampOverview] Valid events: %d, remaining: %s" % [valid.size(), remaining])

	if valid.is_empty():
		if not remaining:
			# === DEMO COMPLETE — done entirely in-place, no screen switch ===
			print("[CampOverview] DEMO COMPLETE — showing end screen in-place")
			_show_demo_complete()
			return
		# Future events exist — just refresh
		_refresh()
		continue_btn.disabled = false
		return

	# Events to fire — switch to event screen
	print("[CampOverview] Switching to EVENT screen")
	ScreenManager.transition_complete.connect(
		func(): EventManager.run_season_events(),
		CONNECT_ONE_SHOT
	)
	ScreenManager.switch_to(ScreenManager.Screen.EVENT)


func _show_demo_complete() -> void:
	# Flag to prevent _refresh from overwriting
	_demo_complete = true

	# Disconnect state_changed to prevent _refresh
	if GameState.state_changed.is_connected(_refresh):
		GameState.state_changed.disconnect(_refresh)

	# Update display directly — no screen transitions
	header_label.text = "End of Vertical Slice"

	var gs := GameState
	var lines := PackedStringArray()
	lines.append("[font_size=24][color=#c9a962]The story continues...[/color][/font_size]")
	lines.append("")
	var vine_loc = gs.flags.get("vine_location", "")
	if vine_loc != null and str(vine_loc) != "":
		var loc_names := {"altar": "beside the altar", "south": "on the south slope", "valley": "in the valley"}
		lines.append("The vine grows %s." % loc_names.get(str(vine_loc), str(vine_loc)))
	if gs.flags.get("seventh_law_taught", false):
		lines.append("The Seventh Law has been spoken.")
	if gs.flags.get("altar_built", false):
		lines.append("The altar stands on Ararat.")
	lines.append("")
	lines.append("[i]More events and seasons are coming.[/i]")
	lines.append("[i]Thank you for playing the Covenant vertical slice.[/i]")
	flags_label.text = "\n".join(lines)

	# Reconfigure button for restart
	continue_btn.text = "Play Again"
	continue_btn.disabled = false
	# Remove old handler and add restart handler
	if continue_btn.pressed.is_connected(_on_continue):
		continue_btn.pressed.disconnect(_on_continue)
	continue_btn.pressed.connect(_on_restart)

	print("[CampOverview] Demo complete screen shown")


func _on_restart() -> void:
	print("[CampOverview] Play Again clicked — restarting")
	continue_btn.disabled = true
	GameState.reset()
	get_tree().reload_current_scene()


func _humanize_flag(key: String, val: Variant) -> String:
	match key:
		"altar_built": return "The altar stands"
		"vineyard_planted": return "The vineyard is planted"
		"vine_location":
			match str(val):
				"altar": return "Vine grows beside the altar"
				"south": return "Vine grows on the south slope"
				"valley": return "Vine grows in the valley"
				_: return ""
		"seventh_law_taught": return "The Seventh Law has been spoken"
		"noah_taught_law": return "Noah has taught the law"
		"first_flame_lit": return "The first flame burns"
		"brothers_dispersed": return "The brothers have gone their ways"
		"tent_chanoch_built": return "The Tent of Chanoch stands"
		"immersion_done": return "The immersion is complete"
		"covenant_festival_y0": return "The first festival was held"
		"first_pressing": return "The first wine has been pressed"
		"ham_incident": return "The incident with Ham"
		"famine_turns": return ""
		"ham_rebuke_severity": return ""
		"baal_stage_reached": return ""
		"goat_initiations_active": return ""
		_:
			if val is bool:
				return key.replace("_", " ").capitalize()
			return "%s: %s" % [key.replace("_", " ").capitalize(), str(val)]


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
