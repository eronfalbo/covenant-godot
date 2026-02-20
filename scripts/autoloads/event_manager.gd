extends Node
## EventManager — Loads events from JSON, filters by predicate, fires them.

signal event_started(event_data: Dictionary)
signal event_choice_made(event_id: String, choice_idx: int)
signal event_finished(event_id: String)
signal narrative_text_added(text: String)
signal season_events_complete

var all_events: Array[Dictionary] = []

var _event_files: Array[String] = [
	"res://data/events/ararat_year0.json",
]

# Set by the game loop; awaited during fire_event
var _pending_choice: int = -1
var _choice_received: bool = false


func _ready() -> void:
	_load_all_events()
	# Wire up the EffectResolver callback for show_text
	EffectResolver.narrative_text_requested = func(text: String):
		narrative_text_added.emit(text)


func _load_all_events() -> void:
	for path in _event_files:
		if not FileAccess.file_exists(path):
			push_warning("EventManager: event file not found: %s" % path)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var text := file.get_as_text()
		file.close()
		var json = JSON.parse_string(text)
		if json == null:
			push_error("EventManager: failed to parse %s" % path)
			continue
		if json.has("events"):
			all_events.append_array(json["events"])
	print("EventManager: loaded %d events" % all_events.size())


func get_valid_events() -> Array[Dictionary]:
	var gs := _get_gs()
	var valid: Array[Dictionary] = []
	for ev in all_events:
		# Once-events that already fired
		if ev.get("frequency", "once") == "once" and ev["id"] in gs.events_fired:
			continue
		# Repeatable cooldown check
		if ev.get("frequency", "once") == "repeatable":
			var last_year: int = gs.event_last_fired.get(ev["id"], -999)
			if gs.year - last_year < ev.get("cooldown", 0):
				continue
		# Predicate check
		if not ConditionChecker.evaluate(ev.get("predicate", {}), gs):
			continue
		valid.append(ev)
	return valid


func run_season_events() -> void:
	var valid := get_valid_events()
	var gs := _get_gs()

	# Separate by prefix
	var ararat: Array[Dictionary] = []
	var harddate: Array[Dictionary] = []
	var mandatory: Array[Dictionary] = []
	var procedural: Array[Dictionary] = []

	for ev in valid:
		var id: String = ev["id"]
		if id.begins_with("H"):
			harddate.append(ev)
		elif id.begins_with("A"):
			ararat.append(ev)
		elif id.begins_with("M") or id.begins_with("BC"):
			mandatory.append(ev)
		elif id.begins_with("P") or id.begins_with("BE"):
			procedural.append(ev)

	var to_fire: Array[Dictionary] = []

	# Priority: H > A > M/BC > P/BE
	if not harddate.is_empty():
		to_fire.append(harddate[0])
	elif not ararat.is_empty() and gs.year != 0:
		to_fire.append(ararat[0])
	elif not mandatory.is_empty():
		to_fire.append(mandatory[0])

	# Fire selected events
	for ev in to_fire:
		await fire_event(ev)

	# Year 0 special: chain Ararat events (re-evaluate after each)
	if gs.year == 0 and gs.phase == "ararat":
		var chain_safety := 0
		while true:
			chain_safety += 1
			if chain_safety > 20:
				push_error("EventManager: Ararat event chain exceeded 20 — breaking")
				break
			var fresh := get_valid_events()
			var chain: Array[Dictionary] = []
			for e in fresh:
				if e["id"].begins_with("A"):
					chain.append(e)
			if chain.is_empty():
				break
			await fire_event(chain[0])

	season_events_complete.emit()


func fire_event(ev: Dictionary) -> void:
	var gs := _get_gs()

	# Signal that an event is starting (UI listens for this)
	event_started.emit(ev)

	# Wait for the player to make a choice
	_choice_received = false
	_pending_choice = -1

	# The event_screen will call submit_choice() when the player picks
	var wait_frames := 0
	while not _choice_received:
		await get_tree().process_frame
		wait_frames += 1
		if wait_frames > 18000:  # ~5 minutes at 60fps — something is broken
			push_error("EventManager: choice timeout for event '%s'" % ev["id"])
			_pending_choice = 0  # default to first choice
			break

	var choice_idx: int = _pending_choice

	# Apply effects
	if choice_idx >= 0 and choice_idx < ev["choices"].size():
		var effects: Array = ev["choices"][choice_idx].get("effects", [])
		EffectResolver.apply_effects(effects, gs)

	# Track
	if ev.get("frequency", "once") == "once":
		gs.events_fired.append(ev["id"])
	gs.event_last_fired[ev["id"]] = gs.year

	event_finished.emit(ev["id"])


func submit_choice(event_id: String, choice_idx: int) -> void:
	_pending_choice = choice_idx
	_choice_received = true
	event_choice_made.emit(event_id, choice_idx)


func _get_gs() -> Node:
	return get_node("/root/GameState")
