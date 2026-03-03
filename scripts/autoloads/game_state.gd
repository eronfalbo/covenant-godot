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
	"Winter": "Fast of Adam & Festival of the Returning Sun",
}

const ROOT_NAMES := [
	"Star Watch", "Altar Road", "Sacrificial Order", "Living Tongue",
	"Festival Calendar", "Sacred Objects", "Teaching Network", "The Stories",
]
const ROOT_SHORT := ["Stars", "Road", "Ritual", "Tongue", "Calendar", "Objects", "Teachers", "Stories"]
const ROOT_STARTING := [7.0, 7.0, 8.0, 9.0, 7.0, 6.0, 6.0, 8.0]

# Tutorial root decay: per-root rates that reflect what actually needs tending
# On Ararat with 8 souls, most roots are naturally maintained:
# Star Watch — Noah watches nightly, clear sky on Ararat
# Altar Road — the altar is 50 paces away, everyone knows where it is
# Sacrificial Order — needs active ritual, sacrifice maintains it
# Living Tongue — 8 people, one language, zero drift
# Festival Calendar — someone must track moons, slight drift
# Sacred Objects — ark timbers need active preservation
# Teaching Network — small group, all within earshot
# The Stories — flood survivors remember everything
const TUTORIAL_ROOT_DECAY: Array[float] = [0.02, 0.01, 0.05, 0.01, 0.03, 0.05, 0.03, 0.02]

const TREE_BURNING_BRIGHT := 80
const TREE_STEADY := 50
const TREE_FLICKERING := 25

# ── Mechanics Constants (from COVENANT_MECHANICS_SPEC §13) ──
const FOOD_PER_GATHERER := 3
const FOOD_PER_GATHERER_SPRING := 4
const PROVISION_PER_WORKER := 1
const BUILD_PER_WORKER := 1
const BUILD_PROVISION_COST := 1  # provisions consumed per season of building
const MIN_BUILDERS := 2
const FIRE_PER_TENDER := 2.0
const FOOD_PER_TENDER := 2       # base food per tender (milk, wool, etc.)
const LIVESTOCK_PER_TENDER := 4   # livestock needed per tender for full output
const LIVESTOCK_CAP_BASE := 20    # max livestock without animal pens
const LIVESTOCK_CAP_PENS := 30    # max livestock with animal pens

const FOOD_PER_PERSON := 1
const ROOT_REWARD_THRESHOLD := 7.0
const WINTER_FOOD_PENALTY := 2
const FOOD_CAP_BASE := 24
const FOOD_CAP_GRANARY := 32
const PROVISION_CAP_BASE := 20

# Legacy aliases for backward compatibility
const FOOD_PER_WORKER := FOOD_PER_GATHERER       # Legacy alias
const FOOD_PER_WORKER_SPRING := FOOD_PER_GATHERER_SPRING  # Legacy alias

const FIRE_DECAY_PRE_TENT := 10.0   # 2.5/season × 4
const FIRE_DECAY_POST_TENT := 12.0  # 3.0/season × 4
const FIRE_TZOHAR_SHELTER_REDUCTION := 0.5
const FIRE_TENT_DROP := 25.0
const FIRE_BLEEDING_PENALTY := 5.0

const OLAH_FIRE := 8.0
const OLAH_LIVESTOCK_COST := 1
const MINCHA_FIRE := 3.0
const MINCHA_FOOD_COST := 2
const SHELAMIM_FIRE := 5.0
const SHELAMIM_LIVESTOCK_COST := 1
const SHELAMIM_FOOD_RETURN := 2
const CHATAT_FIRE := 10.0
const CHATAT_LIVESTOCK_COST := 1
const FIRST_FRUITS_FIRE := 5.0
const FIRST_FRUITS_FOOD_COST := 2

const TENT_FIRE_DROP := 25.0
## Ham drift penalties: "active" remedy = no drift, "none" = worst
const HAM_DRIFT_ACTIVE := 0      # Active remedy: no labor penalty
const HAM_DRIFT_PARTIAL := 1     # Partial remedy: lose 1 worker
const HAM_DRIFT_NONE := 2        # No remedy: lose 2 workers

const COUNCIL_OVERRIDE_COST := 3.0

# ── Tent Definitions (replaces buildings) ──
const TENT_DEFS := {
	"tent_abel": {
		"name": "Tent of Abel",
		"description": "The first altar. Where the offering was accepted.",
		"build_points_required": 4,
		"provision_cost": 2,
		"available_year": 0, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "Sacrifice fire +50%, auto-prep offerings",
		"replaces": "stone_altar",
	},
	"tent_jabal": {
		"name": "Tent of Jabal",
		"description": "Father of those who dwell in tents and tend livestock.",
		"build_points_required": 5,
		"provision_cost": 3,
		"available_year": 0, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "+2 livestock/season, livestock cap 30",
		"replaces": "animal_pens",
	},
	"tent_eve": {
		"name": "Tent of Eve",
		"description": "Mother of all living. Warmth and provision endure here.",
		"build_points_required": 4,
		"provision_cost": 2,
		"available_year": 1, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "No winter food penalty, +1 provision/season",
		"replaces": "warming_shelter",
	},
	"tzohar_shrine": {
		"name": "Tzohar Shrine",
		"description": "The sacred light is sheltered. Fire decay slows.",
		"build_points_required": 3,
		"provision_cost": 1,
		"available_year": 0, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "-1 fire decay/season",
		"replaces": "tzohar_shelter",
	},
	"tent_naamah": {
		"name": "Tent of Naamah",
		"description": "Singer of songs, keeper of memory. Crises lose their edge here.",
		"build_points_required": 5,
		"provision_cost": 3,
		"available_year": 1, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "Crisis effects -20%",
	},
	"tent_tubal_cain": {
		"name": "Tent of Tubal-Cain",
		"description": "Forger of bronze and iron. Tools transform labour into production.",
		"build_points_required": 6,
		"provision_cost": 4,
		"available_year": 2, "available_season": 0,
		"prerequisite": "tent_jabal",
		"bonus_text": "+1 food/gatherer, +1 provision/worker",
		"replaces": "workshop",
	},
	"tent_japheth": {
		"name": "Tent of Japheth",
		"description": "Scouts and watchmen. Ham's drift is held at bay.",
		"build_points_required": 5,
		"provision_cost": 3,
		"available_year": 2, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "-1 ham centralisation/yr",
		"replaces": "watchtower",
	},
	"tent_jubal": {
		"name": "Tent of Jubal",
		"description": "Father of the lyre and pipe. Music keeps memory alive.",
		"build_points_required": 5,
		"provision_cost": 3,
		"available_year": 2, "available_season": 0,
		"prerequisite": "",
		"bonus_text": "Fire decay -1%/season, teaching +25%",
	},
	"tent_chanoch": {
		"name": "Tent of Chanoch",
		"description": "He who walked with God. Teaching flourishes.",
		"build_points_required": 7,
		"provision_cost": 5,
		"available_year": 3, "available_season": 0,
		"prerequisite": "tent_jubal",
		"bonus_text": "Teaching +50% effectiveness",
		"replaces": "teaching_house",
	},
	"tent_cain": {
		"name": "Tent of Cain",
		"description": "The tiller's legacy. Gathering becomes farming.",
		"build_points_required": 8,
		"provision_cost": 6,
		"available_year": 4, "available_season": 0,
		"prerequisite": "tent_tubal_cain",
		"bonus_text": "Food cap +8, +1 food/gatherer",
		"replaces": "granary",
	},
}

# Backward compatibility: map old building IDs to tent IDs
const _BUILDING_TO_TENT := {
	"stone_altar": "tent_abel",
	"animal_pens": "tent_jabal",
	"warming_shelter": "tent_eve",
	"tzohar_shelter": "tzohar_shrine",
	"workshop": "tent_tubal_cain",
	"watchtower": "tent_japheth",
	"teaching_house": "tent_chanoch",
	"granary": "tent_cain",
}

# Legacy alias — code that references BUILDING_DEFS still works
const BUILDING_DEFS := TENT_DEFS

# ── Sacrifice Definitions ──
const SACRIFICE_DEFS := {
	"olah": {
		"name": "Ascent",
		"description": "A whole offering consumed by fire. Costly — the beast and grain for preparation.",
		"livestock_cost": 1, "food_cost": 2,
		"fire_bonus": 8.0, "food_return": 0,
		"available": "always",
	},
	"mincha": {
		"name": "Portion",
		"description": "A grain offering from the harvest.",
		"livestock_cost": 0, "food_cost": 3,
		"fire_bonus": 3.0, "food_return": 0,
		"available": "always",
	},
	"shelamim": {
		"name": "Shared Table",
		"description": "A communal peace offering. The family eats together.",
		"livestock_cost": 1, "food_cost": 1,
		"fire_bonus": 5.0, "food_return": 2,
		"available": "always",
	},
	"chatat": {
		"name": "Covering",
		"description": "A sin offering. Stops the bleeding.",
		"livestock_cost": 1, "food_cost": 1,
		"fire_bonus": 10.0, "food_return": 0,
		"available": "post_tent",
	},
	"first_fruits": {
		"name": "First Fruits",
		"description": "The best of the harvest, given before the family eats.",
		"livestock_cost": 0, "food_cost": 3,
		"fire_bonus": 5.0, "food_return": 0,
		"available": "spring",
	},
}

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
var livestock: int = 14
var food: int = 20
var wine: int = 0
var provision: int = 5
var provision_cap: int = PROVISION_CAP_BASE

# ── Tree of Life (the burning tree — fire sustained by roots) ──
var tree_of_life: float = 95.0
var fire_decay_rate: float = 10.0  # legacy; decay now driven by root health
var food_cap: int = 24  # 32 with granary

# ── Post-Tent Mechanics ──
var tent_scene_occurred: bool = false
var bleeding_active: bool = false
var ham_drift_penalty: int = 0

# ── Building State ──
var buildings_completed: Array[String] = []
var active_building: String = ""  # building id from BUILDING_DEFS
var active_building_progress: int = 0

# ── Allocation (percentage-based, set by player each season) ──
var alloc_pct: Dictionary = {
	"gather": 0.5,
	"work": 0.0,
	"build": 0.0,
	"tend": 0.25,
	"teach": 0.25,
}
# Integer worker counts (computed from alloc_pct before resolution)
var workers_on_gather: int = 0
var workers_on_work: int = 0
var workers_on_build: int = 0
var workers_on_tend: int = 0
var workers_on_teach: int = 0
var chosen_sacrifice: String = ""  # sacrifice id or ""
var seasons_without_sacrifice: int = 0  # consecutive seasons with no offering

# ── Season Resolution Results (for display) ──
var last_food_produced: int = 0
var last_food_consumed: int = 0
var last_fire_delta: float = 0.0
var last_build_progress: int = 0
var last_building_completed: String = ""

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
	"uncontacted": 30000,
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

# ── Chain Integrity (alias for tree_of_life — backward compat with JSON events) ──
var chain_integrity: float:
	get: return tree_of_life
	set(v): tree_of_life = v
var babel_penalties_this_year: int = 0

# ── Eight Roots ──
var roots: Array[float] = [7.0, 7.0, 8.0, 9.0, 7.0, 6.0, 6.0, 8.0]
var root_neglect_years: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]

# ── Diplomatic ──
var ham_centralisation: int = 0
var ham_gentle_drift: int = 0  # Years remaining of +1 centralisation/yr after gentle rebuke
var ham_relation: int = 90
var yephet_loyalty: int = 90
var outer_hostility: float = 0.001

# ── Flags ──
var flags: Dictionary = {}

# ── Buildings ──
var tents_built: Array[String] = []
var building_projects: Array[Dictionary] = []

# ── Festival tracking ──
var festivals_this_year: Array[String] = []
var festivals_skipped_this_year: int = 0
var chosen_festival_scale: String = ""  # "Skip", "Minimal", "Standard", "Grand"
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

# ── Phase transition: Ararat → Shinar ──
# Snapshot of what the family carries when they descend the mountain.
# Written on Ararat completion, read on Shinar init.
var ararat_legacy: Dictionary = {}


## Called when the family departs Ararat. Captures everything that carries forward.
func capture_ararat_legacy() -> void:
	ararat_legacy = {
		"tree_of_life": tree_of_life,
		"roots": roots.duplicate(),
		"tents": buildings_completed.duplicate(),
		"ham_centralisation": ham_centralisation,
		"ham_relation": ham_relation,
		"yephet_loyalty": yephet_loyalty,
		"total_population": total_population,
		"flags": flags.duplicate(),
	}

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

var tree_tier: String:
	get:
		if tree_of_life >= TREE_BURNING_BRIGHT: return "Burning Bright"
		elif tree_of_life >= TREE_STEADY: return "Steady Flame"
		elif tree_of_life >= TREE_FLICKERING: return "Flickering"
		else: return "Embers"

var tzohar_status: String:
	get:
		if tree_of_life > 40: return "BURNING"
		elif tree_of_life > 15: return "DIM"
		else: return "OUT"

var allocatable_labor: int:
	get: return int(floor(total_bnei_brit * tree_of_life / 100.0))

var effective_allocatable: int:
	get: return max(0, allocatable_labor - int(ham_drift_penalty))

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
		return "%d / %d" % [provision, provision_cap]

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
		if tree_of_life >= 80: return 0.10
		elif tree_of_life >= 50: return 0.07
		elif tree_of_life >= 25: return 0.04
		else: return 0.02

var security: int:
	get: return professions.get("Warrior", 0)

var security_needed: int:
	get: return int(total_population * 0.05)


# ── Methods ──

func _ready() -> void:
	reset()


func reset() -> void:
	year = 0
	season_idx = 0
	act = 1
	phase = "ararat"
	livestock = 14
	food = 20
	wine = 0
	provision = 5
	provision_cap = PROVISION_CAP_BASE
	tree_of_life = 95.0
	fire_decay_rate = FIRE_DECAY_PRE_TENT
	food_cap = FOOD_CAP_BASE
	tent_scene_occurred = false
	bleeding_active = false
	ham_drift_penalty = 0
	buildings_completed = []
	active_building = ""
	active_building_progress = 0
	alloc_pct = {"gather": 0.5, "work": 0.0, "build": 0.0, "tend": 0.25, "teach": 0.25}
	workers_on_gather = 0
	workers_on_work = 0
	workers_on_build = 0
	workers_on_tend = 0
	workers_on_teach = 0
	chosen_sacrifice = ""
	chosen_festival_scale = ""
	seasons_without_sacrifice = 0
	last_food_produced = 0
	last_food_consumed = 0
	last_fire_delta = 0.0
	last_build_progress = 0
	last_building_completed = ""
	bnei_brit_shem = 4
	bnei_brit_ham = 2
	bnei_brit_yephet = 2
	sojourners = 0
	initiates = 0
	drifters_known = 0
	drifters_estimated = 0
	bnei_baal = 0
	bnei_elohim = {"uncontacted": 30000, "sojourning": 0, "initiating": 0, "captured": 0, "nephilim": 0}
	teva_count = 0
	teva_training = 0
	teva_training_years = {}
	bc_count = 0
	bc_assignments = []
	bc_next_id = 1
	bc_training_count = 0
	active_arev = 0
	active_initiations = 0
	initiation_years = {}
	bc_community = {"Shem": 0, "Ham": 0, "Japheth": 0}
	babel_penalties_this_year = 0
	roots = [7.0, 7.0, 8.0, 9.0, 7.0, 6.0, 6.0, 8.0]
	root_neglect_years = [0, 0, 0, 0, 0, 0, 0, 0]
	ham_centralisation = 0
	ham_gentle_drift = 0
	ham_relation = 90
	yephet_loyalty = 90
	outer_hostility = 0.001
	events_fired = []
	event_last_fired = {}
	events_this_season = []
	game_over = false
	game_over_reason = ""
	victory = false
	tents_built = []
	building_projects = []
	_init_flags()
	_init_professions()
	reset_yearly_accumulators()


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
		"days_of_silence_done": false,
		"fast_of_adam_done": false,
		"festival_of_light_done": false,
		"first_flame_lighter": null,
		"canaan_born": false,
		"canaan_remedy": null,
		"mourning_of_abel_done": false,
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
		# ── Year 1-7 random event flags ──
		"naamahs_loom_done": false,
		"loom_choice": null,
		"new_spring_found": false,
		"spring_choice": null,
		"raven_returned": false,
		"raven_choice": null,
		"missing_star_seen": false,
		"star_choice": null,
		"counting_stone_found": false,
		"counting_stone_choice": null,
		"ox_event_done": false,
		"ox_choice": null,
		"morning_dance_done": false,
		"dance_choice": null,
		"second_fruit_done": false,
		"second_fruit_choice": null,
		"moon_dispute_done": false,
		"moon_choice": null,
		"canaan_line_done": false,
		"canaan_line_choice": null,
		"granary_built": false,
		"granary_choice": null,
		"song_diverged": false,
		"song_choice": null,
		"cleared_ground_found": false,
		"cleared_ground_choice": null,
		"soil_divides_done": false,
		"soil_choice": null,
		"circle_questioned": false,
		"circle_choice": null,
		"red_flowers_found": false,
		"flowers_choice": null,
		"three_stars_seen": false,
		"three_stars_choice": null,
		"flock_shift_done": false,
		"flock_choice": null,
		"childs_festival_done": false,
		"festival_child_choice": null,
		"wind_recognised": false,
		"wind_choice": null,
		"shem_absence_done": false,
		"absence_choice": null,
		"encounter_choice": null,
		"wolf_lamb_seen": false,
		"mountain_sang": false,
		"mountain_choice": null,
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
	if tree_of_life >= TREE_BURNING_BRIGHT: return "green"
	elif tree_of_life >= TREE_STEADY: return "yellow"
	elif tree_of_life >= TREE_FLICKERING: return "red"
	else: return "grey"


func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	flag_set.emit(flag_name, value)
	# Tent scene hook: when ham_incident fires, apply mechanical consequences
	if flag_name == "ham_incident" and value == true:
		apply_tent_consequences()
	# Canaan remedy hook: recalculate ham drift when diagnosis is made
	if flag_name == "canaan_remedy" and tent_scene_occurred:
		match str(value):
			"active": ham_drift_penalty = HAM_DRIFT_ACTIVE
			"partial": ham_drift_penalty = HAM_DRIFT_PARTIAL
			"none": ham_drift_penalty = HAM_DRIFT_NONE
	# Gentle rebuke triggers 4 years of centralisation drift
	if flag_name == "ham_rebuke_severity" and int(value) == 1:
		ham_gentle_drift = 4
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
		"chain_integrity", "tree_of_life": return 100.0
		"provision": return float(provision_cap)
		"ham_relation": return 100.0
		"yephet_loyalty": return 100.0
		"outer_hostility": return 100.0
		_: return 999999.0


func get_available_buildings() -> Array[String]:
	## Returns tent/building IDs that can be started this season.
	var result: Array[String] = []
	for id in TENT_DEFS:
		if id in buildings_completed:
			continue
		var def: Dictionary = TENT_DEFS[id]
		if year < def["available_year"]:
			continue
		if year == def["available_year"] and season_idx < def["available_season"]:
			continue
		var prereq: String = def.get("prerequisite", "")
		if prereq != "" and not prereq in buildings_completed:
			continue
		var prereq_count: int = def.get("prerequisite_count", 0)
		if prereq_count > 0 and buildings_completed.size() < prereq_count:
			continue
		var prereq_all: Array = def.get("prerequisite_all", [])
		if not prereq_all.is_empty():
			var all_met: bool = true
			for req in prereq_all:
				if req not in buildings_completed:
					all_met = false
					break
			if not all_met:
				continue
		result.append(id)
	return result


func get_available_sacrifices() -> Array[String]:
	## Returns sacrifice IDs available this season.
	var result: Array[String] = []
	for id in SACRIFICE_DEFS:
		var def: Dictionary = SACRIFICE_DEFS[id]
		var avail: String = def["available"]
		match avail:
			"always":
				pass  # always available
			"post_tent":
				if not tent_scene_occurred:
					continue
			"spring":
				if season_idx != 2:
					continue
		# Check affordability
		if def["livestock_cost"] > livestock:
			continue
		if def["food_cost"] > food:
			continue
		result.append(id)
	return result


func can_afford_sacrifice(sacrifice_id: String) -> bool:
	if sacrifice_id == "" or not SACRIFICE_DEFS.has(sacrifice_id):
		return true  # no sacrifice = always affordable
	var def: Dictionary = SACRIFICE_DEFS[sacrifice_id]
	return livestock >= def["livestock_cost"] and food >= def["food_cost"]


func current_festival_name() -> String:
	## Returns the festival name for the current season, or "" if none.
	return FESTIVAL_NAMES.get(current_season, "")


func can_afford_festival(scale: String) -> bool:
	## Returns true if the player can afford the given festival scale.
	if scale == "" or scale == "Skip" or not FESTIVAL_SCALES.has(scale):
		return true
	var costs: Dictionary = FESTIVAL_SCALES[scale]
	return livestock >= costs.get("livestock", 0) and food >= costs.get("food", 0) and wine >= costs.get("wine", 0)


func apply_tent_consequences() -> void:
	## Called when the tent scene fires (A12). Drops fire, changes decay rate.
	tree_of_life = max(0.0, tree_of_life - TENT_FIRE_DROP)
	fire_decay_rate = FIRE_DECAY_POST_TENT
	tent_scene_occurred = true
	bleeding_active = true  # starts bleeding until Covering offered
	# Calculate ham drift from canaan_remedy
	var remedy = flags.get("canaan_remedy", null)
	match str(remedy):
		"active": ham_drift_penalty = HAM_DRIFT_ACTIVE
		"partial": ham_drift_penalty = HAM_DRIFT_PARTIAL
		"none": ham_drift_penalty = HAM_DRIFT_NONE
		_: ham_drift_penalty = HAM_DRIFT_NONE  # default if no choice made
	state_changed.emit()


func accept_covering() -> void:
	## Special one-time covering sacrifice after tent scene.
	if livestock >= 1:
		livestock -= 1
		tree_of_life = min(100.0, tree_of_life + CHATAT_FIRE)
		bleeding_active = false
		state_changed.emit()


func compute_workers_from_pct() -> void:
	## Convert alloc_pct percentages to integer worker counts.
	var available: int = effective_allocatable
	var counts: Dictionary = {}
	var total_assigned: int = 0
	for slot in alloc_pct:
		var count: int = int(round(alloc_pct[slot] * available))
		counts[slot] = count
		total_assigned += count
	# Distribute rounding remainder to largest slot
	if total_assigned != available:
		var diff: int = available - total_assigned
		var largest_slot: String = "gather"
		for slot in counts:
			if counts[slot] > counts.get(largest_slot, 0):
				largest_slot = slot
		counts[largest_slot] += diff
	workers_on_gather = counts.get("gather", 0)
	workers_on_work = counts.get("work", 0)
	workers_on_build = counts.get("build", 0)
	workers_on_tend = counts.get("tend", 0)
	workers_on_teach = counts.get("teach", 0)


func start_building(building_id: String) -> bool:
	## Attempt to start a building project. Pays provision cost upfront.
	## Returns true if successful.
	if active_building != "":
		return false
	var def: Dictionary = TENT_DEFS.get(building_id, {})
	if def.is_empty():
		return false
	var prov_cost: int = def.get("provision_cost", 0)
	if provision < prov_cost:
		return false
	provision -= prov_cost
	active_building = building_id
	active_building_progress = 0
	return true


func has_building(building_id: String) -> bool:
	if building_id in buildings_completed:
		return true
	# Check old ID → new tent mapping for backward compat
	var mapped: String = _BUILDING_TO_TENT.get(building_id, "")
	if mapped != "" and mapped in buildings_completed:
		return true
	return false


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
