extends Node
## GameState — The singleton. All game data lives here.
## Direct port of Python GameState.__init__ from covenant.py.

# ── Signals ──
signal state_changed
signal flag_set(flag_name: String, value: Variant)

# ── Constants ──
const SEASONS := ["Autumn", "Winter", "Spring", "Summer"]

const MOONS := {
	"Spring": ["Moon of Light", "Moon of Purification", "Moon of the Covenant"],
	"Summer": ["Moon of Cain", "Moon of Abel", "Moon of Seth"],
	"Autumn": ["Moon of Reckoning", "Moon of Tents", "Moon of Rain"],
	"Winter": ["Moon of Fire", "Moon of Land", "Moon of Three Trees"],
}

const FESTIVAL_NAMES := {
	"Spring": "Festival of the Covenant",
	"Summer": "Mourning of Abel",
	"Autumn": "Days of Silence & Festival of Tents",
	"Winter": "Fast of Adam & Festival of Light",
}

const PILLAR_NAMES := [
	"Star Watch", "Altar Road", "Sacrificial Order", "Holy Tongue",
	"Festival Calendar", "Sacred Objects", "Teaching Network", "The Stories",
]

const PILLAR_SHORT := ["Stars", "Road", "Ritual", "Tongue", "Calendar", "Objects", "Teachers", "Stories"]
const PILLAR_STARTING := [7.0, 7.0, 8.0, 9.0, 7.0, 6.0, 6.0, 8.0]

const FIRE_BURNING_BRIGHT := 80
const FIRE_STEADY := 50
const FIRE_FLICKERING := 25

const BAAL_STAGES := [
	{"name": "Gathering", "threshold": 0, "label": "Market camps, paths worn into the dust"},
	{"name": "Naming", "threshold": 20, "label": "The settlement has a name. People say they belong to it."},
	{"name": "Walling", "threshold": 40, "label": "Walls rise. Us and them."},
	{"name": "Enthroning", "threshold": 60, "label": "A man crowned. All knees bend to one throne."},
	{"name": "Consecrating", "threshold": 80, "label": "A temple rises. The city is complete."},
]

const PROFESSIONS := {
	"Shepherd": {"tent": "Tent of Abel", "food_prod": 0.5, "consumption": 1.0, "assim_risk": 0.00, "unity": 2, "provision": 0, "train_time": 1},
	"Livestock Breeder": {"tent": "Tent of Jabal", "food_prod": 0.0, "consumption": 1.0, "assim_risk": 0.00, "unity": 1, "provision": 0, "train_time": 2},
	"Tiller": {"tent": "Tent of Cain", "food_prod": 4.0, "consumption": 1.0, "assim_risk": 0.02, "unity": 0, "provision": 0, "train_time": 1},
	"Wine Maker": {"tent": "Tent of Noah", "food_prod": 0.0, "consumption": 1.0, "assim_risk": 0.01, "unity": 0, "provision": 1, "train_time": 2},
	"Clothes Maker": {"tent": "Tent of Eve", "food_prod": 0.0, "consumption": 1.0, "assim_risk": 0.00, "unity": 0, "provision": 2, "train_time": 1},
	"Musician": {"tent": "Tent of Jabal", "food_prod": 0.0, "consumption": 1.0, "assim_risk": 0.01, "unity": 3, "provision": 1, "train_time": 2},
	"Builder": {"tent": "Tent of Cain", "food_prod": 0.0, "consumption": 1.2, "assim_risk": 0.02, "unity": 0, "provision": 1, "train_time": 2},
	"Warrior": {"tent": "Tent of Tubal-Cain", "food_prod": 0.0, "consumption": 1.5, "assim_risk": 0.00, "unity": -1, "provision": 0, "train_time": 2},
}

const TENT_COSTS := {
	"Tent of Chanoch": {"livestock": 8, "builder_years": 2},
	"Tent of Abel": {"livestock": 5, "builder_years": 1},
	"Tent of Jabal": {"livestock": 5, "builder_years": 1},
	"Tent of Noah": {"livestock": 3, "builder_years": 1},
	"Tent of Eve": {"livestock": 3, "builder_years": 1},
	"Tent of Cain": {"livestock": 5, "builder_years": 2},
	"Tent of Tubal-Cain": {"livestock": 8, "builder_years": 3},
	"Second Settlement": {"livestock": 20, "builder_years": 5},
	"Altar Expansion": {"livestock": 15, "builder_years": 4},
}

const FESTIVAL_SCALES := {
	"Skip": {"livestock": 0, "wine": 0, "food": 0, "chain": -2, "diplo": -5},
	"Minimal": {"livestock": 3, "wine": 1, "food": 5, "chain": 0, "diplo": -3},
	"Standard": {"livestock": 8, "wine": 3, "food": 10, "chain": 1, "diplo": 2},
	"Grand": {"livestock": 15, "wine": 5, "food": 20, "chain": 2, "diplo": 5},
}

const STARTING_PROFESSIONS := {
	"Shepherd": 3, "Tiller": 2, "Clothes Maker": 1, "Builder": 1, "Livestock Breeder": 1,
}

const BC_ASSIGNMENTS := [
	"Teaching", "Star Watch", "Ritual", "Diplomacy", "Patrol", "Research",
]

const SABBATH_CYCLE := 7

const SALEM_FOOD_TARGET := 200
const SALEM_LIVESTOCK_TARGET := 100
const SALEM_POP_TARGET := 50
const SALEM_BC_TARGET := 10

# ── Time ──
var year: int = 0
var season_idx: int = 0
var act: int = 1
var phase: String = "ararat"

# ── Resources ──
var livestock: int = 30
var food: int = 20
var wine: int = 0
var provision: int = 80

# ── Population ──
var bnei_brit_shem: int = 4
var bnei_brit_ham: int = 2
var bnei_brit_yephet: int = 2
var sojourners: int = 0
var initiates: int = 0
var drifters_known: int = 0
var drifters_estimated: int = 0
var bnei_baal: int = 0
var bnei_elohim: Dictionary = {
	"uncontacted": 5000,
	"sojourning": 0,
	"initiating": 0,
	"captured": 0,
	"nephilim": 0,
}

# ── Professions (Phase B) ──
var professions: Dictionary = {}
var profession_targets: Dictionary = {}
var unspecialised: int = 0

# ── Institutional ──
var teva_count: int = 0
var teva_training: int = 0
var teva_training_years: Dictionary = {}
var bc_count: int = 0
var bc_assignments: Array = []
var bc_next_id: int = 1
var bc_training_count: int = 0
var active_arev: int = 0
var active_initiations: int = 0
var initiation_years: Dictionary = {}
var bc_community: Dictionary = {"Shem": 0, "Ham": 0, "Japheth": 0}

# ── Chain Integrity ──
var chain_integrity: float = 85.0
var babel_penalties_this_year: int = 0

# ── Eight Pillars ──
var pillars: Array[float] = [7.0, 7.0, 8.0, 9.0, 7.0, 6.0, 6.0, 8.0]
var pillar_neglect_years: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]

# ── Diplomatic ──
var ham_centralisation: int = 0
var ham_relation: int = 90
var yephet_loyalty: int = 90

# ── Flags ──
var flags: Dictionary = {}

# ── Buildings ──
var tents_built: Array[String] = []
var building_projects: Array[Dictionary] = []

# ── Festival tracking ──
var festivals_this_year: Array[String] = []
var festivals_skipped_this_year: int = 0
var offering_quality: String = ""
var clan_fires_lit: int = 0
var clan_fires_total: int = 0
var unresolved_injustices: int = 0
var redistribution_done: bool = false
var seven_words_hollow: int = 0

# ── Event tracking ──
var events_fired: Array[String] = []
var event_last_fired: Dictionary = {}
var events_this_season: Array[Dictionary] = []

# ── Game state ──
var game_over: bool = false
var game_over_reason: String = ""
var victory: bool = false

# ── Yearly accumulators ──
var yearly_food_produced: float = 0
var yearly_food_consumed: float = 0
var yearly_livestock_growth: float = 0
var yearly_drifters_lost: int = 0
var yearly_drifters_reclaimed: int = 0
var yearly_bc_graduated: int = 0
var yearly_initiations_completed: int = 0
var yearly_elohim_log: Array[String] = []


# ── Computed Properties ──

var total_bnei_brit: int:
	get: return bnei_brit_shem + bnei_brit_ham + bnei_brit_yephet

var total_population: int:
	get: return (total_bnei_brit + sojourners + initiates +
		drifters_known + bnei_baal +
		bnei_elohim.get("captured", 0) + bnei_elohim.get("nephilim", 0))

var fire_tier: String:
	get:
		if chain_integrity >= FIRE_BURNING_BRIGHT: return "Burning Bright"
		elif chain_integrity >= FIRE_STEADY: return "Steady Flame"
		elif chain_integrity >= FIRE_FLICKERING: return "Flickering"
		else: return "Embers"

var baal_stage: int:
	get:
		for i in range(BAAL_STAGES.size() - 1, -1, -1):
			if ham_centralisation >= BAAL_STAGES[i]["threshold"]:
				return i
		return 0

var baal_stage_name: String:
	get: return BAAL_STAGES[baal_stage]["name"]

var baal_stage_label: String:
	get: return BAAL_STAGES[baal_stage]["label"]

var provision_label: String:
	get:
		if provision >= 80: return "Fat and well-fed"
		elif provision >= 50: return "Fed and clothed"
		elif provision >= 30: return "Lean"
		else: return "Suffering"

var current_season: String:
	get: return SEASONS[season_idx]

var current_moon: String:
	get: return MOONS[current_season][0]

var shem_relation_label: String:
	get: return "steadfast"

var ham_relation_label: String:
	get:
		if ham_relation >= 80: return "close"
		elif ham_relation >= 60: return "wary"
		elif ham_relation >= 40: return "distant"
		elif ham_relation >= 20: return "hostile"
		else: return "broken"

var japheth_relation_label: String:
	get:
		if yephet_loyalty >= 80: return "loyal"
		elif yephet_loyalty >= 60: return "wavering"
		elif yephet_loyalty >= 40: return "uncertain"
		else: return "drifting"

var shem_population: int:
	get: return bnei_brit_shem + unspecialised

var shem_adults: int:
	get:
		var total := 0
		for v in professions.values():
			total += int(v)
		return total

var bc_free: int:
	get: return bc_count - bc_assignments.size()

var teva_free: int:
	get: return teva_count - teva_training - 1

var tithe_rate: float:
	get:
		if chain_integrity >= 80: return 0.10
		elif chain_integrity >= 50: return 0.07
		elif chain_integrity >= 25: return 0.04
		else: return 0.02

var security: int:
	get: return professions.get("Warrior", 0)

var security_needed: int:
	get: return int(total_population * 0.05)


# ── Methods ──

func _ready() -> void:
	_init_flags()
	_init_professions()


func _init_flags() -> void:
	flags = {
		"altar_built": false,
		"noah_taught_law": false,
		"brothers_dispersed": false,
		"tent_chanoch_built": false,
		"vineyard_planted": false,
		"vineyard_bearing": false,
		"vine_location": null,
		"vine_wintered": false,
		"vine_protection": null,
		"vine_woke": false,
		"tents_location": null,
		"first_flame_lit": false,
		"immersion_done": false,
		"immersion_path": null,
		"covenant_festival_y0": false,
		"covenant_proclamation": null,
		"first_pressing": false,
		"noah_spoke_sons": false,
		"ham_incident": false,
		"ham_rebuke_severity": 0,
		"year_0_reckoning": false,
		"year_1_priority": null,
		"seventh_law_taught": false,
		"first_signs_elohim": false,
		"first_encounter_elohim": false,
		"bnei_elohim_discovered": false,
		"ham_discovered_ruins": false,
		"ham_absorbing_elohim": false,
		"first_city_built": false,
		"tower_recognised": false,
		"salem_project": false,
		"council_of_seventy": false,
		"drought_hit": false,
		"noah_warned_ham": false,
		"cuneiform_question_raised": false,
		"first_arev_done": false,
		"migrated_to_shinar": false,
		"baal_stage_reached": 0,
		"mystical_experience": false,
		"goat_initiations_active": 0,
		"first_bc_trained": false,
		"famine_turns": 0,
	}


func _init_professions() -> void:
	for k in STARTING_PROFESSIONS:
		professions[k] = STARTING_PROFESSIONS[k]
		profession_targets[k] = 0


func bc_assigned_to(assignment_type: String) -> Array:
	var result: Array = []
	for a in bc_assignments:
		if a.get("type", "") == assignment_type:
			result.append(a)
	return result


func anchor_color(val: float) -> String:
	if val >= 8.0: return "green"
	elif val >= 5.0: return "yellow"
	elif val >= 3.0: return "red"
	else: return "grey"


func chain_color() -> String:
	if chain_integrity >= FIRE_BURNING_BRIGHT: return "green"
	elif chain_integrity >= FIRE_STEADY: return "yellow"
	elif chain_integrity >= FIRE_FLICKERING: return "red"
	else: return "grey"


func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	flag_set.emit(flag_name, value)
	state_changed.emit()


func modify_stat(stat_name: String, delta: float) -> void:
	var current = get(stat_name)
	if current == null:
		push_warning("GameState: unknown stat '%s'" % stat_name)
		return
	var max_val := _max_for(stat_name)
	var result = clampf(current + delta, 0.0, max_val)
	# Preserve int type for int stats
	if current is int:
		set(stat_name, int(result))
	else:
		set(stat_name, result)
	state_changed.emit()


func _max_for(stat_name: String) -> float:
	match stat_name:
		"chain_integrity": return 100.0
		"provision": return 100.0
		"ham_relation": return 100.0
		"yephet_loyalty": return 100.0
		_: return 999999.0


func reset_yearly_accumulators() -> void:
	yearly_food_produced = 0
	yearly_food_consumed = 0
	yearly_livestock_growth = 0
	yearly_drifters_lost = 0
	yearly_drifters_reclaimed = 0
	yearly_bc_graduated = 0
	yearly_initiations_completed = 0
	yearly_elohim_log.clear()
	festivals_this_year.clear()
	festivals_skipped_this_year = 0
	offering_quality = ""
	clan_fires_lit = 0
	clan_fires_total = 0
	unresolved_injustices = 0
	redistribution_done = false
	seven_words_hollow = 0
	babel_penalties_this_year = 0
