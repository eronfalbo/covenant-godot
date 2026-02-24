extends Node
## Autoplay test — Runs the game loop N times headlessly.
## Registered as autoload. Run: godot --headless

const MAX_RUNS := 10
var _runs := 0
var _errors: Array[String] = []


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		return

	# Wait for autoloads to be ready
	await get_tree().process_frame

	print("[AUTO] Autoplay: %d runs, Years 0-7 each" % MAX_RUNS)
	print("[AUTO] Godot %s" % Engine.get_version_info().string)
	print("")
	_start_run()


func _start_run() -> void:
	_runs += 1
	print("[AUTO] ===== RUN %d / %d =====" % [_runs, MAX_RUNS])

	GameState.reset()
	GameState.phase = "ararat"
	GameState.year = 0
	GameState.season_idx = 0

	_run_season()


func _run_season() -> void:
	if GameState.game_over:
		print("[AUTO] GAME OVER Y%d S%d: %s" % [GameState.year, GameState.season_idx, GameState.game_over_reason])
		_errors.append("Run %d: GAME OVER at Y%d S%d — %s" % [_runs, GameState.year, GameState.season_idx, GameState.game_over_reason])
		_finish_run()
		return

	if GameState.year >= 8:
		print("[AUTO] Year 8 reached — success!")
		_finish_run()
		return

	var season_name: String = GameState.current_season
	_fire_all_events()

	# Smart allocation: food-first, then build/tend/teach as affordable
	var gs := GameState
	var available: int = gs.effective_allocatable
	var builders: int = 0
	var tenders: int = 0
	var teachers: int = 0

	# Pick a building if none active (granary first for food cap)
	if gs.active_building == "":
		var build_order := ["granary", "warming_shelter", "animal_pens", "tzohar_shelter"]
		for bid in build_order:
			if bid not in gs.buildings_completed:
				gs.active_building = bid
				gs.active_building_progress = 0
				break

	# Only build when food is stable (>= 10) and enough workers
	if gs.active_building != "" and gs.food >= 10 and available >= gs.MIN_BUILDERS + 4:
		builders = gs.MIN_BUILDERS

	var remaining: int = available - builders

	# Assign teachers from Year 2+ (pillar decay is real now)
	if gs.year >= 2 and remaining > 4:
		teachers = mini(1, remaining - 4)
		remaining -= teachers

	# Assign tenders conservatively — max 2, only when food is OK
	var max_effective_tenders: int = gs.livestock / gs.LIVESTOCK_PER_TENDER
	if max_effective_tenders > 0 and remaining > 3 and gs.food >= 5:
		tenders = mini(mini(max_effective_tenders, 2), remaining - 3)  # cap at 2, keep 3 on work

	gs.workers_on_build = builders
	gs.workers_on_tend = tenders
	gs.workers_on_teach = teachers
	gs.workers_on_work = available - builders - tenders - teachers

	# Sacrifice when fire is low
	gs.chosen_sacrifice = ""
	if gs.living_fire < 60 and gs.livestock >= 2:
		gs.chosen_sacrifice = "olah"  # +8 fire, costs 1 livestock
	elif gs.living_fire < 45 and gs.food >= 4:
		gs.chosen_sacrifice = "mincha"  # +3 fire, costs 2 food

	# Resolve
	var summary: Dictionary = SeasonResolver.resolve_season()

	var bld_info := ""
	if GameState.last_building_completed != "":
		bld_info = " BUILT:%s" % GameState.last_building_completed
	elif GameState.active_building != "":
		bld_info = " bld:%s(%d)" % [GameState.active_building, GameState.active_building_progress]
	var sac_info := ""
	if GameState.chosen_sacrifice != "":
		sac_info = " sac:%s" % GameState.chosen_sacrifice
	print("[AUTO] Y%d %s: Fire=%.0f%% Food=%d/%d Pop=%d Lvstk=%d W=%d B=%d T=%d Tch=%d%s%s" % [
		GameState.year, season_name, GameState.living_fire, GameState.food, GameState.food_cap,
		GameState.total_population, GameState.livestock,
		GameState.workers_on_work, GameState.workers_on_build, GameState.workers_on_tend,
		GameState.workers_on_teach, bld_info, sac_info
	])

	if GameState.game_over:
		print("[AUTO] GAME OVER after resolve: %s" % GameState.game_over_reason)
		_errors.append("Run %d: GAME OVER Y%d S%d — %s" % [_runs, GameState.year, GameState.season_idx, GameState.game_over_reason])
		_finish_run()
		return

	# Advance
	GameState.season_idx += 1
	if GameState.season_idx >= 4:
		GameState.season_idx = 0
		GameState.year += 1
		GameState.reset_yearly_accumulators()

	if GameState.living_fire <= 0:
		GameState.game_over = true
		GameState.game_over_reason = "The chain is broken. The flame goes out."

	GameState.state_changed.emit()

	_run_season.call_deferred()


func _fire_all_events() -> void:
	if GameState.year == 0 and GameState.phase == "ararat":
		var safety := 0
		while safety < 25:
			safety += 1
			var fresh: Array[Dictionary] = EventManager.get_valid_events()
			var ararat: Array[Dictionary] = []
			for e in fresh:
				if e["id"].begins_with("A"):
					ararat.append(e)
			if ararat.is_empty():
				break
			_fire_single(ararat[0])
		return

	var valid: Array[Dictionary] = EventManager.get_valid_events()
	var harddate: Array[Dictionary] = []
	var mandatory: Array[Dictionary] = []
	var random_evts: Array[Dictionary] = []

	for ev in valid:
		var id: String = ev["id"]
		if id.begins_with("H"): harddate.append(ev)
		elif id.begins_with("M") or id.begins_with("BC"): mandatory.append(ev)
		elif id.begins_with("R"): random_evts.append(ev)

	var pick: Dictionary = {}
	if not harddate.is_empty():
		pick = harddate[0]
	elif not mandatory.is_empty():
		pick = mandatory[0]
	elif not random_evts.is_empty():
		random_evts.shuffle()
		pick = random_evts[0]

	if not pick.is_empty():
		_fire_single(pick)


func _fire_single(ev: Dictionary) -> void:
	var choices: Array = ev.get("choices", [])
	if not choices.is_empty():
		var effects: Array = choices[0].get("effects", [])
		EffectResolver.apply_effects(effects, GameState)

	if ev.get("frequency", "once") == "once":
		GameState.events_fired.append(ev["id"])
	GameState.event_last_fired[ev["id"]] = GameState.year


func _finish_run() -> void:
	print("[AUTO] Run %d end: Y%d S%d | Fire=%.0f%% Food=%d Pop=%d Ham=%d Central=%d Buildings=%s" % [
		_runs, GameState.year, GameState.season_idx, GameState.living_fire, GameState.food,
		GameState.total_population, GameState.ham_relation, GameState.ham_centralisation,
		str(GameState.buildings_completed)
	])
	print("[AUTO] Events fired: %s" % str(GameState.events_fired))
	print("")

	if _runs < MAX_RUNS:
		_start_run.call_deferred()
	else:
		print("[AUTO] ===== ALL %d RUNS COMPLETE =====" % MAX_RUNS)
		if _errors.is_empty():
			print("[AUTO] NO ERRORS — all runs reached Year 8")
		else:
			print("[AUTO] ERRORS (%d):" % _errors.size())
			for e in _errors:
				print("[AUTO]   %s" % e)
		get_tree().quit(0)
