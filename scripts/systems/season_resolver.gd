extends Node
## SeasonResolver — Processes seasonal allocation into outcomes.
## Follows the 10-step resolution logic from COVENANT_MECHANICS_SPEC §7.
##
## Called by main.gd after the player confirms their allocation.
## Reads allocation from GameState (workers_on_work, workers_on_build,
## workers_on_tend, chosen_sacrifice) and applies all effects.

signal resolution_complete(summary: Dictionary)


func resolve_season() -> Dictionary:
	## Main entry point. Resolves the current season and returns a summary dict.
	var gs := GameState
	var summary := {}

	# ── Step 1: Calculate food produced ──
	var food_rate: int = gs.FOOD_PER_WORKER
	if gs.season_idx == 2:  # Spring
		food_rate = gs.FOOD_PER_WORKER_SPRING
	var food_produced: int = int(food_rate * pow(maxf(gs.workers_on_work, 0), 0.9))
	summary["food_produced"] = food_produced

	# ── Step 2: Calculate food consumed ──
	var pop: int = gs.total_bnei_brit
	var food_consumed: int = pop * gs.FOOD_PER_PERSON
	if gs.season_idx == 1:  # Winter penalty
		if not gs.has_building("warming_shelter"):
			food_consumed += gs.WINTER_FOOD_PENALTY
	summary["food_consumed"] = food_consumed

	# ── Step 3: Update food ──
	var sacrifice_food_cost: int = 0
	var sacrifice_food_return: int = 0
	var sacrifice_fire_bonus: float = 0.0
	var sacrifice_livestock_cost: int = 0

	if gs.chosen_sacrifice != "":
		var sdef: Dictionary = gs.SACRIFICE_DEFS.get(gs.chosen_sacrifice, {})
		sacrifice_food_cost = sdef.get("food_cost", 0)
		sacrifice_livestock_cost = sdef.get("livestock_cost", 0)
		sacrifice_fire_bonus = sdef.get("fire_bonus", 0.0)
		sacrifice_food_return = sdef.get("food_return", 0)

	# Chatat sacrifice clears bleeding
	if gs.chosen_sacrifice == "chatat" and gs.bleeding_active:
		gs.bleeding_active = false
		summary["bleeding_cured"] = true

	var new_food: int = gs.food + food_produced - food_consumed - sacrifice_food_cost + sacrifice_food_return
	new_food = clampi(new_food, 0, gs.food_cap)
	summary["food_before"] = gs.food
	summary["food_after"] = new_food
	gs.food = new_food

	# ── Step 4: Calculate building progress ──
	var build_progress: int = 0
	var building_completed: String = ""
	if gs.active_building != "" and gs.workers_on_build >= gs.MIN_BUILDERS:
		build_progress = gs.workers_on_build * gs.BUILD_PER_WORKER
		gs.active_building_progress += build_progress
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		var required: int = bdef.get("build_points_required", 999)
		if gs.active_building_progress >= required:
			building_completed = gs.active_building
			gs.buildings_completed.append(gs.active_building)
			_apply_building_completion(gs, gs.active_building)
			gs.active_building = ""
			gs.active_building_progress = 0
	summary["build_progress"] = build_progress
	summary["building_completed"] = building_completed
	gs.last_build_progress = build_progress
	gs.last_building_completed = building_completed

	# ── Step 5: Calculate fire change ──
	var decay: float = gs.fire_decay_rate
	if gs.has_building("tzohar_shelter"):
		decay -= gs.FIRE_TZOHAR_SHELTER_REDUCTION
	decay = max(0.0, decay)

	var fire_gain: float = gs.FIRE_PER_TENDER * pow(maxf(gs.workers_on_tend, 0), 0.85)
	var fire_delta: float = -decay + fire_gain + sacrifice_fire_bonus

	# Bleeding penalty (post-tent, no covering done)
	if gs.bleeding_active:
		fire_delta -= gs.FIRE_BLEEDING_PENALTY

	summary["fire_decay"] = decay
	summary["fire_gain"] = fire_gain
	summary["sacrifice_fire"] = sacrifice_fire_bonus
	summary["bleeding_penalty"] = gs.FIRE_BLEEDING_PENALTY if gs.bleeding_active else 0.0
	summary["fire_delta"] = fire_delta

	# ── Step 6: Update Living Fire ──
	var fire_before: float = gs.living_fire
	gs.living_fire = clampf(gs.living_fire + fire_delta, 0.0, 100.0)
	summary["fire_before"] = fire_before
	summary["fire_after"] = gs.living_fire
	gs.last_fire_delta = fire_delta

	# ── Step 7: Update livestock ──
	var livestock_before: int = gs.livestock
	gs.livestock -= sacrifice_livestock_cost
	if gs.has_building("animal_pens"):
		gs.livestock += 1
		summary["livestock_bred"] = 1
	else:
		summary["livestock_bred"] = 0
	gs.livestock = max(0, gs.livestock)
	summary["livestock_before"] = livestock_before
	summary["livestock_after"] = gs.livestock
	summary["sacrifice"] = gs.chosen_sacrifice
	summary["sacrifice_livestock_cost"] = sacrifice_livestock_cost
	summary["sacrifice_food_cost"] = sacrifice_food_cost

	# ── Step 7b: Teaching — strengthen weakest pillar ──
	var teach_pillar_gain: float = 0.0
	var teach_pillar_idx: int = -1
	if gs.workers_on_teach > 0:
		teach_pillar_gain = pow(maxf(gs.workers_on_teach, 0), 0.85) * 0.15
		# Find weakest pillar
		teach_pillar_idx = 0
		var lowest_val: float = gs.pillars[0]
		for i in range(1, gs.pillars.size()):
			if gs.pillars[i] < lowest_val:
				lowest_val = gs.pillars[i]
				teach_pillar_idx = i
		gs.pillars[teach_pillar_idx] = minf(gs.pillars[teach_pillar_idx] + teach_pillar_gain, 10.0)
	summary["teach_pillar_idx"] = teach_pillar_idx
	summary["teach_pillar_gain"] = teach_pillar_gain
	# Pillar decay when no one teaches (starting Year 1)
	if gs.workers_on_teach == 0 and gs.year > 0:
		var decay_rate: float = 0.1
		for i in range(gs.pillars.size()):
			gs.pillars[i] = maxf(gs.pillars[i] - decay_rate, 0.0)

	# ── Step 7c: Population growth (Autumn each year, starting Year 1) ──
	var births: int = 0
	if gs.season_idx == 0 and gs.year > 0:
		var clans := ["bnei_brit_shem", "bnei_brit_ham", "bnei_brit_yephet"]
		var birth_chance: float = 0.5 if gs.provision >= 30 else 0.25
		for clan in clans:
			var clan_size: int = gs.get(clan)
			if clan_size >= 2 and randf() < birth_chance:
				gs.set(clan, clan_size + 1)
				births += 1
	summary["births"] = births

	# Store for display
	gs.last_food_produced = food_produced
	gs.last_food_consumed = food_consumed

	# ── Step 8: Check game over conditions ──
	if gs.living_fire <= 0:
		gs.game_over = true
		gs.game_over_reason = "The chain is broken. The flame goes out."
	if gs.food <= 0:
		gs.flags["famine_turns"] = gs.flags.get("famine_turns", 0) + 1
		if gs.flags.get("famine_turns", 0) >= 2:
			gs.game_over = true
			gs.game_over_reason = "Famine. The people scatter."
	else:
		gs.flags["famine_turns"] = 0

	summary["game_over"] = gs.game_over
	summary["game_over_reason"] = gs.game_over_reason

	# ── Step 9: Narrative events for new season handled by main.gd ──
	# ── Step 10: Display handled by allocation screen ──

	gs.state_changed.emit()
	resolution_complete.emit(summary)
	return summary


func _apply_building_completion(gs: Node, building_id: String) -> void:
	## Apply the permanent effect of a completed building.
	match building_id:
		"animal_pens":
			pass  # livestock +1/season handled in step 7
		"granary":
			gs.food_cap = gs.FOOD_CAP_GRANARY
		"tzohar_shelter":
			pass  # fire decay reduction handled in step 5
		"warming_shelter":
			pass  # winter penalty removal handled in step 2
	pass  # Effect applied above


func forecast(gs_ref: Node, work: int, build: int, tend: int, sacrifice_id: String) -> Dictionary:
	## Returns a preview of what would happen with given allocation.
	## Does NOT modify GameState.
	var gs := gs_ref
	var result := {}

	var food_rate: int = gs.FOOD_PER_WORKER
	if gs.season_idx == 2:
		food_rate = gs.FOOD_PER_WORKER_SPRING
	var food_produced: int = int(food_rate * pow(maxf(work, 0), 0.9))

	var pop: int = gs.total_bnei_brit
	var food_consumed: int = pop * gs.FOOD_PER_PERSON
	if gs.season_idx == 1 and not gs.has_building("warming_shelter"):
		food_consumed += gs.WINTER_FOOD_PENALTY

	var sac_food_cost: int = 0
	var sac_food_return: int = 0
	var sac_fire_bonus: float = 0.0
	var sac_livestock_cost: int = 0
	if sacrifice_id != "":
		var sdef: Dictionary = gs.SACRIFICE_DEFS.get(sacrifice_id, {})
		sac_food_cost = sdef.get("food_cost", 0)
		sac_livestock_cost = sdef.get("livestock_cost", 0)
		sac_fire_bonus = sdef.get("fire_bonus", 0.0)
		sac_food_return = sdef.get("food_return", 0)

	result["food_forecast"] = clampi(gs.food + food_produced - food_consumed - sac_food_cost + sac_food_return, 0, gs.food_cap)
	result["food_produced"] = food_produced
	result["food_consumed"] = food_consumed

	var decay: float = gs.fire_decay_rate
	if gs.has_building("tzohar_shelter"):
		decay -= gs.FIRE_TZOHAR_SHELTER_REDUCTION
	decay = max(0.0, decay)
	var fire_gain: float = gs.FIRE_PER_TENDER * pow(maxf(tend, 0), 0.85)
	var will_cure_bleed: bool = sacrifice_id == "chatat" and gs.bleeding_active
	var bleed: float = gs.FIRE_BLEEDING_PENALTY if (gs.bleeding_active and not will_cure_bleed) else 0.0
	var fire_delta: float = -decay + fire_gain + sac_fire_bonus - bleed
	result["fire_forecast"] = clampf(gs.living_fire + fire_delta, 0.0, 100.0)
	result["fire_delta"] = fire_delta

	var bp: int = 0
	if gs.active_building != "" and build >= gs.MIN_BUILDERS:
		bp = build * gs.BUILD_PER_WORKER
	result["build_progress"] = bp
	result["build_will_complete"] = false
	if gs.active_building != "":
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		result["build_will_complete"] = (gs.active_building_progress + bp) >= bdef.get("build_points_required", 999)

	result["livestock_forecast"] = max(0, gs.livestock - sac_livestock_cost + (1 if gs.has_building("animal_pens") else 0))

	return result
