extends PanelContainer
## HUDPanel — Persistent right-side panel showing game state.
## Matches Python ararat_hud() fog-of-war: numbers hidden, words only for diplomacy.
## Chain bar only visible after noah_taught_law flag.

@onready var season_label: Label = $VBoxContainer/SeasonLabel
@onready var phase_label: Label = $VBoxContainer/PhaseLabel
@onready var chain_section: VBoxContainer = $VBoxContainer/ChainSection
@onready var chain_bar: ProgressBar = $VBoxContainer/ChainSection/ChainBar
@onready var chain_label: Label = $VBoxContainer/ChainSection/ChainLabel
@onready var chain_title: Label = $VBoxContainer/ChainSection/ChainTitle
@onready var provision_label: Label = $VBoxContainer/StatsSection/ProvisionValue
@onready var population_label: Label = $VBoxContainer/StatsSection/PopulationValue
@onready var livestock_label: Label = $VBoxContainer/StatsSection/LivestockValue
@onready var food_label: Label = $VBoxContainer/StatsSection/FoodValue
@onready var shem_label: Label = $VBoxContainer/DiplomacySection/ShemValue
@onready var ham_label: Label = $VBoxContainer/DiplomacySection/HamValue
@onready var japheth_label: Label = $VBoxContainer/DiplomacySection/JaphethValue
@onready var moon_label: Label = $VBoxContainer/MoonLabel


func _ready() -> void:
	GameState.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var gs := GameState
	season_label.text = "%s — Year %d" % [gs.current_season, gs.year]
	phase_label.text = gs.phase.capitalize()

	# The Living Fire — visible after seventh_law_taught or noah_taught_law
	# Python gates on noah_taught_law (A06), but we show it after A01b too
	var show_chain: bool = (
		gs.flags.get("seventh_law_taught", false) == true or
		gs.flags.get("noah_taught_law", false) == true
	)
	chain_section.visible = show_chain
	if show_chain:
		chain_bar.value = gs.living_fire
		chain_label.text = "%.0f%% — %s" % [gs.living_fire, gs.tzohar_status]

		# Color chain bar by tier
		var bar_style := chain_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		if gs.living_fire >= 80:
			bar_style.bg_color = Color(0.788, 0.663, 0.384, 1)
		elif gs.living_fire >= 50:
			bar_style.bg_color = Color(0.7, 0.6, 0.3, 1)
		elif gs.living_fire >= 25:
			bar_style.bg_color = Color(0.8, 0.4, 0.2, 1)
		else:
			bar_style.bg_color = Color(0.5, 0.2, 0.2, 1)
		chain_bar.add_theme_stylebox_override("fill", bar_style)

	# Stats — Python shows "Souls: 8  Livestock: 30  Food: 20"
	population_label.text = "%d souls" % gs.total_bnei_brit
	livestock_label.text = str(gs.livestock)
	food_label.text = str(gs.food)
	provision_label.text = gs.provision_label

	# Diplomacy — fog of war: words only, no numbers
	shem_label.text = gs.shem_relation_label
	ham_label.text = gs.ham_relation_label
	japheth_label.text = gs.japheth_relation_label

	moon_label.text = gs.current_moon
