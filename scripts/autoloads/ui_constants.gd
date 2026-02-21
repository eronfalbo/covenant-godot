extends Node
## UIConstants — Single source of truth for all visual constants.
## Every UI script references these instead of hardcoding values.

# ── Layout ──
const HUD_WIDTH := 280
const ADVISOR_HEIGHT := 110
const CONTENT_MARGIN_H := 60
const CONTENT_MARGIN_TOP := 40
const CONTENT_MARGIN_BOTTOM := 40
const ILLUSTRATION_HEIGHT := 380
const GRADIENT_HEIGHT := 80
const CHOICE_AREA_HEIGHT := 240

# ── Font sizes ──
const HEADER_SIZE := 28
const BODY_SIZE := 20
const BODY_SMALL_SIZE := 16
const LABEL_SIZE := 14
const BUTTON_SIZE := 22
const CHOICE_SIZE := 18

# ── Core palette ──
const GOLD := Color(0.788, 0.663, 0.384, 1.0)
const GOLD_HEX := "#c9a962"
const GOLD_PRESSED := Color(0.75, 0.62, 0.30, 1.0)
const IVORY := Color(0.96, 0.95, 0.92, 1.0)
const IVORY_DIM := Color(0.96, 0.95, 0.92, 0.7)
const IVORY_FAINT := Color(0.96, 0.95, 0.92, 0.5)
const IVORY_MUTED := Color(0.96, 0.95, 0.92, 0.6)
const IVORY_BODY := Color(0.96, 0.95, 0.92, 0.8)
const QUOTE_IVORY := Color(0.83, 0.78, 0.68, 1.0)
const NAVY := Color(0.11, 0.137, 0.192, 1.0)
const NAVY_DARK := Color(0.08, 0.1, 0.14, 0.9)
const NAVY_PANEL := Color(0.08, 0.1, 0.14, 0.85)

# ── Semantic status colors (BBCode hex) ──
const WARN_RED := "#cc4444"
const WARN_ORANGE := "#cc6644"
const CRITICAL_RED := "#ee4444"
const SUCCESS_GREEN := "#44cc44"

# ── Fire bar tiers ──
const FIRE_COLOR_BRIGHT := Color(0.85, 0.72, 0.35, 1)      # >= 80% (distinct from GOLD)
const FIRE_COLOR_STEADY := Color(0.7, 0.6, 0.3, 1)         # >= 50%
const FIRE_COLOR_FLICKER := Color(0.8, 0.4, 0.2, 1)        # >= 25%
const FIRE_COLOR_EMBERS := Color(0.5, 0.2, 0.2, 1)         # < 25%

# ── Portrait modulate levels ──
const PORTRAIT_ACTIVE := Color(1, 1, 1, 1)
const PORTRAIT_AVAILABLE := Color(1, 1, 1, 0.8)
const PORTRAIT_DIMMED := Color(1, 1, 1, 0.4)
const PORTRAIT_RESET := Color(1, 1, 1, 0.6)

# ── Button sizing ──
const CTA_BUTTON_SIZE := Vector2(400, 50)
const CHOICE_BUTTON_HEIGHT := 40

# ── Animation timing ──
const FADE_DURATION := 0.3
const TYPEWRITER_CPS := 30         # characters per second
const CHOICE_STAGGER := 0.1       # delay between each choice appearing
const FIRE_TWEEN_DURATION := 0.5
const RESOURCE_FLASH_DURATION := 0.3
const PORTRAIT_PULSE_DURATION := 0.15

# ── Fonts (preloaded) ──
var font_playfair: Font
var font_playfair_italic: Font
var font_montserrat: Font


func _ready() -> void:
	font_playfair = load("res://assets/fonts/PlayfairDisplay.ttf")
	font_playfair_italic = load("res://assets/fonts/PlayfairDisplay-Italic.ttf")
	font_montserrat = load("res://assets/fonts/Montserrat.ttf")
