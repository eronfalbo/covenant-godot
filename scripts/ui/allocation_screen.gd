extends Control
## AllocationScreen — Player distributes labor, picks building, picks sacrifice.

signal allocation_confirmed

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var status_label: RichTextLabel = $VBoxContainer/StatusPanel/StatusText
@onready var work_label: Label = $VBoxContainer/AllocationPanel/WorkRow/WorkValue
@onready var build_label: Label = $VBoxContainer/AllocationPanel/BuildRow/BuildValue
@onready var tend_label: Label = $VBoxContainer/AllocationPanel/TendRow/TendValue
@onready var forecast_label: RichTextLabel = $VBoxContainer/ForecastPanel/ForecastText
@onready var building_option: OptionButton = $VBoxContainer/BuildingRow/BuildingOption
@onready var sacrifice_option: OptionButton = $VBoxContainer/SacrificeRow/SacrificeOption
@onready var confirm_btn: Button = $VBoxContainer/ConfirmButton
@onready var remaining_label: Label = $VBoxContainer/AllocationPanel/RemainingLabel

var _work: int = 0
var _build: int = 0
var _tend: int = 0
var _available: int = 0


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	building_option.item_selected.connect(_on_building_changed)
	sacrifice_option.item_selected.connect(_on_sacrifice_changed)
	$VBoxContainer/AllocationPanel/WorkRow/WorkMinus.pressed.connect(_on_work_minus)
	$VBoxContainer/AllocationPanel/WorkRow/WorkPlus.pressed.connect(_on_work_plus)
	$VBoxContainer/AllocationPanel/BuildRow/BuildMinus.pressed.connect(_on_build_minus)
	$VBoxContainer/AllocationPanel/BuildRow/BuildPlus.pressed.connect(_on_build_plus)
	$VBoxContainer/AllocationPanel/TendRow/TendMinus.pressed.connect(_on_tend_minus)
	$VBoxContainer/AllocationPanel/TendRow/TendPlus.pressed.connect(_on_tend_plus)
	_setup_allocation()


func setup(_data: Dictionary) -> void:
	pass


func _setup_allocation() -> void:
	var gs := GameState
	_available = gs.effective_allocatable
	header_label.text = "%s — Year %d" % [gs.current_season, gs.year]

	_work = _available
	_build = 0
	_tend = 0

	_populate_buildings()
	_populate_sacrifices()
	_refresh_display()


func _populate_buildings() -> void:
	building_option.clear()
	building_option.add_item("None", 0)
	var gs := GameState
	var available := gs.get_available_buildings()

	if gs.active_building != "":
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		var bname: String = bdef.get("name", gs.active_building)
		var bbonus: String = bdef.get("bonus_text", "")
		var label := "%s (%d/%d)" % [bname, gs.active_building_progress, bdef.get("build_points_required", 0)]
		if bbonus != "":
			label += " — " + bbonus
		building_option.add_item(label, 1)
		building_option.set_item_metadata(1, gs.active_building)
		building_option.select(1)
		var idx := 2
		for bid in available:
			if bid == gs.active_building:
				continue
			var bd: Dictionary = gs.BUILDING_DEFS.get(bid, {})
			var bonus: String = bd.get("bonus_text", "")
			var blabel := "%s (0/%d)" % [bd.get("name", bid), bd.get("build_points_required", 0)]
			if bonus != "":
				blabel += " — " + bonus
			building_option.add_item(blabel, idx)
			building_option.set_item_metadata(idx, bid)
			idx += 1
	else:
		var idx := 1
		for bid in available:
			var bd: Dictionary = gs.BUILDING_DEFS.get(bid, {})
			var bonus: String = bd.get("bonus_text", "")
			var blabel := "%s (0/%d)" % [bd.get("name", bid), bd.get("build_points_required", 0)]
			if bonus != "":
				blabel += " — " + bonus
			building_option.add_item(blabel, idx)
			building_option.set_item_metadata(idx, bid)
			idx += 1


func _populate_sacrifices() -> void:
	sacrifice_option.clear()
	sacrifice_option.add_item("None", 0)
	var gs := GameState
	var available := gs.get_available_sacrifices()
	var idx := 1
	for sid in available:
		var sdef: Dictionary = gs.SACRIFICE_DEFS.get(sid, {})
		var cost_parts: Array[String] = []
		if sdef.get("livestock_cost", 0) > 0:
			cost_parts.append("%d livestock" % sdef["livestock_cost"])
		if sdef.get("food_cost", 0) > 0:
			cost_parts.append("%d food" % sdef["food_cost"])
		var cost_str: String = ", ".join(cost_parts) if not cost_parts.is_empty() else "free"
		sacrifice_option.add_item("%s (%s, +%.0f%% fire)" % [sdef.get("name", sid), cost_str, sdef.get("fire_bonus", 0)], idx)
		sacrifice_option.set_item_metadata(idx, sid)
		idx += 1


func _get_selected_building() -> String:
	var sel := building_option.selected
	if sel <= 0:
		return ""
	return str(building_option.get_item_metadata(sel))


func _get_selected_sacrifice() -> String:
	var sel := sacrifice_option.selected
	if sel <= 0:
		return ""
	return str(sacrifice_option.get_item_metadata(sel))


func _refresh_display() -> void:
	var gs := GameState
	var remaining: int = _available - _work - _build - _tend

	# Status section with demographics
	var status_parts: Array[String] = []
	status_parts.append("[color=%s]Living Fire:[/color] %.0f%% (%s)" % [UIConstants.GOLD_HEX, gs.living_fire, gs.tzohar_status])
	status_parts.append("[color=%s]Souls:[/color] %d    [color=%s]Food:[/color] %d/%d    [color=%s]Livestock:[/color] %d" % [
		UIConstants.GOLD_HEX, gs.total_bnei_brit,
		UIConstants.GOLD_HEX, gs.food, gs.food_cap,
		UIConstants.GOLD_HEX, gs.livestock])
	status_parts.append("[color=%s]Available Labor:[/color] %d of %d (fire x population)" % [UIConstants.GOLD_HEX, _available, gs.total_bnei_brit])
	if gs.tent_scene_occurred and gs.ham_drift_penalty > 0:
		status_parts.append("[color=%s]Ham is distant — effective labor reduced[/color]" % UIConstants.WARN_ORANGE)
	if gs.bleeding_active:
		status_parts.append("[color=%s]The wound festers — extra fire loss each season[/color]" % UIConstants.WARN_RED)
	if not gs.buildings_completed.is_empty():
		var blines: Array[String] = []
		for bid in gs.buildings_completed:
			var bdef: Dictionary = gs.BUILDING_DEFS.get(bid, {})
			blines.append("[color=%s]%s[/color]: %s" % [UIConstants.SUCCESS_GREEN, bdef.get("name", bid), bdef.get("bonus_text", "")])
		status_parts.append("[color=%s]Buildings:[/color] %s" % [UIConstants.GOLD_HEX, "  |  ".join(blines)])
	status_label.text = "\n".join(status_parts)

	# Allocation values
	work_label.text = str(_work)
	build_label.text = str(_build)
	tend_label.text = str(_tend)
	remaining_label.text = "Remaining: %d" % remaining

	# Forecast with color-coded deltas
	var sacrifice_id: String = _get_selected_sacrifice()
	var fc: Dictionary = SeasonResolver.forecast(gs, _work, _build, _tend, sacrifice_id)

	var fc_parts: Array[String] = []
	var food_delta: int = fc["food_forecast"] - gs.food
	var food_color: String = UIConstants.SUCCESS_GREEN if food_delta >= 0 else UIConstants.WARN_RED
	fc_parts.append("[color=%s]Food:[/color] %d → [color=%s]%d[/color]  (produced %d, consumed %d)" % [
		UIConstants.GOLD_HEX, gs.food, food_color, fc["food_forecast"], fc["food_produced"], fc["food_consumed"]])

	var fire_delta: float = fc["fire_delta"]
	var fire_color: String = UIConstants.SUCCESS_GREEN if fire_delta >= 0 else UIConstants.WARN_RED
	var fire_sign: String = "+" if fire_delta >= 0 else ""
	fc_parts.append("[color=%s]Fire:[/color] %.0f%% → [color=%s]%.0f%%[/color]  (%s%.0f%%)" % [
		UIConstants.GOLD_HEX, gs.living_fire, fire_color, fc["fire_forecast"], fire_sign, fire_delta])

	if gs.active_building != "":
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		var bp_after: int = gs.active_building_progress + fc["build_progress"]
		var complete_text: String = " [color=%s]COMPLETE![/color]" % UIConstants.SUCCESS_GREEN if fc["build_will_complete"] else ""
		fc_parts.append("[color=%s]Build:[/color] %s %d/%d%s" % [
			UIConstants.GOLD_HEX,
			bdef.get("name", gs.active_building),
			bp_after,
			bdef.get("build_points_required", 0),
			complete_text
		])

	fc_parts.append("[color=%s]Livestock:[/color] %d → %d" % [UIConstants.GOLD_HEX, gs.livestock, fc["livestock_forecast"]])
	forecast_label.text = "\n".join(fc_parts)

	# Validation
	var valid: bool = remaining == 0
	if _build > 0 and _build < gs.MIN_BUILDERS and _get_selected_building() != "":
		valid = false
		forecast_label.text += "\n[color=%s]Need at least %d builders for progress[/color]" % [UIConstants.WARN_RED, gs.MIN_BUILDERS]
	if _work == 0:
		forecast_label.text += "\n[color=%s]Warning: No food production this season[/color]" % UIConstants.WARN_ORANGE
	confirm_btn.disabled = not valid


func _adjust(bucket: String, delta: int) -> void:
	var step: int = delta
	if bucket == "build":
		step = delta * GameState.MIN_BUILDERS

	match bucket:
		"work":
			_work = clampi(_work + delta, 0, _available - _build - _tend)
		"build":
			var new_build := clampi(_build + step, 0, _available - _tend)
			var diff := new_build - _build
			_build = new_build
			_work = clampi(_work - diff, 0, _available - _build - _tend)
		"tend":
			var new_tend := clampi(_tend + delta, 0, _available - _build)
			var diff := new_tend - _tend
			_tend = new_tend
			_work = clampi(_work - diff, 0, _available - _build - _tend)
	_refresh_display()


func _on_work_minus() -> void: _adjust("work", -1)
func _on_work_plus() -> void: _adjust("work", 1)
func _on_build_minus() -> void: _adjust("build", -1)
func _on_build_plus() -> void: _adjust("build", 1)
func _on_tend_minus() -> void: _adjust("tend", -1)
func _on_tend_plus() -> void: _adjust("tend", 1)


func _on_building_changed(_idx: int) -> void:
	var gs := GameState
	var sel: String = _get_selected_building()
	if sel != "" and sel != gs.active_building:
		gs.active_building = sel
		gs.active_building_progress = 0
	_refresh_display()


func _on_sacrifice_changed(_idx: int) -> void:
	_refresh_display()


func _on_confirm() -> void:
	var gs := GameState
	gs.workers_on_work = _work
	gs.workers_on_build = _build
	gs.workers_on_tend = _tend
	gs.chosen_sacrifice = _get_selected_sacrifice()

	var sel_building: String = _get_selected_building()
	if sel_building != "":
		gs.active_building = sel_building

	confirm_btn.disabled = true
	allocation_confirmed.emit()
