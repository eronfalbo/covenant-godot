extends Control
## AllocationScreen — Player distributes labor, picks building, picks sacrifice.
## Minimal functional UI — will be redesigned later.

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
	# Connect +/- buttons
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

	# Default: all to work
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

	# If there's an active project, show it first
	if gs.active_building != "":
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		var name: String = bdef.get("name", gs.active_building)
		building_option.add_item("%s (%d/%d)" % [name, gs.active_building_progress, bdef.get("build_points_required", 0)], 1)
		building_option.set_item_metadata(1, gs.active_building)
		building_option.select(1)
		var idx := 2
		for bid in available:
			if bid == gs.active_building:
				continue
			var bd: Dictionary = gs.BUILDING_DEFS.get(bid, {})
			building_option.add_item("%s (0/%d)" % [bd.get("name", bid), bd.get("build_points_required", 0)], idx)
			building_option.set_item_metadata(idx, bid)
			idx += 1
	else:
		var idx := 1
		for bid in available:
			var bd: Dictionary = gs.BUILDING_DEFS.get(bid, {})
			building_option.add_item("%s (0/%d)" % [bd.get("name", bid), bd.get("build_points_required", 0)], idx)
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

	# Status
	var status_parts: Array[String] = []
	status_parts.append("[color=#c9a962]Living Fire:[/color] %.0f%% (%s)" % [gs.living_fire, gs.tzohar_status])
	status_parts.append("[color=#c9a962]Food:[/color] %d  [color=#c9a962]Livestock:[/color] %d" % [gs.food, gs.livestock])
	status_parts.append("[color=#c9a962]Population:[/color] %d  [color=#c9a962]Allocatable:[/color] %d" % [gs.total_bnei_brit, _available])
	if gs.tent_scene_occurred and gs.ham_drift_penalty > 0:
		status_parts.append("[color=#cc6644]Ham is distant — effective labor reduced[/color]")
	if gs.bleeding_active:
		status_parts.append("[color=#cc4444]The wound festers — extra fire loss each season[/color]")
	status_label.text = "\n".join(status_parts)

	# Allocation values
	work_label.text = str(_work)
	build_label.text = str(_build)
	tend_label.text = str(_tend)
	remaining_label.text = "Remaining: %d" % remaining

	# Forecast
	var sacrifice_id: String = _get_selected_sacrifice()
	var fc: Dictionary = SeasonResolver.forecast(gs, _work, _build, _tend, sacrifice_id)
	var fc_parts: Array[String] = []
	fc_parts.append("Food: %d + %d - %d = %d" % [gs.food, fc["food_produced"], fc["food_consumed"], fc["food_forecast"]])
	fc_parts.append("Fire: %.0f%% → %.0f%% (%.0f%%)" % [gs.living_fire, fc["fire_forecast"], fc["fire_delta"]])
	if gs.active_building != "":
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		var bp_after: int = gs.active_building_progress + fc["build_progress"]
		fc_parts.append("Build: %s %d/%d%s" % [
			bdef.get("name", gs.active_building),
			bp_after,
			bdef.get("build_points_required", 0),
			" COMPLETE!" if fc["build_will_complete"] else ""
		])
	fc_parts.append("Livestock: %d → %d" % [gs.livestock, fc["livestock_forecast"]])
	forecast_label.text = "\n".join(fc_parts)

	# Validation
	var valid: bool = remaining == 0
	if _build > 0 and _build < gs.MIN_BUILDERS and _get_selected_building() != "":
		valid = false
		forecast_label.text += "\n[color=#cc4444]Need at least %d builders for progress[/color]" % gs.MIN_BUILDERS
	if _work == 0:
		forecast_label.text += "\n[color=#cc6644]Warning: No food production this season[/color]"
	confirm_btn.disabled = not valid


func _adjust(bucket: String, delta: int) -> void:
	var remaining: int = _available - _work - _build - _tend
	match bucket:
		"work":
			_work = clampi(_work + delta, 0, _work + remaining if delta > 0 else _work)
		"build":
			_build = clampi(_build + delta, 0, _build + remaining if delta > 0 else _build)
		"tend":
			_tend = clampi(_tend + delta, 0, _tend + remaining if delta > 0 else _tend)
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
		# Switch active project (preserves progress on old one)
		gs.active_building = sel
		gs.active_building_progress = 0
	elif sel == "":
		# No building selected — don't clear active_building, just won't assign workers
		pass
	_refresh_display()


func _on_sacrifice_changed(_idx: int) -> void:
	_refresh_display()


func _on_confirm() -> void:
	var gs := GameState
	gs.workers_on_work = _work
	gs.workers_on_build = _build
	gs.workers_on_tend = _tend
	gs.chosen_sacrifice = _get_selected_sacrifice()

	# Set active building from dropdown
	var sel_building: String = _get_selected_building()
	if sel_building != "":
		gs.active_building = sel_building

	confirm_btn.disabled = true
	allocation_confirmed.emit()
