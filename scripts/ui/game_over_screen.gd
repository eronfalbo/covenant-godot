extends Control
## GameOverScreen — Displays game-over or demo-complete screen.

@onready var reason_label: RichTextLabel = $VBoxContainer/ReasonText
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var quit_btn: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	quit_btn.text = "Play Again"
	quit_btn.pressed.connect(_on_restart)
	# Fade in
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)


func setup(data: Dictionary) -> void:
	if data.get("demo_complete", false):
		_setup_demo_complete()
	else:
		title_label.text = "The Flame Goes Out"
		var gs := GameState
		var lines: Array[String] = []
		lines.append(gs.game_over_reason)
		lines.append("")
		lines.append("[color=%s]Years survived:[/color] %d" % [UIConstants.GOLD_HEX, gs.year])
		lines.append("[color=%s]Seasons:[/color] %d" % [UIConstants.GOLD_HEX, gs.year * 4 + gs.season_idx])
		lines.append("[color=%s]Final Living Fire:[/color] %.0f%%" % [UIConstants.GOLD_HEX, gs.living_fire])
		lines.append("[color=%s]Population:[/color] %d" % [UIConstants.GOLD_HEX, gs.total_bnei_brit])
		if not gs.buildings_completed.is_empty():
			var bnames: Array[String] = []
			for bid in gs.buildings_completed:
				bnames.append(gs.BUILDING_DEFS.get(bid, {}).get("name", bid))
			lines.append("[color=%s]Buildings:[/color] %s" % [UIConstants.GOLD_HEX, ", ".join(bnames)])
		lines.append("[color=%s]Ham:[/color] %s" % [UIConstants.GOLD_HEX, gs.ham_relation_label])
		reason_label.text = "\n".join(lines)


func _setup_demo_complete() -> void:
	title_label.text = "End of Vertical Slice"
	var gs := GameState
	var lines: Array[String] = []
	lines.append("[font_size=24][color=%s]The story continues...[/color][/font_size]" % UIConstants.GOLD_HEX)
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
