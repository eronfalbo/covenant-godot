extends Control
## AllocationScreen — Player distributes labor via percentage sliders.

signal allocation_confirmed

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var status_label: RichTextLabel = $VBoxContainer/StatusPanel/StatusText
@onready var alloc_panel: VBoxContainer = $VBoxContainer/AllocationPanel
@onready var forecast_label: RichTextLabel = $VBoxContainer/ForecastPanel/ForecastText
@onready var sacrifice_option: OptionButton = $VBoxContainer/SacrificeRow/SacrificeOption
@onready var building_option: OptionButton = $VBoxContainer/BuildingRow/BuildingOption
@onready var confirm_btn: Button = $VBoxContainer/ConfirmButton

# Slot definitions: key, display name
const SLOT_ORDER := ["gather", "build", "tend", "teach", "work"]
const SLOT_NAMES := {
	"gather": "Gather",
	"work": "Work",
	"build": "Build",
	"tend": "Tend",
	"teach": "Teach",
}

var _sliders: Dictionary = {}  # slot -> HSlider
var _pct_labels: Dictionary = {}  # slot -> Label (shows "50% (4)")
var _rows: Dictionary = {}  # slot -> HBoxContainer
var _adjusting: bool = false  # prevent recursive slider updates

# Switch confirmation
var _pending_building_switch: String = ""
var _confirm_dialog: ConfirmationDialog = null


func _ready() -> void:
	print("[ALLOC] _ready start")
	confirm_btn.pressed.connect(_on_confirm)
	sacrifice_option.item_selected.connect(_on_sacrifice_changed)
	building_option.item_selected.connect(_on_building_changed)

	# Create slider rows dynamically
	for slot in SLOT_ORDER:
		var row := _create_slider_row(slot)
		alloc_panel.add_child(row)
		_rows[slot] = row

	# Switch confirmation dialog
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Abandon progress?"
	_confirm_dialog.confirmed.connect(_on_switch_confirmed)
	_confirm_dialog.canceled.connect(_on_switch_canceled)
	add_child(_confirm_dialog)

	# Add reset button before confirm
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.add_theme_font_size_override("font_size", UIConstants.BODY_SMALL_SIZE)
	reset_btn.pressed.connect(_on_reset)
	confirm_btn.get_parent().add_child(reset_btn)
	confirm_btn.get_parent().move_child(reset_btn, confirm_btn.get_index())

	_setup_allocation()


func setup(_data: Dictionary) -> void:
	pass


func _setup_allocation() -> void:
	print("[ALLOC] _setup_allocation start")
	var gs := GameState
	header_label.text = "%s — Year %d" % [gs.current_season, gs.year]
	print("[ALLOC] Y%d S%d pop=%d fire=%.0f avail=%d alloc_pct=%s" % [gs.year, gs.season_idx, gs.total_bnei_brit, gs.living_fire, gs.effective_allocatable, str(gs.alloc_pct)])

	# Initialize sliders from GameState percentages
	_adjusting = true
	for slot in SLOT_ORDER:
		if _sliders.has(slot):
			_sliders[slot].value = gs.alloc_pct.get(slot, 0.0) * 100.0
			print("[ALLOC] slider %s = %.0f" % [slot, _sliders[slot].value])
	_adjusting = false

	# Slot visibility
	_rows["work"].visible = gs.has_building("tent_tubal_cain")

	_populate_buildings()
	_populate_sacrifices()
	print("[ALLOC] calling _refresh_display")
	_refresh_display()
	print("[ALLOC] _setup_allocation done, confirm_btn.disabled=%s" % str(confirm_btn.disabled))


func _create_slider_row(slot: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sRow" % slot.capitalize()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = SLOT_NAMES.get(slot, slot) + ":"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", UIConstants.BODY_SIZE)
	name_lbl.add_theme_color_override("font_color", UIConstants.GOLD)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = 0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(_on_slider_changed.bind(slot))
	row.add_child(slider)
	_sliders[slot] = slider

	var pct_lbl := Label.new()
	pct_lbl.text = "0% (0)"
	pct_lbl.custom_minimum_size = Vector2(120, 0)
	pct_lbl.add_theme_font_size_override("font_size", UIConstants.BODY_SIZE)
	pct_lbl.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92, 0.8))
	row.add_child(pct_lbl)
	_pct_labels[slot] = pct_lbl

	return row


func _on_slider_changed(value: float, slot: String) -> void:
	if _adjusting:
		return
	_adjusting = true

	# Get current total of OTHER visible slots
	var other_total: float = 0.0
	var visible_slots: Array[String] = []
	for s in SLOT_ORDER:
		if s != slot and _rows.get(s, null) != null and _rows[s].visible:
			visible_slots.append(s)
			other_total += _sliders[s].value

	var new_total: float = value + other_total
	if new_total > 100.0:
		# Proportionally shrink other slots
		var excess: float = new_total - 100.0
		if other_total > 0:
			for s in visible_slots:
				var share: float = _sliders[s].value / other_total
				_sliders[s].value = maxf(_sliders[s].value - excess * share, 0)
		else:
			# All others are 0, cap this slider
			_sliders[slot].value = 100.0

	_adjusting = false
	_refresh_display()


func _get_pct() -> Dictionary:
	## Read current slider values into a percentage dictionary (0.0-1.0).
	var pct: Dictionary = {}
	var total: float = 0.0
	for slot in SLOT_ORDER:
		if _rows.get(slot, null) != null and _rows[slot].visible:
			pct[slot] = _sliders[slot].value / 100.0
			total += pct[slot]
		else:
			pct[slot] = 0.0
	# Normalize to exactly 1.0
	if total > 0 and absf(total - 1.0) > 0.001:
		for slot in pct:
			pct[slot] /= total
	return pct


func _populate_buildings() -> void:
	building_option.clear()
	building_option.add_item("— None —", 0)
	var gs := GameState
	var available := gs.get_available_buildings()

	if gs.active_building != "":
		var bdef: Dictionary = gs.TENT_DEFS.get(gs.active_building, {})
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
			var bd: Dictionary = gs.TENT_DEFS.get(bid, {})
			var bonus: String = bd.get("bonus_text", "")
			var prov_cost: int = bd.get("provision_cost", 0)
			var blabel := "%s (0/%d, %d prov)" % [bd.get("name", bid), bd.get("build_points_required", 0), prov_cost]
			if bonus != "":
				blabel += " — " + bonus
			building_option.add_item(blabel, idx)
			building_option.set_item_metadata(idx, bid)
			idx += 1
	else:
		var idx := 1
		for bid in available:
			var bd: Dictionary = gs.TENT_DEFS.get(bid, {})
			var bonus: String = bd.get("bonus_text", "")
			var prov_cost: int = bd.get("provision_cost", 0)
			var blabel := "%s (0/%d, %d prov)" % [bd.get("name", bid), bd.get("build_points_required", 0), prov_cost]
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
	if building_option.selected <= 0:
		return ""
	return str(building_option.get_item_metadata(building_option.selected))


func _get_selected_sacrifice() -> String:
	var sel := sacrifice_option.selected
	if sel <= 0:
		return ""
	return str(sacrifice_option.get_item_metadata(sel))


func _refresh_display() -> void:
	var gs := GameState
	var pct := _get_pct()
	var available: int = gs.effective_allocatable

	# Update slider labels with worker counts
	for slot in SLOT_ORDER:
		if not _pct_labels.has(slot):
			continue
		var count: int = int(round(pct.get(slot, 0.0) * available))
		var pct_val: int = int(round(pct.get(slot, 0.0) * 100))
		_pct_labels[slot].text = "%d%% (%d)" % [pct_val, count]

	# Status section
	var status_parts: Array[String] = []
	if gs.year == 0 and gs.season_idx == 0:
		status_parts.append("[color=%s]First Season — Assign Your Family[/color]" % UIConstants.GOLD_HEX)
		status_parts.append("[b]Gather[/b] finds food    [b]Build[/b] raises tents    [b]Tend[/b] cares for fire + livestock    [b]Teach[/b] preserves the covenant")
		status_parts.append("")
	status_parts.append("[color=%s]Living Fire:[/color] %.0f%% (%s)" % [UIConstants.GOLD_HEX, gs.living_fire, gs.tzohar_status])
	status_parts.append("[color=%s]Souls:[/color] %d    [color=%s]Food:[/color] %d/%d    [color=%s]Livestock:[/color] %d    [color=%s]Provisions:[/color] %s" % [
		UIConstants.GOLD_HEX, gs.total_bnei_brit,
		UIConstants.GOLD_HEX, gs.food, gs.food_cap,
		UIConstants.GOLD_HEX, gs.livestock,
		UIConstants.GOLD_HEX, gs.provision_label])
	status_parts.append("[color=%s]Available Labor:[/color] %d of %d (fire x population)" % [UIConstants.GOLD_HEX, available, gs.total_bnei_brit])
	if gs.tent_scene_occurred and gs.ham_drift_penalty > 0:
		status_parts.append("[color=%s]Ham is distant — effective labor reduced[/color]" % UIConstants.WARN_ORANGE)
	if gs.yephet_loyalty < 100:
		var loyalty_color: String = UIConstants.SUCCESS_GREEN if gs.yephet_loyalty >= 60 else (UIConstants.WARN_ORANGE if gs.yephet_loyalty >= 40 else UIConstants.WARN_RED)
		status_parts.append("[color=%s]Japheth Loyalty:[/color] [color=%s]%d%%[/color]" % [UIConstants.GOLD_HEX, loyalty_color, gs.yephet_loyalty])
	if gs.bleeding_active:
		status_parts.append("[color=%s]The wound festers — extra fire loss each season[/color]" % UIConstants.WARN_RED)
	if not gs.buildings_completed.is_empty():
		var blines: Array[String] = []
		for bid in gs.buildings_completed:
			var bdef: Dictionary = gs.TENT_DEFS.get(bid, {})
			blines.append("[color=%s]%s[/color]: %s" % [UIConstants.SUCCESS_GREEN, bdef.get("name", bid), bdef.get("bonus_text", "")])
		status_parts.append("[color=%s]Tents:[/color] %s" % [UIConstants.GOLD_HEX, "  |  ".join(blines)])
	status_label.text = "\n".join(status_parts)

	# Forecast
	var sacrifice_id: String = _get_selected_sacrifice()
	var fc: Dictionary = SeasonResolver.forecast(gs, pct, sacrifice_id)

	var fc_parts: Array[String] = []
	var food_delta: int = fc["food_forecast"] - gs.food
	var food_color: String = UIConstants.SUCCESS_GREEN if food_delta >= 0 else UIConstants.WARN_RED
	var food_detail: String
	var food_from_tend: int = fc.get("food_from_tend", 0)
	if food_from_tend > 0:
		food_detail = "gather +%d, tend +%d, consumed %d" % [fc.get("food_from_gather", 0), food_from_tend, fc["food_consumed"]]
	else:
		food_detail = "produced %d, consumed %d" % [fc["food_produced"], fc["food_consumed"]]
	fc_parts.append("[color=%s]Food:[/color] %d → [color=%s]%d[/color]  (%s)" % [
		UIConstants.GOLD_HEX, gs.food, food_color, fc["food_forecast"], food_detail])

	# Provisions forecast
	var prov_produced: int = fc.get("prov_produced", 0)
	if prov_produced > 0 or gs.provision > 0:
		var prov_delta: int = fc.get("prov_forecast", gs.provision) - gs.provision
		var prov_color: String = UIConstants.SUCCESS_GREEN if prov_delta >= 0 else UIConstants.WARN_RED
		fc_parts.append("[color=%s]Provisions:[/color] %d → [color=%s]%d[/color]  (+%d produced)" % [
			UIConstants.GOLD_HEX, gs.provision, prov_color, fc.get("prov_forecast", gs.provision), prov_produced])

	var fire_delta: float = fc["fire_delta"]
	var fire_color: String = UIConstants.SUCCESS_GREEN if fire_delta >= 0 else UIConstants.WARN_RED
	var fire_sign: String = "+" if fire_delta >= 0 else ""
	fc_parts.append("[color=%s]Fire:[/color] %.0f%% → [color=%s]%.0f%%[/color]  (%s%.0f%%)" % [
		UIConstants.GOLD_HEX, gs.living_fire, fire_color, fc["fire_forecast"], fire_sign, fire_delta])

	var sel_bid: String = _get_selected_building()
	if sel_bid != "":
		var bdef: Dictionary = gs.TENT_DEFS.get(sel_bid, {})
		var current_progress: int = gs.active_building_progress if sel_bid == gs.active_building else 0
		var bp_after: int = current_progress + fc["build_progress"]
		var required: int = bdef.get("build_points_required", 0)
		var complete_text: String = " [color=%s]COMPLETE![/color]" % UIConstants.SUCCESS_GREEN if bp_after >= required else ""
		fc_parts.append("[color=%s]Build:[/color] %s %d/%d%s" % [
			UIConstants.GOLD_HEX, bdef.get("name", sel_bid), bp_after, required, complete_text])
		if fc["build_progress"] == 0 and pct.get("build", 0.0) > 0:
			if gs.provision < gs.BUILD_PROVISION_COST:
				fc_parts.append("[color=%s]No provisions — building stalled[/color]" % UIConstants.WARN_RED)

	fc_parts.append("[color=%s]Livestock:[/color] %d → %d" % [UIConstants.GOLD_HEX, gs.livestock, fc["livestock_forecast"]])

	# Teaching preview
	var workers_data: Dictionary = fc.get("workers", {})
	var teach_count: int = workers_data.get("teach", 0)
	if teach_count > 0:
		var teach_gain: float = pow(maxf(teach_count, 0), 0.85) * 0.15
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
	var total_pct: float = 0.0
	for slot in pct:
		total_pct += pct[slot]
	var valid: bool = total_pct > 0.99  # sliders sum to ~100%
	print("[ALLOC] validation: total_pct=%.3f valid=%s" % [total_pct, str(valid)])
	var build_pct: float = pct.get("build", 0.0)
	var build_workers: int = int(round(build_pct * available))
	if build_workers > 0 and build_workers < gs.MIN_BUILDERS:
		valid = false
		forecast_label.text += "\n[color=%s]Need at least %d builders for progress[/color]" % [UIConstants.WARN_RED, gs.MIN_BUILDERS]
	if build_workers >= gs.MIN_BUILDERS and sel_bid == "":
		forecast_label.text += "\n[color=%s]Builders ready — choose a project above[/color]" % UIConstants.WARN_ORANGE
	var gather_workers: int = int(round(pct.get("gather", 0.0) * available))
	if gather_workers == 0:
		forecast_label.text += "\n[color=%s]Warning: No food production this season[/color]" % UIConstants.WARN_ORANGE
	if teach_count == 0 and gs.year > 0:
		forecast_label.text += "\n[color=%s]No one is teaching — the pillars weaken[/color]" % UIConstants.WARN_ORANGE
	confirm_btn.disabled = not valid


func _on_reset() -> void:
	_adjusting = true
	for slot in SLOT_ORDER:
		if _sliders.has(slot):
			_sliders[slot].value = 0
	_sliders["gather"].value = 50
	_sliders["tend"].value = 25
	_sliders["teach"].value = 25
	_adjusting = false
	building_option.select(0)
	_refresh_display()


func _on_building_changed(_idx: int) -> void:
	var gs := GameState
	var sel: String = _get_selected_building()
	if sel != "" and sel != gs.active_building and gs.active_building != "" and gs.active_building_progress > 0:
		_pending_building_switch = sel
		var bdef: Dictionary = gs.TENT_DEFS.get(gs.active_building, {})
		_confirm_dialog.dialog_text = "You have %d/%d progress on %s.\nSwitching will lose all progress. Continue?" % [
			gs.active_building_progress,
			bdef.get("build_points_required", 0),
			bdef.get("name", gs.active_building)]
		var revert_idx := _find_building_option_index(gs.active_building)
		building_option.select(revert_idx)
		_confirm_dialog.popup_centered()
		return
	if sel != "" and sel != gs.active_building:
		gs.start_building(sel)
		_populate_buildings()
	_refresh_display()


func _find_building_option_index(building_id: String) -> int:
	for i in range(building_option.item_count):
		if str(building_option.get_item_metadata(i)) == building_id:
			return i
	return 0


func _on_switch_confirmed() -> void:
	var gs := GameState
	gs.start_building(_pending_building_switch)
	_pending_building_switch = ""
	_populate_buildings()
	_refresh_display()


func _on_switch_canceled() -> void:
	_pending_building_switch = ""


func _on_sacrifice_changed(_idx: int) -> void:
	_refresh_display()


func _unhandled_input(event: InputEvent) -> void:
	# DEBUG: F10 triggers confirm
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		if not confirm_btn.disabled:
			_on_confirm()


func _on_confirm() -> void:
	print("[ALLOC] Confirm pressed!")
	var gs := GameState
	var pct := _get_pct()
	print("[ALLOC] pct=%s sacrifice=%s" % [str(pct), _get_selected_sacrifice()])
	gs.alloc_pct = pct
	gs.chosen_sacrifice = _get_selected_sacrifice()

	var sel_building: String = _get_selected_building()
	if sel_building != "" and sel_building != gs.active_building:
		gs.start_building(sel_building)

	confirm_btn.disabled = true
	print("[ALLOC] Emitting allocation_confirmed")
	allocation_confirmed.emit()
