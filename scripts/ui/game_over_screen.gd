extends Control
## GameOverScreen — Displays game-over or demo-complete screen.

@onready var reason_label: RichTextLabel = $VBoxContainer/ReasonText
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var quit_btn: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	quit_btn.text = "Play Again"
	quit_btn.pressed.connect(_on_restart)


func setup(data: Dictionary) -> void:
	if data.get("demo_complete", false):
		_setup_demo_complete()
	else:
		title_label.text = "The Flame Goes Out"
		reason_label.text = GameState.game_over_reason


func _setup_demo_complete() -> void:
	title_label.text = "End of Vertical Slice"
	var gs := GameState
	var lines: Array[String] = []
	lines.append("[font_size=24][color=#c9a962]The story continues...[/color][/font_size]")
	lines.append("")
	var vine_loc: String = str(gs.flags.get("vine_location", ""))
	if vine_loc != "":
		var loc_text := {"altar": "beside the altar", "south": "on the south slope", "valley": "in the valley"}
		lines.append("The vine grows %s." % loc_text.get(vine_loc, vine_loc))
	if gs.flags.get("seventh_law_taught", false):
		lines.append("The Seventh Law has been spoken.")
	if gs.flags.get("altar_built", false):
		lines.append("The altar stands on Ararat.")
	lines.append("")
	lines.append("[i]More events and seasons are coming.[/i]")
	lines.append("[i]Thank you for playing the Covenant vertical slice.[/i]")
	reason_label.text = "\n".join(lines)


func _on_restart() -> void:
	quit_btn.disabled = true
	GameState.reset()
	get_tree().reload_current_scene()
