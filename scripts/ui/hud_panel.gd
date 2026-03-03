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

# Track previous values for flash animations
var _prev_fire: float = -1.0
var _prev_food: int = -1
var _prev_livestock: int = -1

# Dynamic HUD sections (created in _ready)
var _buildings_sep: HSeparator = null
var _buildings_label: RichTextLabel = null
var _forces_sep: HSeparator = null
var _assim_key: Label = null
var _assim_value: Label = null
var _hostility_key: Label = null
var _hostility_value: Label = null


func _ready() -> void:
	GameState.state_changed.connect(_refresh)

	# Create forces section (assimilation + hostility) after diplomacy
	_forces_sep = HSeparator.new()
	$VBoxContainer.add_child(_forces_sep)
	$VBoxContainer.move_child(_forces_sep, $VBoxContainer.get_child_count() - 2)  # before Spacer

	_assim_key = _make_key_label("Outwardness")
	$VBoxContainer.add_child(_assim_key)
	$VBoxContainer.move_child(_assim_key, _forces_sep.get_index() + 1)

	_assim_value = _make_value_label("")
	$VBoxContainer.add_child(_assim_value)
	$VBoxContainer.move_child(_assim_value, _assim_key.get_index() + 1)

	_hostility_key = _make_key_label("Elements")
	$VBoxContainer.add_child(_hostility_key)
	$VBoxContainer.move_child(_hostility_key, _assim_value.get_index() + 1)

	_hostility_value = _make_value_label("")
	$VBoxContainer.add_child(_hostility_value)
	$VBoxContainer.move_child(_hostility_value, _hostility_key.get_index() + 1)

	# Create buildings section at bottom of HUD
	_buildings_sep = HSeparator.new()
	_buildings_sep.visible = false
	$VBoxContainer.add_child(_buildings_sep)
	_buildings_label = RichTextLabel.new()
	_buildings_label.bbcode_enabled = true
	_buildings_label.fit_content = true
	_buildings_label.scroll_active = false
	_buildings_label.add_theme_font_size_override("normal_font_size", UIConstants.LABEL_SIZE)
	_buildings_label.add_theme_color_override("default_color", UIConstants.IVORY_BODY)
	_buildings_label.visible = false
	$VBoxContainer.add_child(_buildings_label)
	_refresh()


func _refresh() -> void:
	var gs := GameState
	season_label.text = "%s — Year %d" % [gs.current_season, gs.year]
	phase_label.text = gs.phase.capitalize()

	# The Tree of Life — visible after seventh_law_taught or noah_taught_law
	var show_chain: bool = (
		gs.flags.get("seventh_law_taught", false) == true or
		gs.flags.get("noah_taught_law", false) == true
	)
	chain_section.visible = show_chain
	if show_chain:
		# Tween the bar value for smooth animation
		var target_val: float = gs.tree_of_life
		if abs(chain_bar.value - target_val) > 0.5:
			var tw := create_tween()
			tw.tween_property(chain_bar, "value", target_val, UIConstants.FIRE_TWEEN_DURATION)
		else:
			chain_bar.value = target_val
		chain_label.text = "%.0f%% — %s" % [gs.tree_of_life, gs.tzohar_status]

		# Color chain bar by tier
		var bar_style := chain_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		if gs.tree_of_life >= 80:
			bar_style.bg_color = UIConstants.FIRE_COLOR_BRIGHT
		elif gs.tree_of_life >= 50:
			bar_style.bg_color = UIConstants.FIRE_COLOR_STEADY
		elif gs.tree_of_life >= 25:
			bar_style.bg_color = UIConstants.FIRE_COLOR_FLICKER
		else:
			bar_style.bg_color = UIConstants.FIRE_COLOR_EMBERS
		chain_bar.add_theme_stylebox_override("fill", bar_style)

		# Flash fire label on change
		if _prev_fire >= 0 and abs(_prev_fire - gs.tree_of_life) > 0.5:
			_flash_label(chain_label)
		_prev_fire = gs.tree_of_life

	# Stats
	population_label.text = "%d %s" % [gs.total_bnei_brit, "soul" if gs.total_bnei_brit == 1 else "souls"]
	livestock_label.text = str(gs.livestock)
	food_label.text = str(gs.food)
	provision_label.text = gs.provision_label

	# Flash food/livestock on change
	if _prev_food >= 0 and _prev_food != gs.food:
		_flash_label(food_label)
	if _prev_livestock >= 0 and _prev_livestock != gs.livestock:
		_flash_label(livestock_label)
	_prev_food = gs.food
	_prev_livestock = gs.livestock

	# Diplomacy — fog of war: words only, no numbers
	shem_label.text = gs.shem_relation_label
	ham_label.text = gs.ham_relation_label
	japheth_label.text = gs.japheth_relation_label

	moon_label.text = gs.current_moon

	# Assimilation & Hostility — the two forces
	if _assim_key and _assim_value:
		_assim_key.text = gs.assimilation_stage_name
		_assim_value.text = gs.assimilation_label
		# Color shifts as assimilation rises
		if gs.assimilation >= 10:
			_assim_value.add_theme_color_override("font_color", UIConstants.GOLD)
		else:
			_assim_value.add_theme_color_override("font_color", UIConstants.IVORY)

	if _hostility_key and _hostility_value:
		_hostility_key.text = gs.hostility_stage_name
		_hostility_value.text = gs.hostility_label
		# Red flash during spikes
		if gs.hostility_spike_seasons > 0:
			_hostility_value.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
		elif gs.hostility >= 6:
			_hostility_value.add_theme_color_override("font_color", UIConstants.GOLD)
		else:
			_hostility_value.add_theme_color_override("font_color", UIConstants.IVORY)

	# Buildings
	if _buildings_label:
		var has_buildings: bool = not gs.buildings_completed.is_empty()
		_buildings_sep.visible = has_buildings
		_buildings_label.visible = has_buildings
		if has_buildings:
			var lines: Array[String] = ["[color=%s]Tents:[/color]" % UIConstants.GOLD_HEX]
			for bid in gs.buildings_completed:
				var bdef: Dictionary = gs.TENT_DEFS.get(bid, {})
				lines.append("  [color=%s]%s[/color]" % [UIConstants.SUCCESS_GREEN, bdef.get("name", bid)])
			_buildings_label.text = "\n".join(lines)


func _make_key_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UIConstants.LABEL_SIZE)
	l.add_theme_color_override("font_color", UIConstants.IVORY_MUTED)
	return l


func _make_value_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UIConstants.BODY_SMALL_SIZE)
	l.add_theme_color_override("font_color", UIConstants.IVORY)
	return l


func _flash_label(label: Label) -> void:
	## Brief gold flash then back to ivory.
	label.add_theme_color_override("font_color", UIConstants.GOLD)
	var tw := create_tween()
	tw.tween_callback(func(): label.add_theme_color_override("font_color", UIConstants.IVORY)).set_delay(UIConstants.RESOURCE_FLASH_DURATION)
