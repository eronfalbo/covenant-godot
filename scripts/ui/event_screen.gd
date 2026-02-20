extends Control
## EventScreen — The core KoDP-style event display.
## Illustration top, scrolling narrative middle, advisors + choices bottom.
## Clicking a lit portrait in the AdvisorStrip shows advice in the SpeechBubble.

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
var _active_advisor: int = -1
var _portrait_connections: Array = []  # [{portrait, callable}] for cleanup

const PARAGRAPH_DELAY := 0.8


func _ready() -> void:
	EventManager.event_started.connect(_on_event_started)
	EventManager.narrative_text_added.connect(_on_narrative_text_added)
	EventManager.season_events_complete.connect(_on_season_complete)
	choice_container.visible = false
	_had_events = false


func setup(_data: Dictionary) -> void:
	pass


func _exit_tree() -> void:
	# Clean up portrait click handlers when this screen is freed
	_clear_portrait_clicks()


func _on_event_started(event_data: Dictionary) -> void:
	_had_events = true
	_current_event = event_data
	_narrative_queue.clear()
	_narrative_index = 0
	narrative_label.text = ""
	quote_text.text = ""
	quote_box.visible = false
	choice_container.visible = false
	_active_advisor = -1
	_portrait_connections.clear()

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

	# Wire up portrait clicking in the AdvisorStrip (no buttons in ChoicePanel)
	if not advisors.is_empty():
		_setup_portrait_clicks(advisors)

	# Choice buttons only — no advisor UI mixed in
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


func _setup_portrait_clicks(advisors: Array) -> void:
	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if not hbox:
		return

	var advisor_names: Array[String] = []
	for adv in advisors:
		advisor_names.append(adv.get("name", "").to_lower())

	# Make portraits with advice clickable via gui_input
	var portraits := _get_portrait_dict(hbox)
	for key in portraits:
		var portrait: TextureRect = portraits[key]
		if not portrait:
			continue

		# Check if this portrait has advice
		var advisor_idx := -1
		for i in advisor_names.size():
			if advisor_names[i].contains(key):
				advisor_idx = i
				break

		if advisor_idx >= 0:
			portrait.modulate = Color(1, 1, 1, 0.8)
			portrait.mouse_filter = Control.MOUSE_FILTER_STOP
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var bound_callable := _on_portrait_input.bind(advisor_idx)
			portrait.gui_input.connect(bound_callable)
			_portrait_connections.append({"portrait": portrait, "callable": bound_callable})
		else:
			portrait.modulate = Color(1, 1, 1, 0.3)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_portrait_input(event: InputEvent, advisor_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var advisors: Array = _current_event.get("advisors", [])
	if advisor_idx >= advisors.size():
		return

	var hbox := get_tree().root.get_node_or_null("Main/AdvisorStrip/HBoxContainer")
	if not hbox:
		return
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if not bubble:
		return

	if _active_advisor == advisor_idx:
		# Toggle off
		bubble.text = ""
		_active_advisor = -1
		_highlight_available_advisors(advisors)
		return

	_active_advisor = advisor_idx
	var adv: Dictionary = advisors[advisor_idx]
	bubble.text = "[b][color=#c9a962]%s:[/color][/b] %s" % [
		adv.get("name", ""), adv.get("text", "")
	]

	# Highlight the active speaker
	var speaker_name: String = adv.get("name", "").to_lower()
	_highlight_strip_portrait(speaker_name)


func _on_choice_pressed(choice_idx: int) -> void:
	# Disable all buttons in the choice container
	for child in choice_container.get_children():
		if child is Button:
			child.disabled = true

	# Reset portraits and clear bubble when choice is made
	_reset_advisor_portraits()

	EventManager.submit_choice(_current_event["id"], choice_idx)


func _on_season_complete() -> void:
	if _had_events:
		await get_tree().create_timer(0.5).timeout
	_had_events = false
	# Reset portraits and clear speech bubble before leaving event screen
	_reset_advisor_portraits()
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
	_clear_portrait_clicks()
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


func _clear_portrait_clicks() -> void:
	for entry in _portrait_connections:
		var portrait: TextureRect = entry["portrait"]
		var bound: Callable = entry["callable"]
		if is_instance_valid(portrait):
			if portrait.gui_input.is_connected(bound):
				portrait.gui_input.disconnect(bound)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_portrait_connections.clear()


func _on_narrative_text_added(text: String) -> void:
	if narrative_label.text != "":
		narrative_label.text += "\n"
	narrative_label.text += text
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)
