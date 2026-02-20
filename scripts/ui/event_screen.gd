extends Control
## EventScreen — The core KoDP-style event display.
## Illustration top, scrolling narrative middle, choices bottom.

@onready var illustration: TextureRect = $IllustrationPanel
@onready var event_title: Label = $IllustrationPanel/EventTitle
@onready var source_citation: RichTextLabel = $IllustrationPanel/SourceCitation
@onready var narrative_scroll: ScrollContainer = $NarrativePanel
@onready var narrative_label: RichTextLabel = $NarrativePanel/NarrativeText
@onready var choice_container: VBoxContainer = $ChoicePanel
@onready var advisor_container: VBoxContainer = $AdvisorPanel

var _current_event: Dictionary = {}
var _narrative_queue: Array = []
var _narrative_index: int = 0
var _typing: bool = false
var _had_events: bool = false

const TEXT_SPEED := 30.0  # characters per second
const PARAGRAPH_DELAY := 0.3


func _ready() -> void:
	EventManager.event_started.connect(_on_event_started)
	EventManager.narrative_text_added.connect(_on_narrative_text_added)
	EventManager.season_events_complete.connect(_on_season_complete)
	choice_container.visible = false
	advisor_container.visible = false
	_had_events = false


func setup(data: Dictionary) -> void:
	# Called by ScreenManager if data is passed
	pass


func _on_event_started(event_data: Dictionary) -> void:
	_had_events = true
	_current_event = event_data
	_narrative_queue.clear()
	_narrative_index = 0
	narrative_label.text = ""
	source_citation.text = ""
	choice_container.visible = false
	advisor_container.visible = false

	# Clear old choice buttons
	for child in choice_container.get_children():
		child.queue_free()
	for child in advisor_container.get_children():
		child.queue_free()

	# Reset advisor portraits to full brightness
	_reset_advisor_portraits()

	# Set illustration
	_load_illustration(event_data.get("illustration", ""))

	# Set title
	event_title.text = event_data.get("name", "")

	# Queue narrative items
	_narrative_queue = event_data.get("narrative", [])
	_narrative_index = 0

	# Start displaying narrative
	_display_next_narrative()


func _load_illustration(path: String) -> void:
	if path == "":
		illustration.texture = null
		return
	var full_path := "res://assets/illustrations/" + path
	if ResourceLoader.exists(full_path):
		illustration.texture = load(full_path)
	else:
		# Use placeholder color
		illustration.texture = null


func _display_next_narrative() -> void:
	if _narrative_index >= _narrative_queue.size():
		# All narrative shown — display advisors then choices
		_show_advisors()
		_show_choices()
		return

	var item: Dictionary = _narrative_queue[_narrative_index]
	_narrative_index += 1

	var type: String = item.get("type", "text")

	if type == "quote":
		# Source reference goes to the citation overlay near the illustration
		_add_citation(item)
		# Quote TEXT still appears in the narrative as italic

	var formatted := _format_narrative_item(item)
	if narrative_label.text != "":
		narrative_label.text += "\n\n"
	narrative_label.text += formatted

	# Auto-scroll to bottom
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)

	# Brief pause between paragraphs, then show next
	await get_tree().create_timer(PARAGRAPH_DELAY).timeout
	_display_next_narrative()


func _format_narrative_item(item: Dictionary) -> String:
	var content: String = item.get("content", "")
	var type: String = item.get("type", "text")
	if type == "quote":
		return "[i][color=#d4cfc4]%s[/color][/i]" % content
	return content


func _add_citation(item: Dictionary) -> void:
	var source: String = item.get("source", "")
	if source == "":
		return
	if source_citation.text != "":
		source_citation.text += "\n"
	source_citation.text += "[right][i]— %s[/i][/right]" % source


func _show_advisors() -> void:
	var advisors: Array = _current_event.get("advisors", [])
	if advisors.is_empty():
		return

	advisor_container.visible = true

	for adv in advisors:
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.text = "[b][color=#c9a962]%s:[/color][/b] [i]%s[/i]" % [
			adv.get("name", ""), adv.get("text", "")
		]
		advisor_container.add_child(label)

	# Update advisor strip — speech bubble + portrait highlighting
	if not advisors.is_empty():
		var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
		if hbox:
			var bubble := hbox.get_node_or_null("SpeechBubble")
			if bubble:
				var first: Dictionary = advisors[0]
				bubble.text = "[b]%s:[/b] %s" % [first.get("name", ""), first.get("text", "")]

			# Highlight active speaker portrait, dim others
			var speaker_name: String = advisors[0].get("name", "").to_lower()
			var portraits := {
				"shem": hbox.get_node_or_null("ShemPortrait"),
				"ham": hbox.get_node_or_null("HamPortrait"),
				"japheth": hbox.get_node_or_null("JaphethPortrait"),
			}
			for key in portraits:
				var portrait: TextureRect = portraits[key]
				if portrait:
					if speaker_name.contains(key):
						portrait.modulate = Color(1, 1, 1, 1)
					else:
						portrait.modulate = Color(1, 1, 1, 0.4)


func _show_choices() -> void:
	var choices: Array = _current_event.get("choices", [])
	if choices.is_empty():
		return

	choice_container.visible = true

	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.get("label", "Choice %d" % (i + 1))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 44)
		var font := load("res://assets/fonts/Montserrat.ttf") as Font
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.788, 0.663, 0.384, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.96, 0.95, 0.92, 1))
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choice_container.add_child(btn)


func _on_choice_pressed(choice_idx: int) -> void:
	# Disable all buttons
	for child in choice_container.get_children():
		if child is Button:
			child.disabled = true

	# Submit choice to EventManager
	EventManager.submit_choice(_current_event["id"], choice_idx)


func _on_season_complete() -> void:
	# All events for this season are done — go to camp overview
	if _had_events:
		await get_tree().create_timer(0.5).timeout
	_had_events = false
	# Schedule switch on the SceneTree to avoid freed-instance coroutine bug.
	# switch_to is async and will queue_free this node during the fade.
	get_tree().create_timer(0.0).timeout.connect(
		func(): ScreenManager.switch_to(ScreenManager.Screen.CAMP_OVERVIEW),
		CONNECT_ONE_SHOT
	)


func _reset_advisor_portraits() -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if not hbox:
		return
	for pname in ["ShemPortrait", "HamPortrait", "JaphethPortrait"]:
		var portrait := hbox.get_node_or_null(pname) as TextureRect
		if portrait:
			portrait.modulate = Color(1, 1, 1, 0.6)

	# Clear speech bubble
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if bubble:
		bubble.text = ""


func _on_narrative_text_added(text: String) -> void:
	# Called when effects produce show_text — append to narrative
	if narrative_label.text != "":
		narrative_label.text += "\n"
	narrative_label.text += text

	# Auto-scroll
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)
