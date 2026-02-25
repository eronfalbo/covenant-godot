extends Control
## GameOverScreen — The chain is broken. There is no way back.

@onready var reason_label: RichTextLabel = $VBoxContainer/ReasonText
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var quit_btn: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	quit_btn.visible = false
	# Slow fade in — the weight of it
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 2.5)


func setup(data: Dictionary) -> void:
	if data.get("demo_complete", false):
		_setup_demo_complete()
		return

	var gs := GameState

	if gs.victory:
		title_label.text = "The Covenant Endures"
	else:
		title_label.text = "The Chain Is Broken"

	var lines: Array[String] = []

	# The reason — no softening
	lines.append("[font_size=24]%s[/font_size]" % gs.game_over_reason)
	lines.append("")

	# What was lost
	if gs.year == 0:
		lines.append("The new world lasted less than a year.")
	elif gs.year == 1:
		lines.append("One year. That is all you were given.")
	else:
		lines.append("%d years. That is all you were given." % gs.year)

	lines.append("")

	# The fire
	if gs.living_fire <= 0:
		lines.append("The fire that Chanoch pressed into your arm is cold.")
		lines.append("What Adam carried, what Seth preserved, what Methuselah guarded —")
		lines.append("gone. The transmission ends here, on a bare mountain,")
		lines.append("with no one left who remembers how to carry it.")
	elif gs.food <= 0:
		lines.append("The land could not sustain you. The covenant requires")
		lines.append("bodies as well as souls — and the bodies scattered.")
	elif gs.ham_centralisation >= 80:
		lines.append("A tower rises where the altar stood. The covenant")
		lines.append("is not forgotten — it is replaced. Ham's children")
		lines.append("will remember Noah. They will not remember what he carried.")
	else:
		lines.append("The chain that ran from Adam to Seth to Chanoch")
		lines.append("to Methuselah to Lamech to you — broken.")

	lines.append("")
	lines.append("[color=#f5f2eb66]There is no one left to try again.[/color]")

	reason_label.text = "\n".join(lines)


func _setup_demo_complete() -> void:
	title_label.text = "End of Vertical Slice"
	quit_btn.visible = true
	quit_btn.text = "Play Again"
	quit_btn.pressed.connect(_on_restart)
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
