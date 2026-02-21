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
var _active_advisor: int = -1
var _portrait_connections: Array = []  # [{portrait, callable}] for cleanup
var _typewriter_tween: Tween = null
var _blink_tweens: Dictionary = {}  # key → Tween

const PARAGRAPH_DELAY := 0.8


func _ready() -> void:
	EventManager.event_started.connect(_on_event_started)
	EventManager.narrative_text_added.connect(_on_narrative_text_added)
	choice_container.visible = false


func setup(_data: Dictionary) -> void:
	pass


func _exit_tree() -> void:
	_stop_all_blinks()
	_clear_portrait_clicks()


func _on_event_started(event_data: Dictionary) -> void:
	_current_event = event_data
	_narrative_queue.clear()
	_narrative_index = 0
	narrative_label.text = ""
	quote_text.text = ""
	quote_box.visible = false
	choice_container.visible = false
	_active_advisor = -1
	_portrait_connections.clear()

	for child in choice_container.get_children():
		child.queue_free()

	_reset_advisor_portraits()
	# Enforce elders label font size every event (protects against stale tscn cache)
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("get_elders_label"):
		main_node.get_elders_label()  # This call enforces font_size = 22
	_load_illustration(event_data.get("illustration", ""))
	event_title.text = event_data.get("name", "")
	_update_music_scene(event_data.get("id", ""))

	_narrative_queue = event_data.get("narrative", [])
	_narrative_index = 0
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
		_show_choices()
		return

	var item: Dictionary = _narrative_queue[_narrative_index]
	_narrative_index += 1

	var type: String = item.get("type", "text")

	if type == "quote":
		_add_quote(item)
		_display_next_narrative()
		return

	if type == "white_screen":
		await _show_white_screen(item.get("duration", 3.0))
		_display_next_narrative()
		return

	# Regular text — typewriter reveal
	if narrative_label.text != "":
		narrative_label.text += "\n\n"

	var full_text: String = narrative_label.text + item.get("content", "")
	var old_len: int = narrative_label.text.length()
	narrative_label.text = full_text

	# Typewriter: reveal new characters one by one
	narrative_label.visible_characters = old_len
	var new_chars: int = full_text.length() - old_len
	var duration: float = float(new_chars) / UIConstants.TYPEWRITER_CPS

	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(narrative_label, "visible_characters", full_text.length(), duration)

	# Allow click to skip typewriter
	_typewriter_tween.finished.connect(func():
		narrative_label.visible_characters = -1
	, CONNECT_ONE_SHOT)

	await _typewriter_tween.finished

	# Auto-scroll to bottom
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)

	await get_tree().create_timer(PARAGRAPH_DELAY).timeout
	_display_next_narrative()


func _input(event: InputEvent) -> void:
	# Click to skip typewriter
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typewriter_tween and _typewriter_tween.is_valid():
			_typewriter_tween.kill()
			narrative_label.visible_characters = -1


func _add_quote(item: Dictionary) -> void:
	var content: String = item.get("content", "")
	var source: String = item.get("source", "")

	if quote_text.text != "":
		quote_text.text += "\n\n"

	quote_text.text += "[i]%s[/i]" % content
	if source != "":
		quote_text.text += "\n[font_size=13][color=%s]— %s[/color][/font_size]" % [UIConstants.GOLD_HEX, source]

	quote_box.visible = true


func _show_choices() -> void:
	var choices: Array = _current_event.get("choices", [])
	var advisors: Array = _current_event.get("advisors", [])
	print("[EventScreen] _show_choices: %d choices, %d advisors" % [choices.size(), advisors.size()])
	if choices.is_empty():
		return

	choice_container.visible = true

	if not advisors.is_empty():
		_setup_portrait_clicks(advisors)
		_start_advisor_blinks(advisors)

	# Stagger choice button appearance
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.get("label", "Choice %d" % (i + 1))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, UIConstants.CHOICE_BUTTON_HEIGHT)
		btn.add_theme_font_size_override("font_size", UIConstants.CHOICE_SIZE)
		btn.add_theme_color_override("font_color", UIConstants.GOLD)
		btn.add_theme_color_override("font_hover_color", UIConstants.IVORY)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		btn.modulate.a = 0.0
		choice_container.add_child(btn)

		# Stagger fade-in
		var tw := create_tween()
		tw.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(i * UIConstants.CHOICE_STAGGER)


func _get_advisor_hbox() -> HBoxContainer:
	## Centralized access to advisor portrait container.
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("get_advisor_portraits"):
		return main_node.get_advisor_portraits()
	return null


func _setup_portrait_clicks(advisors: Array) -> void:
	var hbox := _get_advisor_hbox()
	if not hbox:
		return

	var advisor_names: Array[String] = []
	for adv in advisors:
		advisor_names.append(adv.get("name", "").to_lower())

	var portraits := _get_portrait_dict(hbox)
	for key in portraits:
		var portrait: TextureRect = portraits[key]
		if not portrait:
			continue

		var advisor_idx := -1
		for i in advisor_names.size():
			if advisor_names[i].contains(key):
				advisor_idx = i
				break

		if advisor_idx >= 0:
			portrait.modulate = UIConstants.PORTRAIT_AVAILABLE
			portrait.mouse_filter = Control.MOUSE_FILTER_STOP
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var bound_callable := _on_portrait_input.bind(advisor_idx)
			portrait.gui_input.connect(bound_callable)
			_portrait_connections.append({"portrait": portrait, "callable": bound_callable})
		else:
			portrait.modulate = UIConstants.PORTRAIT_DIMMED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_portrait_input(event: InputEvent, advisor_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var advisors: Array = _current_event.get("advisors", [])
	if advisor_idx >= advisors.size():
		return

	var hbox := _get_advisor_hbox()
	if not hbox:
		return
	var bubble := hbox.get_node_or_null("SpeechBubble") as RichTextLabel
	if not bubble:
		return

	# Stop elders label blink on first click
	_stop_blink("elders_label")

	if _active_advisor == advisor_idx:
		bubble.text = ""
		_active_advisor = -1
		_highlight_available_advisors(advisors)
		return

	_active_advisor = advisor_idx
	var adv: Dictionary = advisors[advisor_idx]
	bubble.text = "[b][color=%s]%s:[/color][/b] %s" % [
		UIConstants.GOLD_HEX, adv.get("name", ""), adv.get("text", "")
	]

	# Stop blink on the clicked portrait and pulse it
	var speaker_name: String = adv.get("name", "").to_lower()
	for key in ["shem", "ham", "japheth", "naamah"]:
		if speaker_name.contains(key):
			_stop_blink("portrait_" + key)
			break
	_highlight_strip_portrait(speaker_name)


func _on_choice_pressed(choice_idx: int) -> void:
	_stop_all_blinks()
	for child in choice_container.get_children():
		if child is Button:
			child.disabled = true

	_reset_advisor_portraits()
	EventManager.submit_choice(_current_event["id"], choice_idx)


func _highlight_available_advisors(advisors: Array) -> void:
	var hbox := _get_advisor_hbox()
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
			portrait.modulate = UIConstants.PORTRAIT_AVAILABLE if has_advice else UIConstants.PORTRAIT_DIMMED


func _highlight_strip_portrait(speaker_name: String) -> void:
	var hbox := _get_advisor_hbox()
	if not hbox:
		return
	var portraits := _get_portrait_dict(hbox)
	for key in portraits:
		var portrait = portraits[key]
		if portrait:
			if speaker_name.contains(key):
				portrait.modulate = UIConstants.PORTRAIT_ACTIVE
				# Brief scale pulse
				portrait.pivot_offset = portrait.size / 2
				var tw := create_tween()
				tw.tween_property(portrait, "scale", Vector2(1.1, 1.1), UIConstants.PORTRAIT_PULSE_DURATION / 2)
				tw.tween_property(portrait, "scale", Vector2(1.0, 1.0), UIConstants.PORTRAIT_PULSE_DURATION / 2)
			else:
				portrait.modulate = UIConstants.PORTRAIT_DIMMED


func _get_portrait_dict(hbox: Node) -> Dictionary:
	return {
		"shem": hbox.get_node_or_null("ShemPortrait"),
		"ham": hbox.get_node_or_null("HamPortrait"),
		"japheth": hbox.get_node_or_null("JaphethPortrait"),
		"naamah": hbox.get_node_or_null("NaamahPortrait"),
	}


func _reset_advisor_portraits() -> void:
	_stop_all_blinks()
	_clear_portrait_clicks()
	var hbox := _get_advisor_hbox()
	if not hbox:
		return
	for pname in ["ShemPortrait", "HamPortrait", "JaphethPortrait", "NaamahPortrait"]:
		var portrait := hbox.get_node_or_null(pname) as TextureRect
		if portrait:
			portrait.modulate = UIConstants.PORTRAIT_RESET
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


func _start_advisor_blinks(advisors: Array) -> void:
	print("[EventScreen] Starting advisor blinks for %d advisors" % advisors.size())
	# Blink the "ELDERS" label
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("get_elders_label"):
		var label: Label = main_node.get_elders_label()
		if label:
			print("[EventScreen] Blinking ELDERS label")
			_start_blink(label, "elders_label")
		else:
			print("[EventScreen] WARN: get_elders_label returned null")
	else:
		print("[EventScreen] WARN: Main node not found or missing get_elders_label")

	# Blink available portraits
	var hbox := _get_advisor_hbox()
	if not hbox:
		print("[EventScreen] WARN: advisor hbox not found")
		return
	var advisor_names: Array[String] = []
	for adv in advisors:
		advisor_names.append(adv.get("name", "").to_lower())
	var portraits := _get_portrait_dict(hbox)
	for key in portraits:
		var portrait: TextureRect = portraits[key]
		if not portrait:
			continue
		for advisor_name in advisor_names:
			if advisor_name.contains(key):
				print("[EventScreen] Blinking portrait: %s" % key)
				_start_blink(portrait, "portrait_" + key)
				break


func _start_blink(node: CanvasItem, key: String) -> void:
	_stop_blink(key)
	node.modulate.a = 1.0
	var tw := create_tween().set_loops()
	tw.tween_property(node, "modulate:a", 0.15, 0.35)
	tw.tween_property(node, "modulate:a", 1.0, 0.35)
	_blink_tweens[key] = tw
	print("[EventScreen] Blink tween created for key=%s, valid=%s" % [key, tw.is_valid()])


func _stop_blink(key: String) -> void:
	if key in _blink_tweens:
		if _blink_tweens[key].is_valid():
			_blink_tweens[key].kill()
		_blink_tweens.erase(key)


func _stop_all_blinks() -> void:
	for key in _blink_tweens:
		if _blink_tweens[key].is_valid():
			_blink_tweens[key].kill()
	_blink_tweens.clear()
	# Restore alpha on elders label
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("get_elders_label"):
		var label: Label = main_node.get_elders_label()
		if label:
			label.modulate.a = 1.0
	# Restore portrait alpha
	var hbox := _get_advisor_hbox()
	if hbox:
		var portraits := _get_portrait_dict(hbox)
		for key in portraits:
			if portraits[key]:
				portraits[key].modulate.a = 1.0


func _show_white_screen(duration: float) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(1, 1, 1, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	await get_tree().create_timer(duration).timeout
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 1.0)
	await tween.finished
	overlay.queue_free()


func _update_music_scene(event_id: String) -> void:
	match event_id:
		"A03":
			AdaptiveMusic.trigger_festival("tents")
		"A06":
			AdaptiveMusic.trigger_festival("light")
		"A09":
			AdaptiveMusic.trigger_festival("covenant")
		"A11":
			AdaptiveMusic.set_scene_override("tent_before")
		"A12":
			AdaptiveMusic.set_scene_override("tent_breach")
		"A13":
			AdaptiveMusic.set_scene_override("tent_after")
		_:
			if AdaptiveMusic.scene_override != "":
				AdaptiveMusic.set_scene_override("")


func _on_narrative_text_added(text: String) -> void:
	if narrative_label.text != "":
		narrative_label.text += "\n"
	narrative_label.text += text
	await get_tree().process_frame
	narrative_scroll.scroll_vertical = int(narrative_scroll.get_v_scroll_bar().max_value)
