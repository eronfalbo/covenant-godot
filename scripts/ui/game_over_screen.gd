extends Control
## GameOverScreen — Death, or departure.

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
	var gs := GameState

	if gs.victory and gs.phase == "ararat":
		_setup_ararat_departure()
		return

	if data.get("demo_complete", false):
		_setup_ararat_departure()
		return

	if gs.victory:
		title_label.text = "The Covenant Endures"
	else:
		title_label.text = "The Tree Has Withered"

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
	if gs.tree_of_life <= 0:
		lines.append("The Tree that Adam tended, that Seth watered, that Methuselah guarded —")
		lines.append("its roots have withered. The burning branches go dark.")
		lines.append("The transmission ends here, on a bare mountain,")
		lines.append("with no one left who remembers how to tend it.")
	elif gs.food <= 0:
		lines.append("The land could not sustain you. The covenant requires")
		lines.append("bodies as well as souls — and the bodies scattered.")
	elif gs.ham_centralisation >= 80:
		lines.append("A tower rises where the altar stood. The covenant")
		lines.append("is not forgotten — it is replaced. Ham's children")
		lines.append("will remember Noah. They will not remember what he carried.")
	else:
		lines.append("The roots that ran from Adam to Seth to Chanoch")
		lines.append("to Methuselah to Lamech to you — withered.")

	lines.append("")
	lines.append("[color=#f5f2eb66]There is no one left to try again.[/color]")

	reason_label.text = "\n".join(lines)


func _setup_ararat_departure() -> void:
	var gs := GameState
	var gold := UIConstants.GOLD_HEX

	title_label.text = "The Descent from Ararat"

	quit_btn.visible = true
	quit_btn.text = "Play Again"
	quit_btn.pressed.connect(_on_restart)

	# ── Build the scorecard ──
	var lines: Array[String] = []

	# Opening — the moment
	lines.append("")
	lines.append("[font_size=22][color=%s]Seven years on the mountain.[/color][/font_size]" % gold)
	lines.append("[font_size=22][color=%s]Noah gathers his sons at the altar one last time.[/color][/font_size]" % gold)
	lines.append("")

	# ── The Tree of Life ──
	var fire := gs.tree_of_life
	var fire_pct := int(fire)
	var fire_bar := _make_bar(fire / 100.0, 20)
	if fire >= 80:
		lines.append("[font_size=20]The Tree of Life burns [color=%s]bright[/color].  %s  %d%%[/font_size]" % [gold, fire_bar, fire_pct])
	elif fire >= 50:
		lines.append("[font_size=20]The Tree of Life still burns.  %s  %d%%[/font_size]" % [fire_bar, fire_pct])
	elif fire >= 25:
		lines.append("[font_size=20]The Tree of Life [color=%s]flickers[/color].  %s  %d%%[/font_size]" % [UIConstants.WARN_ORANGE, fire_bar, fire_pct])
	else:
		lines.append("[font_size=20]The Tree of Life is [color=%s]barely alive[/color].  %s  %d%%[/font_size]" % [UIConstants.CRITICAL_RED, fire_bar, fire_pct])

	lines.append("")

	# ── The Eight Roots ──
	lines.append("[font_size=18][color=%s]The Eight Roots[/color][/font_size]" % gold)
	var avg_root := 0.0
	for i in range(gs.roots.size()):
		var val: float = gs.roots[i]
		avg_root += val
		var bar := _make_bar(val / 10.0, 12)
		var name: String = gs.ROOT_SHORT[i] if i < gs.ROOT_SHORT.size() else "Root %d" % i
		var color := gold if val >= 7.0 else ("#f5f2eb" if val >= 4.0 else UIConstants.WARN_ORANGE)
		lines.append("  [font_size=16][color=%s]%s[/color]  %s  %.1f[/font_size]" % [color, name, bar, val])
	avg_root /= gs.roots.size()
	lines.append("")

	# ── Tents carried forward ──
	var tent_count: int = gs.buildings_completed.size()
	if tent_count > 0:
		var tent_word := "tent" if tent_count == 1 else "tents"
		lines.append("[font_size=18][color=%s]%d %s dismantled and packed for the journey:[/color][/font_size]" % [gold, tent_count, tent_word])
		for tid in gs.buildings_completed:
			var def: Dictionary = gs.TENT_DEFS.get(tid, {})
			var tent_name: String = def.get("name", tid)
			lines.append("  [font_size=16]• %s[/font_size]" % tent_name)
	else:
		lines.append("[font_size=18][color=#f5f2ebb3]No tents built. The family travels light.[/color][/font_size]")
	lines.append("")

	# ── The Two Forces ──
	lines.append("[font_size=18][color=%s]The Two Forces[/color][/font_size]" % gold)
	var assim := gs.assimilation
	var host := gs.hostility
	var assim_bar := _make_bar(assim / 15.0, 12)  # relative to Ararat cap
	var host_bar := _make_bar(host / 12.0, 12)
	lines.append("  [font_size=16]%s (%s)  %s  %s[/font_size]" % [gs.assimilation_stage_name, gs.assimilation_label, assim_bar, "%.0f%%" % assim])
	lines.append("  [font_size=16]%s (%s)  %s  %s[/font_size]" % [gs.hostility_stage_name, gs.hostility_label, host_bar, "%.0f%%" % host])
	lines.append("[font_size=14][color=#f5f2eb66]  These forces follow you down the mountain.[/color][/font_size]")
	lines.append("")

	# ── The family ──
	var pop: int = gs.total_population
	lines.append("[font_size=18]%d souls descend the mountain.[/font_size]" % pop)
	lines.append("")

	# ── Closing ──
	lines.append("[font_size=20][color=%s]━━━━━━━━━━━━━━━━━━━━━━━━━━[/color][/font_size]" % gold)
	lines.append("")

	# Vine location
	var vine_loc: String = str(gs.flags.get("vine_location", ""))
	if vine_loc != "":
		var loc_text := {"altar": "beside the altar", "south": "on the south slope", "valley": "in the valley"}
		lines.append("[font_size=18][i]The vine grows %s.[/i][/font_size]" % loc_text.get(vine_loc, vine_loc))

	if gs.flags.get("altar_built", false):
		lines.append("[font_size=18][i]The altar stands on Ararat, behind them.[/i][/font_size]")

	lines.append("")
	lines.append("[font_size=22][color=%s]The road to Shinar lies ahead.[/color][/font_size]" % gold)
	lines.append("[font_size=22][color=%s]Everything you built — everything you tended —[/color][/font_size]" % gold)
	lines.append("[font_size=22][color=%s]is all they will carry down.[/color][/font_size]" % gold)
	lines.append("")
	lines.append("[font_size=16][color=#f5f2eb66][i]End of Ararat. The covenant continues.[/i][/color][/font_size]")

	reason_label.text = "\n".join(lines)


## Build a visual bar: ████░░░░░░
func _make_bar(ratio: float, width: int) -> String:
	ratio = clampf(ratio, 0.0, 1.0)
	var filled: int = int(ratio * width)
	var empty: int = width - filled
	return "█".repeat(filled) + "░".repeat(empty)


func _on_restart() -> void:
	quit_btn.disabled = true
	GameState.reset()
	get_tree().reload_current_scene()
