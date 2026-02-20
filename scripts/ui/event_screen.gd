extends Control
## EventScreen — The core KoDP-style event display.
## Illustration top, scrolling narrative middle, advisors + choices bottom.

@onready var illustration: TextureRect = $IllustrationPanel
@onready var event_title: Label = $IllustrationPanel/EventTitle
@onready var quote_box: PanelContainer = $IllustrationPanel/QuoteBox
@onready var quote_text: RichTextLabel = $IllustrationPanel/QuoteBox/QuoteText
@onready var narrative_scroll: ScrollContainer = $NarrativePanel
@onready var narrative_label: RichTextLabel = $NarrativePanel/NarrativeText
@onready var choice_container: VBoxContainer = $ChoicePanel

var _current_event: Dictionary = {}
var _narrative_queue: Array = []
var _narrative_index: int = 0
var _had_events: bool = false
var _advice_label: RichTextLabel = null
var _active_advisor: int = -1

const PARAGRAPH_DELAY := 0.8


func _ready() -> void:
	EventManager.event_started.connect(_on_event_started)
	EventManager.narrative_text_added.connect(_on_narrative_text_added)
	EventManager.season_events_complete.connect(_on_season_complete)
	choice_container.visible = false
	_had_events = false


func setup(_data: Dictionary) -> void:
	pass


func _on_event_started(event_data: Dictionary) -> void:
	_had_events = true
	_current_event = event_data
	_narrative_queue.clear()
	_narrative_index = 0
	narrative_label.text = ""
	quote_text.text = ""
	quote_box.visible = false
	choice_container.visible = false
	_advice_label = null
	_active_advisor = -1

	# Clear old children from choice container
	for child in choice_container.get_children():
		child.queue_free()

	# Reset advisor portraits
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
		illustration.texture = null


func _display_next_narrative() -> void:
	if _narrative_index >= _narrative_queue.size():
		# All narrative shown — display choices with advisor access
		_show_choices()
		return

	var item: Dictionary = _narrative_queue[_narrative_index]
	_narrative_index += 1

	var type: String = item.get("type", "text")

	if type == "quote":
		# Quotes go to the styled box on the illustration, not inline
		_add_quote(item)
		# No delay — continue immediately to next item
		_display_next_narrative()
		return

	# Regular text goes to narrative
	if narrative_label.text != "":
		narrative_label.text += "\n\n"
	narrative_label.text += item.get("content", "")

	# Auto-scroll to bottom
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)

	# Brief pause between paragraphs, then show next
	await get_tree().create_timer(PARAGRAPH_DELAY).timeout
	_display_next_narrative()


func _add_quote(item: Dictionary) -> void:
	var content: String = item.get("content", "")
	var source: String = item.get("source", "")

	if quote_text.text != "":
		quote_text.text += "\n\n"

	quote_text.text += "[i]%s[/i]" % content
	if source != "":
		quote_text.text += "\n[font_size=13][color=#c9a962]— %s[/color][/font_size]" % source

	quote_box.visible = true


func _show_choices() -> void:
	var choices: Array = _current_event.get("choices", [])
	var advisors: Array = _current_event.get("advisors", [])
	if choices.is_empty():
		return

	choice_container.visible = true

	# Advisor portrait buttons (clickable to reveal advice)
	if not advisors.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var prompt := Label.new()
		prompt.text = "Seek counsel:"
		prompt.add_theme_font_size_override("font_size", 14)
		prompt.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92, 0.4))
		row.add_child(prompt)

		for i in advisors.size():
			var adv: Dictionary = advisors[i]
			var btn := Button.new()
			btn.text = adv.get("name", "")
			btn.add_theme_font_size_override("font_size", 16)
			btn.add_theme_color_override("font_color", Color(0.788, 0.663, 0.384, 1))
			btn.add_theme_color_override("font_hover_color", Color(0.96, 0.95, 0.92, 1))
			btn.pressed.connect(_on_advisor_clicked.bind(i))
			row.add_child(btn)

		choice_container.add_child(row)

		# Advice text (hidden until an advisor is clicked)
		_advice_label = RichTextLabel.new()
		_advice_label.bbcode_enabled = true
		_advice_label.fit_content = true
		_advice_label.visible = false
		var advice_font := load("res://assets/fonts/Montserrat.ttf") as Font
		_advice_label.add_theme_font_override("normal_font", advice_font)
		_advice_label.add_theme_font_size_override("normal_font_size", 16)
		_advice_label.add_theme_color_override("default_color", Color(0.96, 0.95, 0.92, 0.8))
		choice_container.add_child(_advice_label)

		# Brighten portraits of advisors who have counsel
		_highlight_available_advisors(advisors)

	# Choice buttons
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.get("label", "Choice %d" % (i + 1))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 40)
		var btn_font := load("res://assets/fonts/Montserrat.ttf") as Font
		btn.add_theme_font_override("font", btn_font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.788, 0.663, 0.384, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.96, 0.95, 0.92, 1))
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choice_container.add_child(btn)


func _on_advisor_clicked(idx: int) -> void:
	var advisors: Array = _current_event.get("advisors", [])
	if idx >= advisors.size() or _advice_label == null:
		return

	if _active_advisor == idx:
		# Toggle off
		_advice_label.visible = false
		_active_advisor = -1
		_highlight_available_advisors(advisors)
		return

	_active_advisor = idx
	var adv: Dictionary = advisors[idx]
	_advice_label.text = "[b][color=#c9a962]%s:[/color][/b] [i]%s[/i]" % [
		adv.get("name", ""), adv.get("text", "")
	]
	_advice_label.visible = true

	# Highlight the active speaker in the advisor strip
	var speaker_name: String = adv.get("name", "").to_lower()
	_highlight_strip_portrait(speaker_name)

	# Update speech bubble in strip
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if hbox:
		var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
		if bubble:
			bubble.text = "[b]%s:[/b] %s" % [adv.get("name", ""), adv.get("text", "")]


func _on_choice_pressed(choice_idx: int) -> void:
	# Disable all buttons in the choice container
	for child in choice_container.get_children():
		if child is Button:
			child.disabled = true
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Button:
					sub.disabled = true

	EventManager.submit_choice(_current_event["id"], choice_idx)


func _on_season_complete() -> void:
	if _had_events:
		await get_tree().create_timer(0.5).timeout
	_had_events = false
	# Deferred switch to avoid freed-instance coroutine bug
	get_tree().create_timer(0.0).timeout.connect(
		func(): ScreenManager.switch_to(ScreenManager.Screen.CAMP_OVERVIEW),
		CONNECT_ONE_SHOT
	)


func _highlight_available_advisors(advisors: Array) -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if not hbox:
		return

	var advisor_names: Array[String] = []
	for adv in advisors:
		advisor_names.append(adv.get("name", "").to_lower())

	var portraits := _get_portrait_dict(hbox)
	for key in portraits:
		var portrait = portraits[key]
		if portrait:
			var has_advice := false
			for advisor_name in advisor_names:
				if advisor_name.contains(key):
					has_advice = true
					break
			portrait.modulate = Color(1, 1, 1, 0.8) if has_advice else Color(1, 1, 1, 0.3)


func _highlight_strip_portrait(speaker_name: String) -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if not hbox:
		return
	var portraits := _get_portrait_dict(hbox)
	for key in portraits:
		var portrait = portraits[key]
		if portrait:
			if speaker_name.contains(key):
				portrait.modulate = Color(1, 1, 1, 1)
			else:
				portrait.modulate = Color(1, 1, 1, 0.3)


func _get_portrait_dict(hbox: Node) -> Dictionary:
	return {
		"shem": hbox.get_node_or_null("ShemPortrait"),
		"ham": hbox.get_node_or_null("HamPortrait"),
		"japheth": hbox.get_node_or_null("JaphethPortrait"),
		"naamah": hbox.get_node_or_null("NaamahPortrait"),
	}


func _reset_advisor_portraits() -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if not hbox:
		return
	for pname in ["ShemPortrait", "HamPortrait", "JaphethPortrait", "NaamahPortrait"]:
		var portrait := hbox.get_node_or_null(pname) as TextureRect
		if portrait:
			portrait.modulate = Color(1, 1, 1, 0.6)
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if bubble:
		bubble.text = ""


func _on_narrative_text_added(text: String) -> void:
	if narrative_label.text != "":
		narrative_label.text += "\n"
	narrative_label.text += text
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)
