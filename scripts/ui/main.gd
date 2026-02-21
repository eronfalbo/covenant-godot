extends Control
## Main — Root scene. Sets up layout references and kicks off the game.
## Also handles season-complete transitions (must live on a node that is never freed).

@onready var hud_panel: PanelContainer = $HUDPanel
@onready var content_area: Control = $ContentArea
@onready var advisor_strip: PanelContainer = $AdvisorStrip
@onready var transition_rect: ColorRect = $TransitionRect


func _ready() -> void:
	ScreenManager.setup(content_area, hud_panel, advisor_strip, transition_rect)
	EventManager.season_events_complete.connect(_on_season_events_complete)
	ScreenManager.switch_to(ScreenManager.Screen.INTRO)


func _on_season_events_complete() -> void:
	## Runs on Main (never freed) so the coroutine survives screen transitions.
	print("[Main] season_events_complete received")
	# Reset advisor portraits before leaving event screen
	_reset_advisor_strip()
	# Brief pause so the player can read the last effect text
	await get_tree().create_timer(0.5).timeout
	print("[Main] Switching to CAMP_OVERVIEW")
	await ScreenManager.switch_to(ScreenManager.Screen.CAMP_OVERVIEW)
	print("[Main] CAMP_OVERVIEW loaded")


func _reset_advisor_strip() -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/VBoxContainer/HBoxContainer")
	if not hbox:
		return
	for pname in ["ShemPortrait", "HamPortrait", "JaphethPortrait", "NaamahPortrait"]:
		var portrait := hbox.get_node_or_null(pname) as TextureRect
		if portrait:
			portrait.modulate = Color(1, 1, 1, 0.6)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if bubble:
		bubble.text = ""
