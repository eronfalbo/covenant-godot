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

	# Food
	var fp: int = _summary.get("food_produced", 0)
	var fc: int = _summary.get("food_consumed", 0)
	parts.append("[color=#c9a962]Food:[/color] %d → %d  (produced %d, consumed %d)" % [
		_summary.get("food_before", 0), _summary.get("food_after", 0), fp, fc])

	# Fire
	var fd: float = _summary.get("fire_delta", 0.0)
	var sign: String = "+" if fd >= 0 else ""
	parts.append("[color=#c9a962]Living Fire:[/color] %.0f%% → %.0f%%  (%s%.0f%%)" % [
		_summary.get("fire_before", 0), _summary.get("fire_after", 0), sign, fd])

	# Building
	var bc: String = _summary.get("building_completed", "")
	if bc != "":
		var bdef: Dictionary = gs.BUILDING_DEFS.get(bc, {})
		parts.append("[color=#44cc44]Building complete:[/color] %s" % bdef.get("name", bc))
	elif _summary.get("build_progress", 0) > 0:
		parts.append("[color=#c9a962]Build progress:[/color] +%d points" % _summary.get("build_progress", 0))

	# Livestock
	parts.append("[color=#c9a962]Livestock:[/color] %d → %d" % [
		_summary.get("livestock_before", 0), _summary.get("livestock_after", 0)])

	# Sacrifice
	var sac: String = _summary.get("sacrifice", "")
	if sac != "":
		var sdef: Dictionary = gs.SACRIFICE_DEFS.get(sac, {})
		parts.append("[color=#c9a962]Sacrifice:[/color] %s (+%.0f%% fire)" % [sdef.get("name", sac), sdef.get("fire_bonus", 0)])

	# Bleeding warning
	if gs.bleeding_active:
		parts.append("\n[color=#cc4444]The wound still festers. Offer a Covering to stop the bleeding.[/color]")

	# Game over warning
	if _summary.get("game_over", false):
		parts.append("\n[color=#cc2222]%s[/color]" % _summary.get("game_over_reason", ""))

	summary_text.text = "\n".join(parts)


func _on_continue() -> void:
	continue_btn.disabled = true
	continue_pressed.emit()
