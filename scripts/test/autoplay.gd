extends Node
## Autoplay test — Runs the game loop with varied strategies headlessly.
## Registered as autoload. Run: godot --headless

const MAX_RUNS := 20
var _runs := 0
var _errors: Array[String] = []
var _notes: Array[String] = []

# Strategy profiles — each run uses a different approach
var _strategies := [
	# 0: Balanced (original)
	{"name": "balanced", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "first"},
	# 1: Gather-heavy — never starve
	{"name": "gather-heavy", "gather": 0.75, "tend": 0.25, "teach": 0.0, "build_when_food": 18, "teach_from_year": 3, "sac_threshold": 50, "choice_style": "first"},
	# 2: Builder rush — tents ASAP
	{"name": "builder-rush", "gather": 0.40, "tend": 0.20, "teach": 0.0, "build_when_food": 8, "teach_from_year": 4, "sac_threshold": 60, "choice_style": "first"},
	# 3: Fire keeper — max tend, frequent sacrifice
	{"name": "fire-keeper", "gather": 0.50, "tend": 0.40, "teach": 0.0, "build_when_food": 15, "teach_from_year": 2, "sac_threshold": 80, "choice_style": "first"},
	# 4: Teacher — start teaching Year 0
	{"name": "early-teacher", "gather": 0.50, "tend": 0.25, "teach": 0.25, "build_when_food": 15, "teach_from_year": 0, "sac_threshold": 60, "choice_style": "first"},
	# 5: Neglect fire — 0 tend, no sacrifice
	{"name": "neglect-fire", "gather": 0.75, "tend": 0.0, "teach": 0.0, "build_when_food": 10, "teach_from_year": 1, "sac_threshold": 999, "choice_style": "first"},
	# 6: Neglect food — 0 gather
	{"name": "neglect-food", "gather": 0.0, "tend": 0.50, "teach": 0.25, "build_when_food": 5, "teach_from_year": 0, "sac_threshold": 60, "choice_style": "first"},
	# 7: All-in teach
	{"name": "all-teach", "gather": 0.25, "tend": 0.25, "teach": 0.50, "build_when_food": 15, "teach_from_year": 0, "sac_threshold": 60, "choice_style": "first"},
	# 8: No building ever
	{"name": "no-build", "gather": 0.60, "tend": 0.25, "teach": 0.15, "build_when_food": 999, "teach_from_year": 1, "sac_threshold": 60, "choice_style": "first"},
	# 9: Always sacrifice olah
	{"name": "sacrifice-heavy", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 100, "choice_style": "first"},
	# 10: Balanced + always pick choice 1
	{"name": "alt-choices-1", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "second"},
	# 11: Balanced + always pick last choice
	{"name": "alt-choices-last", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "last"},
	# 12: Balanced + random choices
	{"name": "random-choices", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "random"},
	# 13: Ham-friendly — severity 1 (silence)
	{"name": "ham-friendly", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "last"},
	# 14: Strict — severity 3 (full binding)
	{"name": "strict-noah", "gather": 0.50, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "first"},
	# 15: Minimal intervention — gather only, no teach, no build
	{"name": "survivalist", "gather": 0.75, "tend": 0.25, "teach": 0.0, "build_when_food": 999, "teach_from_year": 99, "sac_threshold": 999, "choice_style": "first"},
	# 16: Sprint builder — sacrifice everything for tents
	{"name": "sprint-build", "gather": 0.30, "tend": 0.20, "teach": 0.0, "build_when_food": 5, "teach_from_year": 5, "sac_threshold": 50, "choice_style": "first"},
	# 17: Balanced + random again (different seed behavior)
	{"name": "random-2", "gather": 0.45, "tend": 0.30, "teach": 0.0, "build_when_food": 10, "teach_from_year": 1, "sac_threshold": 65, "choice_style": "random"},
	# 18: Max population growth (accept all refugees/wanderers)
	{"name": "growth-focus", "gather": 0.60, "tend": 0.25, "teach": 0.0, "build_when_food": 12, "teach_from_year": 2, "sac_threshold": 60, "choice_style": "first"},
	# 19: Austerity — minimize everything
	{"name": "austerity", "gather": 0.50, "tend": 0.15, "teach": 0.10, "build_when_food": 20, "teach_from_year": 1, "sac_threshold": 40, "choice_style": "second"},
]

var _strat: Dictionary = {}
var _season_log: Array[String] = []  # per-run season log
var _fire_min: float = 100.0
var _food_min: int = 999
var _food_zero_count: int = 0
var _sacrifice_count: int = 0
var _overflow_food_total: int = 0


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		return
	await get_tree().process_frame
	print("[ECON] === ECONOMICS & LOGIC PLAYTHROUGH: %d strategies ===" % MAX_RUNS)
	print("")
	_start_run()


func _start_run() -> void:
	_runs += 1
	_strat = _strategies[(_runs - 1) % _strategies.size()]
	_season_log = []
	_fire_min = 100.0
	_food_min = 999
	_food_zero_count = 0
	_sacrifice_count = 0
	_overflow_food_total = 0

	print("[ECON] ===== RUN %d: %s =====" % [_runs, _strat["name"]])

	GameState.reset()
	GameState.phase = "ararat"
	GameState.year = 0
	GameState.season_idx = 0
	_run_season()


func _run_season() -> void:
	if GameState.game_over:
		print("[ECON] GAME OVER Y%dS%d: %s" % [GameState.year, GameState.season_idx, GameState.game_over_reason])
		_errors.append("Run %d (%s): GAME OVER Y%dS%d — %s" % [_runs, _strat["name"], GameState.year, GameState.season_idx, GameState.game_over_reason])
		_finish_run()
		return

	if GameState.year >= 8:
		_finish_run()
		return

	var gs := GameState
	var season_name: String = gs.current_season
	_fire_all_events()

	# Strategy-based allocation
	var gather_pct: float = _strat["gather"]
	var tend_pct: float = _strat["tend"]
	var teach_pct: float = _strat["teach"] if gs.year >= int(_strat["teach_from_year"]) else 0.0
	var build_pct: float = 0.0
	var work_pct: float = 0.0

	# Pick building
	if gs.active_building == "" and int(_strat["build_when_food"]) < 999:
		var build_order := ["tzohar_shrine", "tent_jabal", "tent_abel", "tent_eve",
			"tent_naamah", "tent_tubal_cain", "tent_japheth", "tent_jubal",
			"tent_chanoch", "tent_cain"]
		var avail: Array[String] = gs.get_available_buildings()
		for bid in build_order:
			if bid in avail:
				var bdef: Dictionary = gs.TENT_DEFS.get(bid, {})
				if gs.provision >= bdef.get("provision_cost", 0):
					gs.start_building(bid)
					break

	# Build allocation
	if gs.active_building != "" and gs.food >= int(_strat["build_when_food"]) and gs.provision >= gs.BUILD_PROVISION_COST:
		build_pct = 0.25
		gather_pct -= 0.125

	# Work allocation
	if gs.provision < 5 and gs.food >= 10:
		work_pct = 0.125
		gather_pct -= 0.0625

	# Emergency food
	if gs.food < 8:
		build_pct = 0.0
		work_pct = 0.0
		teach_pct = minf(teach_pct, 0.1)
		gather_pct = 1.0 - tend_pct - teach_pct

	# Clamp & normalize
	gather_pct = maxf(gather_pct, 0.05)
	tend_pct = maxf(tend_pct, 0.0)
	teach_pct = maxf(teach_pct, 0.0)
	build_pct = maxf(build_pct, 0.0)
	work_pct = maxf(work_pct, 0.0)
	var total: float = gather_pct + work_pct + build_pct + tend_pct + teach_pct
	if total > 0:
		gather_pct /= total
		work_pct /= total
		build_pct /= total
		tend_pct /= total
		teach_pct /= total

	gs.alloc_pct = {"gather": gather_pct, "work": work_pct, "build": build_pct, "tend": tend_pct, "teach": teach_pct}

	# Sacrifice
	gs.chosen_sacrifice = ""
	if gs.tree_of_life < float(_strat["sac_threshold"]) and gs.livestock >= 2:
		gs.chosen_sacrifice = "olah"
		_sacrifice_count += 1
	elif gs.tree_of_life < float(_strat["sac_threshold"]) - 15 and gs.food >= 6:
		gs.chosen_sacrifice = "mincha"
		_sacrifice_count += 1

	# Festival selection (Year 1+)
	gs.chosen_festival_scale = ""
	if gs.year > 0 and gs.current_festival_name() != "":
		if gs.food >= 20 and gs.can_afford_festival("Standard"):
			gs.chosen_festival_scale = "Standard"
		elif gs.food >= 12 and gs.can_afford_festival("Minimal"):
			gs.chosen_festival_scale = "Minimal"
		else:
			gs.chosen_festival_scale = "Skip"

	# Track pre-resolve state
	var pre_fire: float = gs.tree_of_life
	var pre_food: int = gs.food
	var pre_pop: int = gs.total_population

	# Resolve
	var summary: Dictionary = SeasonResolver.resolve_season()

	# Track post-resolve
	var fire_delta: float = gs.tree_of_life - pre_fire
	var food_delta: int = gs.food - pre_food
	_fire_min = minf(_fire_min, gs.tree_of_life)
	_food_min = mini(_food_min, gs.food)
	if gs.food <= 0:
		_food_zero_count += 1

	var bld := ""
	if gs.last_building_completed != "":
		bld = " BUILT:%s" % gs.last_building_completed
	elif gs.active_building != "":
		bld = " bld:%s(%d)" % [gs.active_building, gs.active_building_progress]

	var sac := " sac:%s" % gs.chosen_sacrifice if gs.chosen_sacrifice != "" else ""

	var of: int = summary.get("overflow_food", 0)
	_overflow_food_total += of
	var of_str := " ovf:+%dfd" % of if of > 0 else ""

	var line := "  Y%dS%d %s: F=%.0f%%(%+.0f) Fd=%d(%+d) Pop=%d Lv=%d Pr=%d Rt=%.1f%s%s%s" % [
		gs.year, gs.season_idx, season_name,
		gs.tree_of_life, fire_delta, gs.food, food_delta,
		gs.total_population, gs.livestock, gs.provision,
		_avg_roots(), bld, sac, of_str
	]
	print(line)
	_season_log.append(line)

	if GameState.game_over:
		print("[ECON] GAME OVER after resolve: %s" % GameState.game_over_reason)
		_errors.append("Run %d (%s): GAME OVER Y%dS%d — %s" % [_runs, _strat["name"], gs.year, gs.season_idx, gs.game_over_reason])
		_finish_run()
		return

	# Advance
	gs.season_idx += 1
	if gs.season_idx >= 4:
		gs.season_idx = 0
		gs.year += 1
		gs.reset_yearly_accumulators()

	if gs.tree_of_life <= 0:
		gs.game_over = true
		gs.game_over_reason = "The roots have withered. The Tree of Life goes dark."

	gs.state_changed.emit()
	_run_season.call_deferred()


func _avg_roots() -> float:
	var gs := GameState
	var sum: float = 0.0
	for p in gs.roots:
		sum += p
	return sum / maxf(gs.roots.size(), 1.0)


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

	# Fire ALL harddate events (pinned to specific seasons, must not be skipped)
	for ev in harddate:
		_fire_single(ev)
	# Fire ALL mandatory events
	for ev in mandatory:
		_fire_single(ev)
	# ALSO fire one random event per season
	if not random_evts.is_empty():
		random_evts.shuffle()
		_fire_single(random_evts[0])


func _fire_single(ev: Dictionary) -> void:
	var choices: Array = ev.get("choices", [])
	if choices.is_empty():
		return

	var pick_idx: int = 0
	var style: String = _strat.get("choice_style", "first")

	match style:
		"first":
			pick_idx = 0
		"second":
			pick_idx = mini(1, choices.size() - 1)
		"last":
			pick_idx = choices.size() - 1
		"random":
			pick_idx = randi() % choices.size()

	var effects: Array = choices[pick_idx].get("effects", [])
	EffectResolver.apply_effects(effects, GameState)

	if ev.get("frequency", "once") == "once":
		GameState.events_fired.append(ev["id"])
	GameState.event_last_fired[ev["id"]] = GameState.year


func _finish_run() -> void:
	var gs := GameState
	var survived: bool = gs.year >= 8
	var roots_str := ""
	for i in gs.roots.size():
		roots_str += "%.1f " % gs.roots[i]

	print("[ECON] --- Run %d (%s) Summary ---" % [_runs, _strat["name"]])
	print("[ECON]   Result: %s | Y%dS%d" % ["SURVIVED" if survived else "DIED", gs.year, gs.season_idx])
	print("[ECON]   Fire: %.0f%% (min=%.0f%%) | Food: %d (min=%d, zeroes=%d)" % [gs.tree_of_life, _fire_min, gs.food, _food_min, _food_zero_count])
	print("[ECON]   Pop: %d | Ham=%d Central=%d Yephet=%d" % [gs.total_population, gs.ham_relation, gs.ham_centralisation, gs.yephet_loyalty])
	print("[ECON]   Tents: %s" % str(gs.buildings_completed))
	print("[ECON]   Roots: [%s] avg=%.1f" % [roots_str.strip_edges(), _avg_roots()])
	print("[ECON]   Sacrifices: %d | Livestock: %d | Overflow food: %d" % [_sacrifice_count, gs.livestock, _overflow_food_total])

	# Flag specific observations
	if _fire_min < 20:
		_notes.append("Run %d (%s): FIRE DANGER — min fire %.0f%%" % [_runs, _strat["name"], _fire_min])
	if _food_min <= 2:
		_notes.append("Run %d (%s): FAMINE RISK — min food %d" % [_runs, _strat["name"], _food_min])
	if gs.total_population == 8 and gs.year >= 4:
		_notes.append("Run %d (%s): NO POPULATION GROWTH by Y%d" % [_runs, _strat["name"], gs.year])
	if gs.ham_centralisation >= 30:
		_notes.append("Run %d (%s): HIGH CENTRALISATION %d" % [_runs, _strat["name"], gs.ham_centralisation])
	if _avg_roots() < 5.0:
		_notes.append("Run %d (%s): ROOTS DECAYED avg=%.1f" % [_runs, _strat["name"], _avg_roots()])
	if gs.tree_of_life >= 99 and gs.year >= 3:
		_notes.append("Run %d (%s): FIRE CAPPED AT 100%% — too easy?" % [_runs, _strat["name"]])
	if gs.food >= gs.food_cap and gs.year >= 3:
		_notes.append("Run %d (%s): FOOD CAPPED — excess production wasted" % [_runs, _strat["name"]])
	if survived and len(gs.buildings_completed) <= 2:
		_notes.append("Run %d (%s): SURVIVED with only %d tents — building feels optional" % [_runs, _strat["name"], len(gs.buildings_completed)])
	if not survived:
		_notes.append("Run %d (%s): DIED at Y%dS%d — %s" % [_runs, _strat["name"], gs.year, gs.season_idx, gs.game_over_reason])
	if _sacrifice_count == 0 and survived:
		_notes.append("Run %d (%s): NEVER SACRIFICED — survived without altar use" % [_runs, _strat["name"]])
	if gs.livestock >= 28 and _overflow_food_total == 0:
		_notes.append("Run %d (%s): LIVESTOCK CAPPED at %d — no overflow triggered?" % [_runs, _strat["name"], gs.livestock])
	elif _overflow_food_total > 0:
		_notes.append("Run %d (%s): LIVESTOCK OVERFLOW — %d extra food from herds" % [_runs, _strat["name"], _overflow_food_total])

	print("")

	if _runs < MAX_RUNS:
		_start_run.call_deferred()
	else:
		_print_final_report()


func _print_final_report() -> void:
	print("[ECON] ========================================")
	print("[ECON] FINAL REPORT: %d runs complete" % MAX_RUNS)
	print("[ECON] ========================================")
	print("")

	if _errors.is_empty():
		print("[ECON] DEATHS: 0 / %d" % MAX_RUNS)
	else:
		print("[ECON] DEATHS: %d / %d" % [_errors.size(), MAX_RUNS])
		for e in _errors:
			print("[ECON]   %s" % e)

	print("")
	print("[ECON] OBSERVATIONS (%d):" % _notes.size())
	for n in _notes:
		print("[ECON]   %s" % n)

	print("")
	print("[ECON] DONE")
	get_tree().quit(0)
