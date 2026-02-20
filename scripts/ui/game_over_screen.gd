extends Control
## GameOverScreen — Displays the game-over reason and offers quit.

@onready var reason_label: RichTextLabel = $VBoxContainer/ReasonText
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var quit_btn: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	var gs := GameState
	title_label.text = "The Flame Goes Out"
	reason_label.text = gs.game_over_reason
	quit_btn.pressed.connect(func(): get_tree().quit())


func setup(_data: Dictionary) -> void:
	pass
