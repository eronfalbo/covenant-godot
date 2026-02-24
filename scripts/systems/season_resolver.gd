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

	# ── Pillar reward flags (computed once, used across steps) ──
	var pillar_rewards: Array[String] = []
	var pr_festival_food: bool = gs.pillars[4] >= gs.PILLAR_REWARD_THRESHOLD  # Festival Calendar: +1 food
	var pr_sacred_build: bool = gs.pillars[5] >= gs.PILLAR_REWARD_THRESHOLD   # Sacred Objects: +1 build
	var pr_star_fire: bool = gs.pillars[0] >= gs.PILLAR_REWARD_THRESHOLD      # Star Watch: +0.5 fire
	var pr_sacr_order: bool = gs.pillars[2] >= gs.PILLAR_REWARD_THRESHOLD     # Sacrificial Order: +1 sac fire
	var pr_altar_road: bool = gs.pillars[1] >= gs.PILLAR_REWARD_THRESHOLD     # Altar Road: sac food cost -1
	var pr_holy_tongue: bool = gs.pillars[3] >= gs.PILLAR_REWARD_THRESHOLD    # Holy Tongue: teach +25%
	var pr_teach_net: bool = gs.pillars[6] >= gs.PILLAR_REWARD_THRESHOLD      # Teaching Network: decay -0.1
	var pr_stories: bool = gs.pillars[7] >= gs.PILLAR_REWARD_THRESHOLD        # Stories: +2 ham_relation/yr

	# ── Step 0b: Compute workers from percentages ──
	gs.compute_workers_from_pct()

	# ── Step 1: Calculate food produced (from gatherers) ──
	var food_rate: int = gs.FOOD_PER_GATHERER
	if gs.season_idx == 2:  # Spring
		food_rate = gs.FOOD_PER_GATHERER_SPRING
	if gs.has_building("tent_tubal_cain"):
		food_rate += 1
	if gs.has_building("tent_cain"):
		food_rate += 1
	var food_from_gather: int = int(food_rate * pow(maxf(gs.workers_on_gather, 0), 0.9))

	# Tending food: each tender produces food from livestock (milking, shearing)
	# Effective tenders capped by livestock available (need LIVESTOCK_PER_TENDER head per tender)
	var effective_tenders: int = mini(gs.workers_on_tend, gs.livestock / gs.LIVESTOCK_PER_TENDER)
	var food_from_tend: int = effective_tenders * gs.FOOD_PER_TENDER

	var food_produced: int = food_from_gather + food_from_tend
	if pr_festival_food:
		food_produced += 1
		pillar_rewards.append("Festival Calendar: +1 food")
	# Ham's agricultural knowledge leaves with his people
	var ham_food_penalty: int = 0
	if gs.ham_centralisation >= 60:
		ham_food_penalty = 3
	elif gs.ham_centralisation >= 40:
		ham_food_penalty = 2
	elif gs.ham_centralisation >= 20:
		ham_food_penalty = 1
	food_produced = maxi(food_produced - ham_food_penalty, 0)
	summary["ham_food_penalty"] = ham_food_penalty
	# ── Step 1b: Seasonal weather (random, not in forecast) ──
	var weather_event: String = ""
	var weather_food_mod: int = 0
	var weather_fire_mod: float = 0.0
	var weather_livestock_mod: int = 0
	match gs.season_idx:
		1:  # Winter — 20% harsh winter
			if randf() < 0.20:
				weather_event = "Harsh winter — the cold bites deeper than expected."
				weather_food_mod = -1
				weather_fire_mod = -2.0
		3:  # Summer — 15% heat wave
			if randf() < 0.15:
				weather_event = "A heat wave scorches the hillside. Livestock suffer."
				weather_livestock_mod = -1
		2:  # Spring — 10% abundant rain
			if randf() < 0.10:
				weather_event = "Abundant rains! The earth yields generously."
				weather_food_mod = 2
		0:  # Autumn — 15% early frost
			if randf() < 0.15:
				weather_event = "An early frost catches the harvest short."
				weather_food_mod = -2
	food_produced += weather_food_mod
	food_produced = maxi(food_produced, 0)
	summary["weather_event"] = weather_event
	summary["weather_food_mod"] = weather_food_mod
	summary["weather_fire_mod"] = weather_fire_mod
	summary["weather_livestock_mod"] = weather_livestock_mod

	summary["food_produced"] = food_produced
	summary["food_from_gather"] = food_from_gather
	summary["food_from_work"] = food_from_gather  # Legacy alias
	summary["food_from_tend"] = food_from_tend

	# ── Step 1c: Provisions production (from workers) ──
	var prov_rate: int = gs.PROVISION_PER_WORKER
	if gs.has_building("tent_tubal_cain"):
		prov_rate += 1
	var prov_produced: int = int(prov_rate * pow(maxf(gs.workers_on_work, 0), 0.9))
	# Tent of Eve bonus: +1 provision/season
	if gs.has_building("tent_eve"):
		prov_produced += 1
	var prov_before: int = gs.provision
	gs.provision = mini(gs.provision + prov_produced, gs.provision_cap)
	summary["prov_produced"] = prov_produced
	summary["prov_before"] = prov_before

	# ── Step 2: Calculate food consumed (with population pressure) ──
	var pop: int = gs.total_bnei_brit
	var food_per_person: float = gs.FOOD_PER_PERSON
	if pop >= 19:
		food_per_person = 1.5
	elif pop >= 15:
		food_per_person = 1.25
	var food_consumed: int = int(ceil(pop * food_per_person))
	if gs.season_idx == 1:  # Winter penalty
		if not gs.has_building("tent_eve"):
			food_consumed += gs.WINTER_FOOD_PENALTY
	summary["food_consumed"] = food_consumed
	summary["pop_pressure"] = food_per_person

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
		# Pillar: Altar Road reduces sacrifice food cost
		if pr_altar_road and sacrifice_food_cost > 0:
			sacrifice_food_cost = maxi(sacrifice_food_cost - 1, 0)
			pillar_rewards.append("Altar Road: sacrifice cost -1")
		# Pillar: Sacrificial Order adds +1 fire to sacrifices
		if pr_sacr_order:
			sacrifice_fire_bonus += 1.0
			pillar_rewards.append("Sacrificial Order: +1 sacrifice fire")
		# Stone Altar: +50% sacrifice fire bonus
		if gs.has_building("tent_abel"):
			sacrifice_fire_bonus *= 1.5

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
	var build_prov_cost: int = 0
	if gs.active_building != "" and gs.workers_on_build >= gs.MIN_BUILDERS:
		# Building consumes provisions each season
		if gs.provision >= gs.BUILD_PROVISION_COST:
			build_prov_cost = gs.BUILD_PROVISION_COST
			gs.provision -= build_prov_cost
			build_progress = gs.workers_on_build * gs.BUILD_PER_WORKER
			if pr_sacred_build:
				build_progress += 1
				pillar_rewards.append("Sacred Objects: +1 build point")
			gs.active_building_progress += build_progress
			var bdef: Dictionary = gs.TENT_DEFS.get(gs.active_building, {})
			var required: int = bdef.get("build_points_required", 999)
			if gs.active_building_progress >= required:
				building_completed = gs.active_building
				gs.buildings_completed.append(gs.active_building)
				_apply_building_completion(gs, gs.active_building)
				gs.active_building = ""
				gs.active_building_progress = 0
	summary["build_progress"] = build_progress
	summary["build_prov_cost"] = build_prov_cost
	summary["building_completed"] = building_completed
	summary["prov_after"] = gs.provision
	gs.last_build_progress = build_progress
	gs.last_building_completed = building_completed

	# ── Step 5: Calculate fire change ──
	# Chain decay: -5/yr = -1.25/season pre-tent, -8/yr = -2.0/season post-tent
	var chain_decay: float = 1.5 if gs.tent_scene_occurred else 1.25
	# Noah+Shem anchor: +3/yr = +0.75/season during ararat phase
	var anchor: float = 0.75 if gs.phase == "ararat" else 0.0
	# Pillar drag: (avg_pillar - 5.0) * 1.5 / 4 per season
	var avg_pillar: float = 0.0
	for p in gs.pillars:
		avg_pillar += p
	avg_pillar /= gs.pillars.size()
	var pillar_drag: float = (avg_pillar - 5.0) * 1.5 / 4.0

	# Tzohar shrine reduces decay
	if gs.has_building("tzohar_shrine"):
		chain_decay -= gs.FIRE_TZOHAR_SHELTER_REDUCTION
	# Tent of Jubal: additional fire decay reduction
	if gs.has_building("tent_jubal"):
		chain_decay -= 1.0
	chain_decay = max(0.0, chain_decay)

	var fire_gain: float = gs.FIRE_PER_TENDER * pow(maxf(gs.workers_on_tend, 0), 0.85)
	var pillar_fire_bonus: float = 0.0
	if pr_star_fire:
		pillar_fire_bonus += 0.5
		pillar_rewards.append("Star Watch: +0.5% fire")
	var fire_delta: float = -chain_decay + anchor + pillar_drag + fire_gain + sacrifice_fire_bonus + pillar_fire_bonus + weather_fire_mod

	# Bleeding penalty (post-tent, no covering done)
	if gs.bleeding_active:
		fire_delta -= gs.FIRE_BLEEDING_PENALTY

	summary["fire_decay"] = chain_decay
	summary["fire_anchor"] = anchor
	summary["pillar_drag"] = pillar_drag
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
	gs.livestock += weather_livestock_mod  # weather may kill livestock
	if gs.has_building("tent_jabal"):
		gs.livestock += 2
		summary["livestock_bred"] = 2
	else:
		summary["livestock_bred"] = 0
	var livestock_cap: int = gs.LIVESTOCK_CAP_PENS if gs.has_building("tent_jabal") else gs.LIVESTOCK_CAP_BASE
	gs.livestock = clampi(gs.livestock, 0, livestock_cap)
	summary["livestock_before"] = livestock_before
	summary["livestock_after"] = gs.livestock
	summary["livestock_cap"] = livestock_cap
	summary["sacrifice"] = gs.chosen_sacrifice
	summary["sacrifice_livestock_cost"] = sacrifice_livestock_cost
	summary["sacrifice_food_cost"] = sacrifice_food_cost

	# ── Step 7b: Teaching — strengthen weakest pillar ──
	var teach_pillar_gain: float = 0.0
	var teach_pillar_idx: int = -1
	if gs.workers_on_teach > 0:
		var teach_multiplier: float = 1.0
		if pr_holy_tongue:
			teach_multiplier += 0.25
			pillar_rewards.append("Holy Tongue: +25% teaching")
		if gs.has_building("tent_jubal"):
			teach_multiplier += 0.25
		if gs.has_building("tent_chanoch"):
			teach_multiplier += 0.50
		teach_pillar_gain = pow(maxf(gs.workers_on_teach, 0), 0.85) * 0.15 * teach_multiplier
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
		var decay_rate: float = 0.35 if gs.year >= 3 else 0.25
		if pr_teach_net:
			decay_rate -= 0.1
			pillar_rewards.append("Teaching Network: -0.1 pillar decay")
		for i in range(gs.pillars.size()):
			gs.pillars[i] = maxf(gs.pillars[i] - decay_rate, 0.0)

	# ── Step 7b-ii: Pillar cascade ──
	# Teaching Network (idx 6) < 3 → Sacrificial Order (idx 2) -0.3
	if gs.pillars[6] < 3.0:
		gs.pillars[2] = maxf(gs.pillars[2] - 0.3, 0.0)
	# Sacrificial Order (idx 2) < 3 → Festival Calendar (idx 4) -0.3
	if gs.pillars[2] < 3.0:
		gs.pillars[4] = maxf(gs.pillars[4] - 0.3, 0.0)
	# Holy Tongue (idx 3) < 3 → Stories (idx 7) -0.3
	if gs.pillars[3] < 3.0:
		gs.pillars[7] = maxf(gs.pillars[7] - 0.3, 0.0)
	# Stories (idx 7) < 3 → Sacrificial Order (idx 2) -0.3
	if gs.pillars[7] < 3.0:
		gs.pillars[2] = maxf(gs.pillars[2] - 0.3, 0.0)

	# ── Step 7c-i: Yearly faction updates (once per year, Autumn = season 0) ──
	if gs.season_idx == 0 and gs.year > 0:
		# Pillar: Stories improves ham relations
		if pr_stories:
			gs.ham_relation = mini(gs.ham_relation + 2, 100)
			pillar_rewards.append("Stories: +2 ham relation")
		# Ham centralisation natural drift: +2/yr (accelerates if neglected)
		var ham_drift: int = 2
		if gs.ham_relation < 60:
			ham_drift += 1  # neglect accelerates drift
		if gs.has_building("tent_japheth"):
			ham_drift -= 1
		ham_drift = maxi(ham_drift, 0)
		gs.ham_centralisation += ham_drift
		# Ham gentle drift: if active, +1 centralisation and decrement counter
		if gs.ham_gentle_drift > 0:
			gs.ham_centralisation += 1
			gs.ham_gentle_drift -= 1
		# Japheth loyalty tied to pillar health ("dwell in tents of Shem")
		var avg_p: float = 0.0
		for p in gs.pillars:
			avg_p += p
		avg_p /= gs.pillars.size()
		if avg_p >= 6.0:
			gs.yephet_loyalty = mini(gs.yephet_loyalty + 2, 100)
		elif avg_p < 3.0:
			gs.yephet_loyalty = maxi(gs.yephet_loyalty - 5, 0)
		elif avg_p < 5.0:
			gs.yephet_loyalty = maxi(gs.yephet_loyalty - 3, 0)
		# Ham's city pulls at Japheth
		if gs.ham_centralisation >= 60:
			gs.yephet_loyalty = maxi(gs.yephet_loyalty - 4, 0)
		elif gs.ham_centralisation >= 40:
			gs.yephet_loyalty = maxi(gs.yephet_loyalty - 2, 0)
	summary["ham_centralisation"] = gs.ham_centralisation
	summary["yephet_loyalty"] = gs.yephet_loyalty

	# ── Step 7c-ii: Population growth (Autumn each year, starting Year 1) ──
	# Percentage-based: Shem 5%, Ham 7%, Japheth 5.5% (reduced if wavering)
	var births: int = 0
	if gs.season_idx == 0 and gs.year > 0:
		var yephet_rate: float = 0.055
		if gs.yephet_loyalty < 40:
			yephet_rate = 0.0
		elif gs.yephet_loyalty < 60:
			yephet_rate = 0.0275
		var clan_rates := {
			"bnei_brit_shem": 0.05,
			"bnei_brit_ham": 0.07,
			"bnei_brit_yephet": yephet_rate,
		}
		for clan in clan_rates:
			var clan_size: int = gs.get(clan)
			var growth: float = clan_size * clan_rates[clan]
			# Fractional growth: guaranteed floor + chance for +1
			var guaranteed: int = int(growth)
			var remainder: float = growth - guaranteed
			var actual: int = guaranteed + (1 if randf() < remainder else 0)
			if actual > 0:
				gs.set(clan, clan_size + actual)
				births += actual
	summary["births"] = births

	# Store for display
	summary["pillar_rewards"] = pillar_rewards
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
	# Baal Cycle: game over at stage 5 (ham_centralisation >= 80)
	if gs.ham_centralisation >= 80:
		gs.game_over = true
		gs.game_over_reason = "A temple rises in the valley. The city is complete. The covenant is forgotten."

	# ── Victory condition: Salem project complete ──
	if gs.flags.get("salem_project", false) and not gs.game_over:
		if (gs.food >= gs.SALEM_FOOD_TARGET
			and gs.livestock >= gs.SALEM_LIVESTOCK_TARGET
			and gs.total_population >= gs.SALEM_POP_TARGET
			and gs.bc_count >= gs.SALEM_BC_TARGET):
			gs.victory = true
			gs.game_over = true
			gs.game_over_reason = "Salem stands. The covenant endures. The chain is unbroken."

	summary["game_over"] = gs.game_over
	summary["game_over_reason"] = gs.game_over_reason
	summary["victory"] = gs.victory

	# ── Step 9: Narrative events for new season handled by main.gd ──
	# ── Step 10: Display handled by allocation screen ──

	gs.state_changed.emit()
	resolution_complete.emit(summary)
	return summary


func _apply_building_completion(gs: Node, building_id: String) -> void:
	## Apply the permanent effect of a completed tent/building.
	match building_id:
		"tent_abel":
			pass  # sacrifice +50% handled in step 3
		"tent_jabal":
			pass  # livestock +2/season handled in step 7, cap in step 7
		"tent_eve":
			pass  # winter penalty removal in step 2, +1 prov in step 1c
		"tzohar_shrine":
			pass  # fire decay reduction handled in step 5
		"tent_naamah":
			pass  # crisis -20% handled by event system
		"tent_tubal_cain":
			pass  # +1 food/gatherer in step 1, +1 prov/worker in step 1c
		"tent_japheth":
			pass  # ham drift handled in step 7c
		"tent_jubal":
			pass  # fire decay -1 in step 5, teaching +25% in step 7b
		"tent_chanoch":
			pass  # teaching +50% handled in step 7b
		"tent_cain":
			gs.food_cap = gs.FOOD_CAP_GRANARY  # +8 food cap


func forecast(gs_ref: Node, pct: Dictionary, sacrifice_id: String) -> Dictionary:
	## Returns a preview of what would happen with given percentage allocation.
	## Does NOT modify GameState.
	var gs := gs_ref
	var result := {}

	# Compute integer workers from percentages
	var available: int = gs.effective_allocatable
	var workers := {}
	var total_assigned: int = 0
	for slot in pct:
		var count: int = int(round(pct[slot] * available))
		workers[slot] = count
		total_assigned += count
	if total_assigned != available:
		var diff: int = available - total_assigned
		var largest_slot: String = "gather"
		for slot in workers:
			if workers[slot] > workers.get(largest_slot, 0):
				largest_slot = slot
		workers[largest_slot] += diff
	var gather: int = workers.get("gather", 0)
	var work: int = workers.get("work", 0)
	var build: int = workers.get("build", 0)
	var tend: int = workers.get("tend", 0)

	# Pillar reward flags for forecast
	var f_pr_festival: bool = gs.pillars[4] >= gs.PILLAR_REWARD_THRESHOLD
	var f_pr_sacred: bool = gs.pillars[5] >= gs.PILLAR_REWARD_THRESHOLD
	var f_pr_star: bool = gs.pillars[0] >= gs.PILLAR_REWARD_THRESHOLD
	var f_pr_sacr_order: bool = gs.pillars[2] >= gs.PILLAR_REWARD_THRESHOLD
	var f_pr_altar_road: bool = gs.pillars[1] >= gs.PILLAR_REWARD_THRESHOLD

	var food_rate: int = gs.FOOD_PER_GATHERER
	if gs.season_idx == 2:
		food_rate = gs.FOOD_PER_GATHERER_SPRING
	if gs.has_building("tent_tubal_cain"):
		food_rate += 1
	if gs.has_building("tent_cain"):
		food_rate += 1
	var food_from_gather: int = int(food_rate * pow(maxf(gather, 0), 0.9))

	# Tending food forecast
	var f_effective_tenders: int = mini(tend, gs.livestock / gs.LIVESTOCK_PER_TENDER)
	var food_from_tend: int = f_effective_tenders * gs.FOOD_PER_TENDER

	var food_produced: int = food_from_gather + food_from_tend
	if f_pr_festival:
		food_produced += 1
	# Ham food penalty in forecast
	var f_ham_penalty: int = 0
	if gs.ham_centralisation >= 60:
		f_ham_penalty = 3
	elif gs.ham_centralisation >= 40:
		f_ham_penalty = 2
	elif gs.ham_centralisation >= 20:
		f_ham_penalty = 1
	food_produced = maxi(food_produced - f_ham_penalty, 0)

	var pop: int = gs.total_bnei_brit
	var f_food_per_person: float = gs.FOOD_PER_PERSON
	if pop >= 19:
		f_food_per_person = 1.5
	elif pop >= 15:
		f_food_per_person = 1.25
	var food_consumed: int = int(ceil(pop * f_food_per_person))
	if gs.season_idx == 1 and not gs.has_building("tent_eve"):
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
		if f_pr_altar_road and sac_food_cost > 0:
			sac_food_cost = maxi(sac_food_cost - 1, 0)
		if f_pr_sacr_order:
			sac_fire_bonus += 1.0
		if gs.has_building("tent_abel"):
			sac_fire_bonus *= 1.5

	result["food_forecast"] = clampi(gs.food + food_produced - food_consumed - sac_food_cost + sac_food_return, 0, gs.food_cap)
	result["food_produced"] = food_produced
	result["food_from_gather"] = food_from_gather
	result["food_from_work"] = food_from_gather  # Legacy alias
	result["food_from_tend"] = food_from_tend
	result["food_consumed"] = food_consumed

	# Provisions forecast
	var f_prov_rate: int = gs.PROVISION_PER_WORKER
	if gs.has_building("tent_tubal_cain"):
		f_prov_rate += 1
	var f_prov_produced: int = int(f_prov_rate * pow(maxf(work, 0), 0.9))
	if gs.has_building("tent_eve"):
		f_prov_produced += 1
	var f_build_prov_cost: int = 0
	if gs.active_building != "" and build >= gs.MIN_BUILDERS and gs.provision >= gs.BUILD_PROVISION_COST:
		f_build_prov_cost = gs.BUILD_PROVISION_COST
	result["prov_forecast"] = mini(gs.provision + f_prov_produced - f_build_prov_cost, gs.provision_cap)
	result["prov_produced"] = f_prov_produced

	# Chain decay: post-tent increases
	var f_decay: float = 1.5 if gs.tent_scene_occurred else 1.25
	var f_anchor: float = 0.75 if gs.phase == "ararat" else 0.0
	var f_avg_pillar: float = 0.0
	for p in gs.pillars:
		f_avg_pillar += p
	f_avg_pillar /= gs.pillars.size()
	var f_pillar_drag: float = (f_avg_pillar - 5.0) * 1.5 / 4.0
	if gs.has_building("tzohar_shrine"):
		f_decay -= gs.FIRE_TZOHAR_SHELTER_REDUCTION
	if gs.has_building("tent_jubal"):
		f_decay -= 1.0
	f_decay = max(0.0, f_decay)
	var fire_gain: float = gs.FIRE_PER_TENDER * pow(maxf(tend, 0), 0.85)
	var f_pillar_fire: float = 0.5 if f_pr_star else 0.0
	var will_cure_bleed: bool = sacrifice_id == "chatat" and gs.bleeding_active
	var bleed: float = gs.FIRE_BLEEDING_PENALTY if (gs.bleeding_active and not will_cure_bleed) else 0.0
	var fire_delta: float = -f_decay + f_anchor + f_pillar_drag + fire_gain + sac_fire_bonus + f_pillar_fire - bleed
	result["fire_forecast"] = clampf(gs.living_fire + fire_delta, 0.0, 100.0)
	result["fire_delta"] = fire_delta

	var bp: int = 0
	if gs.active_building != "" and build >= gs.MIN_BUILDERS:
		if gs.provision >= gs.BUILD_PROVISION_COST:
			bp = build * gs.BUILD_PER_WORKER
			if f_pr_sacred:
				bp += 1
	result["build_progress"] = bp
	result["build_will_complete"] = false
	if gs.active_building != "":
		var bdef: Dictionary = gs.TENT_DEFS.get(gs.active_building, {})
		result["build_will_complete"] = (gs.active_building_progress + bp) >= bdef.get("build_points_required", 999)

	var f_livestock_cap: int = gs.LIVESTOCK_CAP_PENS if gs.has_building("tent_jabal") else gs.LIVESTOCK_CAP_BASE
	result["livestock_forecast"] = clampi(gs.livestock - sac_livestock_cost + (2 if gs.has_building("tent_jabal") else 0), 0, f_livestock_cap)

	# Worker counts for display
	result["workers"] = workers

	return result
