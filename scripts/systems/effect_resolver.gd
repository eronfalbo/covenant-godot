class_name EffectResolver
## Translates JSON effect arrays into GameState mutations.
##
## Effect format:
##   {"op": "set_flag", "flag": "altar_built", "value": true}
##   {"op": "modify", "stat": "chain_integrity", "delta": 3}
##   {"op": "modify_root", "index": 2, "delta": 0.3}
##   {"op": "set_stat", "stat": "livestock", "value": 25}
##   {"op": "show_text", "text": "You dig the rows beside the altar stones."}
##   {"op": "show_advisor", "name": "Shem", "text": "Something to say."}
##   {"op": "conditional", "if": {"flag": "vine_location"},
##       "then": [...effects], "else": [...effects]}
##   {"op": "skill_test", "stat": "chain_integrity", "difficulty": 40,
##       "success": [...effects], "failure": [...effects]}
##   {"op": "modify_dict", "dict": "bnei_elohim", "key": "captured", "delta": 5}
##   {"op": "set_dict", "dict": "bnei_elohim", "key": "captured", "value": 0}
##   {"op": "append_array", "array": "bc_assignments", "value": {"id": 1, "type": "Teaching"}}

## Emitted when a "show_text" effect fires. The event screen listens for this.
## We use a static reference to avoid autoload dependency.
static var narrative_text_requested: Callable = func(_t: String): pass
static var advisor_text_requested: Callable = func(_n: String, _t: String): pass


static func apply_effects(effects: Array, gs: Node = null) -> void:
	if gs == null:
		gs = _get_game_state()
	if gs == null:
		push_error("EffectResolver: GameState not found")
		return

	for effect in effects:
		if not effect is Dictionary:
			continue
		var op: String = effect.get("op", "")
		match op:
			"set_flag":
				var value = effect.get("value", true)
				gs.set_flag(effect["flag"], value)

			"modify":
				gs.modify_stat(effect["stat"], effect["delta"])

			"modify_root":
				var idx: int = int(effect["index"])
				if idx < 0 or idx >= gs.roots.size():
					push_warning("EffectResolver: root index %d out of bounds" % idx)
				else:
					gs.roots[idx] = clampf(gs.roots[idx] + effect["delta"], 0.0, 10.0)
					gs.state_changed.emit()

			"set_stat":
				var stat_name: String = effect["stat"]
				gs.set(stat_name, effect["value"])
				gs.state_changed.emit()

			"show_text":
				narrative_text_requested.call(effect["text"])

			"show_advisor":
				advisor_text_requested.call(effect["name"], effect["text"])

			"conditional":
				var predicate: Dictionary = effect.get("if", {})
				if ConditionChecker.evaluate(predicate, gs):
					apply_effects(effect.get("then", []), gs)
				else:
					apply_effects(effect.get("else", []), gs)

			"skill_test":
				var stat_val: float = gs.get(effect["stat"])
				var difficulty: int = int(effect.get("difficulty", 50))
				var variance: int = int(effect.get("variance", 20))
				var result := _roll_skill_test(stat_val, difficulty, variance)
				var success: bool = result["success"]
				var margin: int = result["margin"]
				var desc: String = result["description"]
				# Show roll description if present
				if effect.get("show_roll", true):
					narrative_text_requested.call("[%s]" % desc)
				# Apply success or failure branch
				if success:
					apply_effects(effect.get("success", []), gs)
				else:
					apply_effects(effect.get("failure", []), gs)
				# Apply margin-based effects if present
				if margin > 10 and effect.has("great_success"):
					apply_effects(effect["great_success"], gs)

			"modify_dict":
				var dict_name: String = effect["dict"]
				var key: String = effect["key"]
				var delta = effect["delta"]
				var d: Dictionary = gs.get(dict_name)
				if d is Dictionary:
					d[key] = d.get(key, 0) + delta
					gs.state_changed.emit()

			"set_dict":
				var dict_name: String = effect["dict"]
				var key: String = effect["key"]
				var value = effect["value"]
				var d: Dictionary = gs.get(dict_name)
				if d is Dictionary:
					d[key] = value
					gs.state_changed.emit()

			"append_array":
				var arr_name: String = effect["array"]
				var value = effect["value"]
				var arr: Array = gs.get(arr_name)
				if arr is Array:
					arr.append(value)
					gs.state_changed.emit()

			_:
				push_warning("EffectResolver: unknown op '%s'" % op)


## Skill test: roll against a stat value with difficulty and variance.
## Returns {success: bool, margin: int, description: String}
## Port of Python skill_test(stat, difficulty, variance=20)
static func _roll_skill_test(stat_val: float, difficulty: int, variance: int = 20) -> Dictionary:
	var roll: int = randi_range(-variance, variance)
	var effective: int = int(stat_val) + roll
	var margin: int = effective - difficulty
	var success: bool = margin >= 0

	var desc: String
	if margin > 15:
		desc = "Great success"
	elif margin > 5:
		desc = "Success"
	elif margin >= 0:
		desc = "Narrow success"
	elif margin > -10:
		desc = "Narrow failure"
	elif margin > -20:
		desc = "Failure"
	else:
		desc = "Crushing failure"

	return {"success": success, "margin": margin, "description": desc}


static func _get_game_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("/root/GameState")
	return null
