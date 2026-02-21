extends Control
## CampOverview — Ararat camp screen. Shows milestones and a Continue button.
## Stats are now displayed in the persistent HUDPanel.

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var flags_label: RichTextLabel = $VBoxContainer/MilestonesPanel/FlagsText
@onready var continue_btn: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	print("[CampOverview] _ready — connecting button")
	continue_btn.pressed.connect(_on_continue)
	_refresh()
	GameState.state_changed.connect(_refresh)


func setup(_data: Dictionary) -> void:
	pass


func _refresh() -> void:
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

	# Update button text
	var has_events := not EventManager.get_valid_events().is_empty()
	if has_events:
		continue_btn.text = "Continue"
	else:
		var next_idx := (gs.season_idx + 1) % 4
		var next_season: String = GameState.SEASONS[next_idx]
		var next_year := gs.year + (1 if gs.season_idx == 3 else 0)
		continue_btn.text = "Continue to %s — Year %d" % [next_season, next_year]


func _on_continue() -> void:
	print("[CampOverview] Continue clicked — season_idx=%d, year=%d" % [GameState.season_idx, GameState.year])
	continue_btn.disabled = true

	var gs := GameState

	# Check for events in the CURRENT season BEFORE advancing
	var valid := EventManager.get_valid_events()
	print("[CampOverview] Valid events for current season: %d" % valid.size())

	if not valid.is_empty():
		# Events to fire — switch to event screen
		# Season advances AFTER events complete (in main.gd _on_season_events_complete)
		print("[CampOverview] Switching to EVENT screen")
		ScreenManager.transition_complete.connect(
			func(): EventManager.run_season_events(),
			CONNECT_ONE_SHOT
		)
		ScreenManager.switch_to(ScreenManager.Screen.EVENT)
		return

	# No events this season — advance season now
	_advance_season(gs)

	if gs.game_over:
		print("[CampOverview] Game over")
		gs.state_changed.emit()
		ScreenManager.switch_to(ScreenManager.Screen.GAME_OVER)
		return

	gs.state_changed.emit()
	_refresh()
	continue_btn.disabled = false


func _advance_season(gs: Node) -> void:
	## Advances to the next season, handles year-end tick and game-over checks.
	# Year-end tick when wrapping from Summer (idx 3) to Autumn (idx 0)
	if gs.season_idx == 3:
		_year_end_tick(gs)

	gs.season_idx += 1
	if gs.season_idx >= 4:
		gs.season_idx = 0
		gs.year += 1
		gs.reset_yearly_accumulators()

	# Check game over
	if gs.living_fire <= 0:
		gs.game_over = true
		gs.game_over_reason = "The chain is broken. The flame goes out."
	if gs.food <= 0:
		gs.flags["famine_turns"] = gs.flags.get("famine_turns", 0) + 1
		if gs.flags["famine_turns"] >= 2:
			gs.game_over = true
			gs.game_over_reason = "Famine. The people scatter."
	else:
		gs.flags["famine_turns"] = 0


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
		"days_of_silence_done": return "The dead were mourned"
		"tents_location":
			match str(val):
				"altar": return "Tents built near the altar"
				"valley": return "Tents built in the valley"
				"ridge": return "Tents built on the ridge"
				_: return ""
		"vine_wintered": return "The vine survived winter"
		"vine_protection": return ""
		"fast_of_adam_done": return "The Fast of Adam was observed"
		"festival_of_light_done": return "The Festival of Light was celebrated"
		"first_flame_lighter": return ""
		"first_flame_lit": return "The first flame burns"
		"vine_woke": return "The vine bears fruit"
		"brothers_dispersed": return "The brothers have gone their ways"
		"tent_chanoch_built": return "The Tent of Chanoch stands"
		"immersion_done": return "The immersion is complete"
		"immersion_path": return ""
		"covenant_festival_y0": return "The Seven Words proclaimed"
		"covenant_proclamation": return ""
		"first_pressing": return "The first wine has been pressed"
		"noah_spoke_sons": return "Noah spoke to his sons"
		"ham_incident": return "The tent"
		"canaan_remedy":
			match str(val):
				"active": return "Canaan bound to Shem"
				"partial": return "Canaan's nature named"
				"none": return ""
				_: return ""
		"canaan_born": return "Canaan is born"
		"mourning_of_abel_done": return "Abel was mourned"
		"year_0_reckoning": return "The first year is reckoned"
		"year_1_priority": return ""
		"famine_turns": return ""
		"ham_rebuke_severity": return ""
		"baal_stage_reached": return ""
		"goat_initiations_active": return ""
		# ── Year 1-7 random event flags ──
		"naamahs_loom_done": return "Naamah's pattern preserved"
		"loom_choice": return ""
		"new_spring_found": return "A new spring found"
		"spring_choice": return ""
		"raven_returned": return "The raven returned"
		"raven_choice": return ""
		"missing_star_seen": return "A star went missing"
		"star_choice": return ""
		"counting_stone_found": return "The counting stone"
		"counting_stone_choice": return ""
		"ox_event_done": return "The ox has moved"
		"ox_choice": return ""
		"morning_dance_done": return "The morning dance"
		"dance_choice": return ""
		"second_fruit_done": return "The vine's second fruit"
		"second_fruit_choice": return ""
		"moon_dispute_done": return "The moon was disputed"
		"moon_choice": return ""
		"canaan_line_done": return "The line was drawn"
		"canaan_line_choice": return ""
		"granary_built": return "The granary stands"
		"granary_choice": return ""
		"song_diverged": return "The song divided"
		"song_choice": return ""
		"cleared_ground_found": return "Cleared ground discovered"
		"cleared_ground_choice": return ""
		"soil_divides_done": return "The soil divides"
		"soil_choice": return ""
		"circle_questioned": return "The circle questioned"
		"circle_choice": return ""
		"red_flowers_found": return "Red flowers on the ridge"
		"flowers_choice": return ""
		"three_stars_seen": return "Three stars aligned"
		"three_stars_choice": return ""
		"flock_shift_done": return "The flock shifted"
		"flock_choice": return ""
		"childs_festival_done": return "The children's festival"
		"festival_child_choice": return ""
		"wind_recognised": return "Noah recognised the wind"
		"wind_choice": return ""
		"shem_absence_done": return "Shem was absent"
		"absence_choice": return ""
		"encounter_choice": return ""
		"wolf_lamb_seen": return "The wolf lay with the lamb"
		"mountain_sang": return "The mountain sang"
		"mountain_choice": return ""
		_:
			if val is bool:
				return key.replace("_", " ").capitalize()
			return "%s: %s" % [key.replace("_", " ").capitalize(), str(val)]


func _year_end_tick(gs: Node) -> void:
	var pop: int = gs.total_bnei_brit
	var food_produced: int = pop * 3
	var food_consumed: int = pop * 2
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
		gs.living_fire = max(0, gs.living_fire - 1)
