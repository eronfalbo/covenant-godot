extends Control
## IntroSequence — Opening text sequence before Year 0 begins.
## Ported verbatim from covenant.py show_intro().

@onready var text_label: RichTextLabel = $ScrollContainer/IntroText
@onready var continue_btn: Button = $ContinueButton
@onready var choice_container: VBoxContainer = $ChoiceContainer
@onready var door_illustration: TextureRect = $DoorIllustration
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

const PAGE_FADE_DURATION := 0.4

# Three pages, matching the Python prototype's three "Press Enter" beats.
var _pages: Array[Array] = [
	# Page 1 — The door opens
	[
		"You push the door.",
		"It has not moved in a year. The wood is swollen, the pitch cracked. Your sons brace behind you — Shem at your right shoulder, Ham at your left, Japheth pressing from behind. The animals below stamp and cry. They know.",
		"The door gives.",
		"Light floods in — raw, white, blinding. You shield your eyes. Wind hits your face for the first time in a year and ten days. The sky is enormous. The horizon stretches in every direction — mountains, plains, rivers cutting new paths through land that belongs to no one.",
		"All of it. Open. Waiting.",
		"You are Noah.",
		"You have carried this since your great-grandfather pressed it into your arm — you were young, and his hand was steady, and then he was gone. Not dead. Gone. The fire he left in your skin has not gone out in six hundred years.",
	],
	# Page 2 — The emptiness
	[
		"[indent][i]\"In the second month, on the twenty-seventh day of the month, the earth was dry.\"[/i]\n[right](Gen 8:14)[/right][/indent]",
		"From the doorway you see it all. The rock below is slick with silt — a grey paste that covers everything, the residue of a world ground to powder by the water. White salt crusts the boulders where pools have dried. The air is thick and warm, heavy with moisture — the sun is drawing the water back out of the earth, and a low haze blurs the horizon in every direction.",
		"Below the mountain, the plain is brown and flat. Where forests once stood, nothing. Where villages once smoked, nothing. Waterlines scar the hillsides — you can trace how high it reached. Driftwood and bone lie tangled in the gullies. The rivers are new, cutting raw channels through earth that has forgotten what a current feels like, carrying silt down to valleys that are still more lake than land.",
		"No birds sing. No insects hum. The silence is not the silence of night — it is the silence of absence. Even the wind sounds wrong, moving over a world with nothing in it to rustle or creak or answer back.",
		"You have never seen the world this empty. Even before the water, there was always something — a sound, a movement, a fire on a distant hill.",
		"Now there is only you.",
		"Your wife, Naamah, stands beside you. Your three sons and their wives behind. Eight souls on a bare mountain, blinking in the haze.",
		"The whole world.",
	],
	# Page 3 — The weight / the choice
	[
		"[indent][i]\"Be fruitful and multiply and fill the earth.\"[/i]\n[right](Gen 9:1)[/right][/indent]",
		"Now the decision must be yours.",
		"Six hundred and one years old. Everything the first man knew — every law, every name of every star — passed mouth to ear through Adam, Seth, Enoch, Methuselah who lived longer than anyone and died the week the rain began. Ten generations. You are the last mouth. There are no more ears unless you make them.",
		"The vastness is not a gift. It is a weight. Every hill, every valley, every river — all of it waiting to be filled by your hand, your word, your strength alone.",
		"The ark is warm behind you. The world ahead is silent. Inside, your family was one. Inside, you fed every creature and every creature was fed. Inside, the world was small enough to tend.",
		"Out here, the garden has no walls.",
		"Your sons wait. Naamah watches your face.",
		"The fire in your arm. The steadiness in your hands — the thing that kept you lifting planks for a hundred and twenty years while the world laughed. It was old when it reached you. It will outlive you if you find the next hands.",
		"Will you step out?",
		"Will you keep the covenant?",
	],
]

var _current_page: int = 0


func _ready() -> void:
	text_label.text = ""
	continue_btn.text = "Continue"
	continue_btn.pressed.connect(_on_continue)
	choice_container.visible = false
	_show_page()


func setup(_data: Dictionary) -> void:
	pass


func _show_page() -> void:
	if _current_page >= _pages.size():
		return

	continue_btn.visible = false

	if _current_page > 0:
		var fade_out := create_tween()
		fade_out.tween_property(text_label, "modulate:a", 0.0, PAGE_FADE_DURATION)
		await fade_out.finished

	if _current_page == 1 and door_illustration.visible:
		var fade_img := create_tween()
		fade_img.tween_property(door_illustration, "modulate:a", 0.0, PAGE_FADE_DURATION)
		fade_img.parallel().tween_property(title_label, "modulate:a", 0.0, PAGE_FADE_DURATION)
		fade_img.parallel().tween_property(subtitle_label, "modulate:a", 0.0, PAGE_FADE_DURATION)
		await fade_img.finished
		door_illustration.visible = false
		title_label.visible = false
		subtitle_label.visible = false
		scroll_container.offset_top = 80.0

	text_label.text = ""
	var paragraphs: Array = _pages[_current_page]
	for i in paragraphs.size():
		if i > 0:
			text_label.text += "\n\n"
		text_label.text += paragraphs[i]

	await get_tree().process_frame
	scroll_container.scroll_vertical = 0

	text_label.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(text_label, "modulate:a", 1.0, PAGE_FADE_DURATION)
	await fade_in.finished

	if _current_page == _pages.size() - 1:
		_show_covenant_choice()
	else:
		continue_btn.text = "Continue"
		continue_btn.visible = true


func _on_continue() -> void:
	if _current_page == 0:
		AdaptiveMusic.play_door_sound()
		AdaptiveMusic.play_intro_music()
	_current_page += 1
	_show_page()


func _show_covenant_choice() -> void:
	continue_btn.visible = false
	choice_container.visible = true

	for child in choice_container.get_children():
		child.queue_free()

	var btn_yes := Button.new()
	btn_yes.text = "Yes. Step out. Build. Fill the earth."
	btn_yes.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_yes.add_theme_font_size_override("font_size", UIConstants.CHOICE_SIZE + 2)
	btn_yes.add_theme_color_override("font_color", UIConstants.GOLD)
	btn_yes.add_theme_color_override("font_hover_color", UIConstants.IVORY)
	btn_yes.pressed.connect(_on_yes)
	choice_container.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "No. Close the door. Stay where it is safe."
	btn_no.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_no.add_theme_font_size_override("font_size", UIConstants.CHOICE_SIZE + 2)
	btn_no.add_theme_color_override("font_color", UIConstants.GOLD)
	btn_no.add_theme_color_override("font_hover_color", UIConstants.IVORY)
	btn_no.pressed.connect(_on_no)
	choice_container.add_child(btn_no)


func _on_no() -> void:
	choice_container.visible = false
	text_label.text = ""
	text_label.text += "The door closes. The dark returns."
	text_label.text += "\nIt is warm. It is safe. Nothing will be asked of you."
	text_label.text += "\n\nThis game is not for you."
	text_label.text += "\nPlease choose another game."
	text_label.text += "\nIf you paid for this one, we will reimburse you."
	text_label.text += "\n\n\n[center][color=%s]G A M E   O V E R[/color][/center]" % UIConstants.GOLD_HEX

	continue_btn.visible = true
	continue_btn.text = "Try Again"
	_disconnect_continue()
	continue_btn.pressed.connect(_on_try_again)


func _on_yes() -> void:
	choice_container.visible = false
	continue_btn.visible = false

	var fade_out := create_tween()
	fade_out.tween_property(text_label, "modulate:a", 0.0, 0.8)
	await fade_out.finished

	text_label.text = ""
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await get_tree().create_timer(1.0).timeout

	text_label.modulate.a = 1.0
	text_label.text = "[center]\n\n\n[color=%s][font_size=64]C   O   V   E   N   A   N   T[/font_size][/color][/center]" % UIConstants.GOLD_HEX  # Title size intentionally hardcoded

	text_label.modulate.a = 0.0
	var title_in := create_tween()
	title_in.tween_property(text_label, "modulate:a", 1.0, 2.0)
	await title_in.finished

	await get_tree().create_timer(0.8).timeout

	text_label.text += "\n\n[center][color=%s][font_size=%d]H a r n e s s   t h e   F l a m e[/font_size][/color][/center]" % [UIConstants.GOLD_HEX, UIConstants.HEADER_SIZE]

	await get_tree().create_timer(2.0).timeout

	text_label.text += "\n\n\n\n[center]You know what to do first.[/center]"
	text_label.text += "\n[center]You have always known.[/center]"
	text_label.text += "\n\n[center]You begin to gather stones.[/center]"

	await get_tree().create_timer(1.5).timeout

	continue_btn.visible = true
	continue_btn.text = "Begin"
	_disconnect_continue()
	continue_btn.pressed.connect(_on_begin)


func _on_begin() -> void:
	continue_btn.disabled = true
	GameState.phase = "ararat"
	GameState.year = 0
	GameState.season_idx = 0

	print("[Intro] _on_begin: connecting run_season_events to transition_complete")
	# CRITICAL: Use Callable bound to EventManager (autoload, never freed).
	# A lambda here would be owned by this intro node, which gets queue_free'd
	# during switch_to — Godot removes the connection and run_season_events
	# is never called, causing a blank-screen freeze.
	ScreenManager.transition_complete.connect(
		Callable(EventManager, "run_season_events"),
		CONNECT_ONE_SHOT
	)
	print("[Intro] _on_begin: calling switch_to(EVENT)")
	ScreenManager.switch_to(ScreenManager.Screen.EVENT)


func _on_try_again() -> void:
	continue_btn.disabled = true
	GameState.reset()
	get_tree().reload_current_scene()


func _disconnect_continue() -> void:
	if continue_btn.pressed.is_connected(_on_continue):
		continue_btn.pressed.disconnect(_on_continue)
	if continue_btn.pressed.is_connected(_on_begin):
		continue_btn.pressed.disconnect(_on_begin)
	if continue_btn.pressed.is_connected(_on_try_again):
		continue_btn.pressed.disconnect(_on_try_again)
