extends Control
## AllocationScreen — Player distributes labor, picks building, picks sacrifice.

signal allocation_confirmed

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var status_label: RichTextLabel = $VBoxContainer/StatusPanel/StatusText
@onready var work_label: Label = $VBoxContainer/AllocationPanel/WorkRow/WorkValue
@onready var build_label: Label = $VBoxContainer/AllocationPanel/BuildRow/BuildValue
@onready var tend_label: Label = $VBoxContainer/AllocationPanel/TendRow/TendValue
@onready var forecast_label: RichTextLabel = $VBoxContainer/ForecastPanel/ForecastText
@onready var sacrifice_option: OptionButton = $VBoxContainer/SacrificeRow/SacrificeOption
@onready var confirm_btn: Button = $VBoxContainer/ConfirmButton
@onready var remaining_label: Label = $VBoxContainer/AllocationPanel/RemainingLabel

var _work: int = 0
var _build: int = 0
var _tend: int = 0
var _teach: int = 0
var _available: int = 0
var teach_label: Label = null

# Building inline row (created in code, shown when builders >= MIN_BUILDERS)
var building_option: OptionButton = null
var _building_inline_row: HBoxContainer = null

# Switch confirmation
var _pending_building_switch: String = ""
var _confirm_dialog: ConfirmationDialog = null


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	sacrifice_option.item_selected.connect(_on_sacrifice_changed)
	$VBoxContainer/AllocationPanel/WorkRow/WorkMinus.pressed.connect(_on_work_minus)
	$VBoxContainer/AllocationPanel/WorkRow/WorkPlus.pressed.connect(_on_work_plus)
	$VBoxContainer/AllocationPanel/BuildRow/BuildMinus.pressed.connect(_on_build_minus)
	$VBoxContainer/AllocationPanel/BuildRow/BuildPlus.pressed.connect(_on_build_plus)
	$VBoxContainer/AllocationPanel/TendRow/TendMinus.pressed.connect(_on_tend_minus)
	$VBoxContainer/AllocationPanel/TendRow/TendPlus.pressed.connect(_on_tend_plus)

	var alloc_panel := $VBoxContainer/AllocationPanel
	var build_row := $VBoxContainer/AllocationPanel/BuildRow

	# Add building inline row (after BuildRow)
	_building_inline_row = _create_building_inline_row()
	alloc_panel.add_child(_building_inline_row)
	alloc_panel.move_child(_building_inline_row, build_row.get_index() + 1)

	# Add Teach row dynamically (after Tend row)
	var teach_row := _create_teach_row()
	alloc_panel.add_child(teach_row)
	alloc_panel.move_child(teach_row, remaining_label.get_index())

	# Add reset button dynamically (placed before confirm)
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.add_theme_font_size_override("font_size", UIConstants.BODY_SMALL_SIZE)
	reset_btn.pressed.connect(_on_reset)
	confirm_btn.get_parent().add_child(reset_btn)
	confirm_btn.get_parent().move_child(reset_btn, confirm_btn.get_index())

	# Switch confirmation dialog
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Abandon progress?"
	_confirm_dialog.confirmed.connect(_on_switch_confirmed)
	_confirm_dialog.canceled.connect(_on_switch_canceled)
	add_child(_confirm_dialog)

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
	_teach = 0

	# Tooltips
	work_label.tooltip_text = "Workers producing food (%d per worker, %d in spring)" % [gs.FOOD_PER_WORKER, gs.FOOD_PER_WORKER_SPRING]
	build_label.tooltip_text = "Workers constructing buildings (%d point per worker, minimum %d)" % [gs.BUILD_PER_WORKER, gs.MIN_BUILDERS]
	tend_label.tooltip_text = "Workers tending the Living Fire (+%.0f%% per tender)" % gs.FIRE_PER_TENDER
	if teach_label:
		teach_label.tooltip_text = "Workers teaching the covenant (strengthens weakest pillar)"

	_populate_buildings()
	_populate_sacrifices()
	_refresh_display()


func _populate_buildings() -> void:
	if not building_option:
		return
	building_option.clear()
	building_option.add_item("— Select —", 0)
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
	if not building_option or building_option.selected <= 0:
		return ""
	return str(building_option.get_item_metadata(building_option.selected))


func _get_selected_sacrifice() -> String:
	var sel := sacrifice_option.selected
	if sel <= 0:
		return ""
	return str(sacrifice_option.get_item_metadata(sel))


func _refresh_display() -> void:
	var gs := GameState
	var remaining: int = _available - _work - _build - _tend - _teach

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
	if teach_label:
		teach_label.text = str(_teach)
	remaining_label.text = "Remaining: %d" % remaining

	# Building inline row visibility — show only when enough builders allocated
	if _building_inline_row:
		var show_building: bool = _build >= gs.MIN_BUILDERS
		_building_inline_row.visible = show_building
		if not show_building and building_option:
			# Auto-deselect when builders drop below minimum
			building_option.select(0)

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

	if _get_selected_building() != "":
		var sel_bid: String = _get_selected_building()
		var bdef: Dictionary = gs.BUILDING_DEFS.get(sel_bid, {})
		var current_progress: int = gs.active_building_progress if sel_bid == gs.active_building else 0
		var bp_after: int = current_progress + fc["build_progress"]
		var required: int = bdef.get("build_points_required", 0)
		var complete_text: String = " [color=%s]COMPLETE![/color]" % UIConstants.SUCCESS_GREEN if bp_after >= required else ""
		fc_parts.append("[color=%s]Build:[/color] %s %d/%d%s" % [
			UIConstants.GOLD_HEX,
			bdef.get("name", sel_bid),
			bp_after,
			required,
			complete_text
		])

	fc_parts.append("[color=%s]Livestock:[/color] %d → %d" % [UIConstants.GOLD_HEX, gs.livestock, fc["livestock_forecast"]])

	if _teach > 0:
		var teach_gain: float = pow(maxf(_teach, 0), 0.85) * 0.15
		var lowest_idx: int = 0
		var lowest_val: float = gs.pillars[0]
		for i in range(1, gs.pillars.size()):
			if gs.pillars[i] < lowest_val:
				lowest_val = gs.pillars[i]
				lowest_idx = i
		fc_parts.append("[color=%s]Teaching:[/color] %s +%.1f (weakest pillar)" % [
			UIConstants.GOLD_HEX, gs.PILLAR_SHORT[lowest_idx], teach_gain])

	forecast_label.text = "\n".join(fc_parts)

	# Validation
	var valid: bool = remaining == 0
	if _build > 0 and _build < gs.MIN_BUILDERS:
		valid = false
		forecast_label.text += "\n[color=%s]Need at least %d builders for progress[/color]" % [UIConstants.WARN_RED, gs.MIN_BUILDERS]
	if _build >= gs.MIN_BUILDERS and _get_selected_building() == "":
		valid = false
		forecast_label.text += "\n[color=%s]Builders ready — choose a project above[/color]" % UIConstants.WARN_ORANGE
	if _work == 0:
		forecast_label.text += "\n[color=%s]Warning: No food production this season[/color]" % UIConstants.WARN_ORANGE
	if _teach == 0 and gs.year > 0:
		forecast_label.text += "\n[color=%s]No one is teaching — the pillars weaken[/color]" % UIConstants.WARN_ORANGE
	confirm_btn.disabled = not valid


func _adjust(bucket: String, delta: int) -> void:
	var step: int = delta
	if bucket == "build":
		step = delta * GameState.MIN_BUILDERS

	match bucket:
		"work":
			_work = clampi(_work + delta, 0, _available - _build - _tend - _teach)
		"build":
			var new_build := clampi(_build + step, 0, _available - _tend - _teach)
			var diff := new_build - _build
			_build = new_build
			_work = clampi(_work - diff, 0, _available - _build - _tend - _teach)
		"tend":
			var new_tend := clampi(_tend + delta, 0, _available - _build - _teach)
			var diff := new_tend - _tend
			_tend = new_tend
			_work = clampi(_work - diff, 0, _available - _build - _tend - _teach)
		"teach":
			var new_teach := clampi(_teach + delta, 0, _available - _build - _tend)
			var diff := new_teach - _teach
			_teach = new_teach
			_work = clampi(_work - diff, 0, _available - _build - _tend - _teach)
	_refresh_display()


func _on_reset() -> void:
	_work = _available
	_build = 0
	_tend = 0
	_teach = 0
	if building_option:
		building_option.select(0)
	_refresh_display()


func _create_building_inline_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "BuildingInlineRow"
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "Project:"
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_lbl.add_theme_font_size_override("font_size", UIConstants.BODY_SMALL_SIZE)
	name_lbl.add_theme_color_override("font_color", UIConstants.GOLD)
	row.add_child(name_lbl)
	building_option = OptionButton.new()
	building_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_option.add_theme_font_size_override("font_size", UIConstants.BODY_SMALL_SIZE)
	building_option.item_selected.connect(_on_building_changed)
	row.add_child(building_option)
	row.visible = false
	return row


func _create_teach_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TeachRow"
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "Teach"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", UIConstants.BODY_SIZE)
	row.add_child(name_lbl)
	var minus := Button.new()
	minus.text = "-"
	minus.name = "TeachMinus"
	minus.custom_minimum_size = Vector2(40, 0)
	minus.pressed.connect(_on_teach_minus)
	row.add_child(minus)
	teach_label = Label.new()
	teach_label.text = "0"
	teach_label.name = "TeachValue"
	teach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teach_label.custom_minimum_size = Vector2(40, 0)
	teach_label.add_theme_font_size_override("font_size", UIConstants.BODY_SIZE)
	row.add_child(teach_label)
	var plus := Button.new()
	plus.text = "+"
	plus.name = "TeachPlus"
	plus.custom_minimum_size = Vector2(40, 0)
	plus.pressed.connect(_on_teach_plus)
	row.add_child(plus)
	return row


func _on_work_minus() -> void: _adjust("work", -1)
func _on_work_plus() -> void: _adjust("work", 1)
func _on_build_minus() -> void: _adjust("build", -1)
func _on_build_plus() -> void: _adjust("build", 1)
func _on_tend_minus() -> void: _adjust("tend", -1)
func _on_tend_plus() -> void: _adjust("tend", 1)
func _on_teach_minus() -> void: _adjust("teach", -1)
func _on_teach_plus() -> void: _adjust("teach", 1)


func _on_building_changed(_idx: int) -> void:
	var gs := GameState
	var sel: String = _get_selected_building()
	# Switching away from a building with progress — confirm first
	if sel != "" and sel != gs.active_building and gs.active_building != "" and gs.active_building_progress > 0:
		_pending_building_switch = sel
		var bdef: Dictionary = gs.BUILDING_DEFS.get(gs.active_building, {})
		_confirm_dialog.dialog_text = "You have %d/%d progress on %s.\nSwitching will lose all progress. Continue?" % [
			gs.active_building_progress,
			bdef.get("build_points_required", 0),
			bdef.get("name", gs.active_building)]
		# Revert dropdown to current building until confirmed
		var revert_idx := _find_building_option_index(gs.active_building)
		building_option.select(revert_idx)
		_confirm_dialog.popup_centered()
		return
	if sel != "" and sel != gs.active_building:
		gs.active_building = sel
		gs.active_building_progress = 0
	_refresh_display()


func _find_building_option_index(building_id: String) -> int:
	for i in range(building_option.item_count):
		if str(building_option.get_item_metadata(i)) == building_id:
			return i
	return 0


func _on_switch_confirmed() -> void:
	var gs := GameState
	gs.active_building = _pending_building_switch
	gs.active_building_progress = 0
	_pending_building_switch = ""
	_populate_buildings()
	_refresh_display()


func _on_switch_canceled() -> void:
	_pending_building_switch = ""


func _on_sacrifice_changed(_idx: int) -> void:
	_refresh_display()


func _on_confirm() -> void:
	var gs := GameState
	gs.workers_on_work = _work
	gs.workers_on_build = _build
	gs.workers_on_tend = _tend
	gs.workers_on_teach = _teach
	gs.chosen_sacrifice = _get_selected_sacrifice()

	var sel_building: String = _get_selected_building()
	if sel_building != "":
		gs.active_building = sel_building

	confirm_btn.disabled = true
	allocation_confirmed.emit()
