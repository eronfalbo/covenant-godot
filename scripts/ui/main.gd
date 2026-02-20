extends Control
## Main — Root scene. Sets up layout references and kicks off the game.

@onready var hud_panel: PanelContainer = $HUDPanel
@onready var content_area: Control = $ContentArea
@onready var advisor_strip: PanelContainer = $AdvisorStrip
@onready var transition_rect: ColorRect = $TransitionRect


func _ready() -> void:
	ScreenManager.setup(content_area, hud_panel, advisor_strip, transition_rect)
	ScreenManager.switch_to(ScreenManager.Screen.INTRO)
