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
				active.append("[color=%s]%s[/color]" % [UIConstants.GOLD_HEX, display])

	# Buildings completed — permanent structures
	if not gs.buildings_completed.is_empty():
		active.append("")
		active.append("[color=%s]— Structures Standing —[/color]" % UIConstants.GOLD_HEX)
		for bid in gs.buildings_completed:
			var bdef: Dictionary = gs.BUILDING_DEFS.get(bid, {})
			active.append("[color=%s]%s[/color]  [color=#f5f2ebb3]%s[/color]" % [
				UIConstants.SUCCESS_GREEN, bdef.get("name", bid), bdef.get("bonus_text", "")])

	# Active construction in progress
	if gs.active_building != "" and gs.active_building_progress > 0:
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		active.append("[color=%s]Under construction: %s (%d/%d)[/color]" % [
			UIConstants.GOLD_HEX, bdef.get("name", gs.active_building),
			gs.active_building_progress, bdef.get("build_points_required", 0)])

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
		print("[CampOverview] Switching to EVENT screen")
		ScreenManager.transition_complete.connect(
			func(): EventManager.run_season_events(),
			CONNECT_ONE_SHOT
		)
		ScreenManager.switch_to(ScreenManager.Screen.EVENT)
		return

	# No events — the main.gd loop handles season advancement via allocation
	# Just switch to allocation screen
	ScreenManager.switch_to(ScreenManager.Screen.ALLOCATION)


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
