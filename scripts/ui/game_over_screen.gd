extends Control
## GameOverScreen — Displays the game-over reason and offers quit.

@onready var reason_label: RichTextLabel = $VBoxContainer/ReasonText
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var quit_btn: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	var gs := GameState
	title_label.text = "The Flame Goes Out"
	reason_label.text = gs.game_over_reason
	quit_btn.text = "Try Again"
	quit_btn.pressed.connect(_on_restart)


func _on_restart() -> void:
	quit_btn.disabled = true
	GameState.reset()
	get_tree().reload_current_scene()


func setup(_data: Dictionary) -> void:
	pass
