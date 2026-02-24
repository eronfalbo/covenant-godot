extends Control
## SeasonSummary — Shows results after season resolution. Click to continue.

signal continue_pressed

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var summary_text: RichTextLabel = $VBoxContainer/SummaryPanel/SummaryText
@onready var continue_btn: Button = $VBoxContainer/ContinueButton

var _summary: Dictionary = {}


func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)


func setup(data: Dictionary) -> void:
	_summary = data.get("summary", {})
	_refresh()


func _refresh() -> void:
	var gs := GameState
	header_label.text = "%s — Year %d — Results" % [gs.current_season, gs.year]

	var parts: Array[String] = []

	# Weather
	var weather_evt: String = _summary.get("weather_event", "")
	if weather_evt != "":
		parts.append("[color=%s]%s[/color]" % [UIConstants.WARN_RED, weather_evt])
		parts.append("")

	# Food
	var fp: int = _summary.get("food_produced", 0)
	var fc: int = _summary.get("food_consumed", 0)
	var food_diff: int = _summary.get("food_after", 0) - _summary.get("food_before", 0)
	var food_color: String = UIConstants.SUCCESS_GREEN if food_diff >= 0 else UIConstants.WARN_RED
	var food_detail: String
	var food_from_tend: int = _summary.get("food_from_tend", 0)
	if food_from_tend > 0:
		food_detail = "gather +%d, tend +%d, consumed %d" % [_summary.get("food_from_gather", _summary.get("food_from_work", 0)), food_from_tend, fc]
	else:
		food_detail = "produced %d, consumed %d" % [fp, fc]
	parts.append("[color=%s]Food:[/color] %d → [color=%s]%d[/color]  (%s)" % [
		UIConstants.GOLD_HEX, _summary.get("food_before", 0), food_color, _summary.get("food_after", 0), food_detail])

	# Fire
	var fd: float = _summary.get("fire_delta", 0.0)
	var sign: String = "+" if fd >= 0 else ""
	var fire_color: String = UIConstants.SUCCESS_GREEN if fd >= 0 else UIConstants.WARN_RED
	parts.append("[color=%s]Living Fire:[/color] %.0f%% → [color=%s]%.0f%%[/color]  (%s%.0f%%)" % [
		UIConstants.GOLD_HEX, _summary.get("fire_before", 0), fire_color, _summary.get("fire_after", 0), sign, fd])

	# Building
	var bc: String = _summary.get("building_completed", "")
	if bc != "":
		var bdef: Dictionary = gs.TENT_DEFS.get(bc, {})
		var bname: String = bdef.get("name", bc)
		var bdesc: String = bdef.get("description", "")
		var bbonus: String = bdef.get("bonus_text", "")
		parts.append("")
		parts.append("[color=%s]The %s is complete.[/color]" % [UIConstants.SUCCESS_GREEN, bname])
		if bdesc != "":
			parts.append("[color=#d4c7ad]%s[/color]" % bdesc)
		if bbonus != "":
			parts.append("[color=%s]Effect: %s[/color]" % [UIConstants.GOLD_HEX, bbonus])
		parts.append("[color=#f5f2eb99]It will stand as long as the covenant holds.[/color]")
		parts.append("")
	elif _summary.get("build_progress", 0) > 0:
		var bp: int = _summary.get("build_progress", 0)
		if gs.active_building != "":
			var bdef: Dictionary = gs.TENT_DEFS.get(gs.active_building, {})
			var remaining: int = bdef.get("build_points_required", 0) - gs.active_building_progress
			parts.append("[color=%s]Build progress:[/color] +%d on %s (%d remaining)" % [
				UIConstants.GOLD_HEX, bp, bdef.get("name", gs.active_building), remaining])
		else:
			parts.append("[color=%s]Build progress:[/color] +%d points" % [UIConstants.GOLD_HEX, bp])

	# Fire breakdown
	var fire_parts: Array[String] = []
	var decay: float = _summary.get("fire_decay", 0.0)
	if decay > 0:
		fire_parts.append("[color=%s]-%.0f decay[/color]" % [UIConstants.WARN_RED, decay])
	var fire_gain: float = _summary.get("fire_gain", 0.0)
	if fire_gain > 0:
		fire_parts.append("[color=%s]+%.0f tending[/color]" % [UIConstants.SUCCESS_GREEN, fire_gain])
	var sac_fire: float = _summary.get("sacrifice_fire", 0.0)
	if sac_fire > 0:
		fire_parts.append("[color=%s]+%.0f sacrifice[/color]" % [UIConstants.SUCCESS_GREEN, sac_fire])
	var bleed_pen: float = _summary.get("bleeding_penalty", 0.0)
	if bleed_pen > 0:
		fire_parts.append("[color=%s]-%.0f bleeding[/color]" % [UIConstants.WARN_RED, bleed_pen])
	if not fire_parts.is_empty():
		parts.append("    %s" % "  ".join(fire_parts))

	# Provisions
	var prov_produced: int = _summary.get("prov_produced", 0)
	if prov_produced > 0 or _summary.get("prov_before", 0) > 0:
		var prov_after: int = _summary.get("prov_after", _summary.get("prov_before", 0))
		var prov_diff: int = prov_after - _summary.get("prov_before", 0)
		var prov_color: String = UIConstants.SUCCESS_GREEN if prov_diff >= 0 else UIConstants.WARN_RED
		var build_cost: int = _summary.get("build_prov_cost", 0)
		var prov_detail: String = "+%d produced" % prov_produced
		if build_cost > 0:
			prov_detail += ", -%d building" % build_cost
		parts.append("[color=%s]Provisions:[/color] %d → [color=%s]%d[/color]  (%s)" % [
			UIConstants.GOLD_HEX, _summary.get("prov_before", 0), prov_color, prov_after, prov_detail])

	# Livestock
	var ls_diff: int = _summary.get("livestock_after", 0) - _summary.get("livestock_before", 0)
	var ls_color: String = UIConstants.SUCCESS_GREEN if ls_diff >= 0 else UIConstants.WARN_RED
	parts.append("[color=%s]Livestock:[/color] %d → [color=%s]%d[/color]" % [
		UIConstants.GOLD_HEX, _summary.get("livestock_before", 0), ls_color, _summary.get("livestock_after", 0)])

	# Sacrifice
	var sac: String = _summary.get("sacrifice", "")
	if sac != "":
		var sdef: Dictionary = gs.SACRIFICE_DEFS.get(sac, {})
		parts.append("[color=%s]Sacrifice:[/color] %s (+%.0f%% fire)" % [UIConstants.GOLD_HEX, sdef.get("name", sac), sdef.get("fire_bonus", 0)])

	# Teaching
	var teach_gain: float = _summary.get("teach_pillar_gain", 0.0)
	if teach_gain > 0:
		var tidx: int = _summary.get("teach_pillar_idx", 0)
		parts.append("[color=%s]Teaching:[/color] %s +%.1f" % [UIConstants.GOLD_HEX, gs.PILLAR_SHORT[tidx], teach_gain])

	# Pillar rewards
	var pr: Array = _summary.get("pillar_rewards", [])
	if not pr.is_empty():
		parts.append("[color=%s]Pillar blessings:[/color] %s" % [UIConstants.GOLD_HEX, ", ".join(pr)])

	# Bleeding cured
	if _summary.get("bleeding_cured", false):
		parts.append("[color=%s]The Covering is accepted. The bleeding stops.[/color]" % UIConstants.SUCCESS_GREEN)

	# Births
	var births: int = _summary.get("births", 0)
	if births > 0:
		parts.append("[color=%s]New life:[/color] %d born this year (population now %d)" % [UIConstants.SUCCESS_GREEN, births, gs.total_bnei_brit])

	# Ham food penalty
	var ham_pen: int = _summary.get("ham_food_penalty", 0)
	if ham_pen > 0:
		parts.append("[color=%s]Ham's knowledge fades:[/color] -%d food" % [UIConstants.WARN_RED, ham_pen])

	# Japheth loyalty warning
	if gs.yephet_loyalty < 60:
		if gs.yephet_loyalty < 40:
			parts.append("[color=%s]Japheth drifts — his people no longer grow[/color]" % UIConstants.WARN_RED)
		else:
			parts.append("[color=%s]Japheth is wavering — growth slowed[/color]" % UIConstants.WARN_ORANGE)

	# Population pressure warning
	var pop_pressure: float = _summary.get("pop_pressure", 1.0)
	if pop_pressure > 1.0:
		parts.append("[color=%s]Crowding:[/color] food consumption +%d%%" % [UIConstants.WARN_RED, int((pop_pressure - 1.0) * 100)])

	# Famine warning
	if gs.food <= 0:
		var famine_turns: int = gs.flags.get("famine_turns", 0)
		if famine_turns >= 1:
			parts.append("\n[color=%s]Famine! One more season without food and the people scatter.[/color]" % UIConstants.CRITICAL_RED)

	# Bleeding warning
	if gs.bleeding_active:
		parts.append("\n[color=%s]The wound still festers. Offer a Covering to stop the bleeding.[/color]" % UIConstants.WARN_RED)

	# Game over warning
	if _summary.get("game_over", false):
		parts.append("\n[color=%s]%s[/color]" % [UIConstants.CRITICAL_RED, _summary.get("game_over_reason", "")])

	summary_text.text = "\n".join(parts)


func _on_continue() -> void:
	continue_btn.disabled = true
	continue_pressed.emit()
