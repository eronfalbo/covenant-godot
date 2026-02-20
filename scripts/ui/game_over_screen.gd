extends Control
## GameOverScreen — Displays the game-over reason and offers restart.

@onready var reason_label: RichTextLabel = $VBoxContainer/ReasonText
@onready var title_label: Label = $VBoxContainer/TitleLabel


func _ready() -> void:
	var gs := GameState
	title_label.text = "The Flame Goes Out"
	reason_label.text = gs.game_over_reason


func setup(_data: Dictionary) -> void:
	pass
