class_name ConditionChecker
## Evaluates JSON predicate expressions against GameState.
##
## Predicate format examples:
##   {"and": [{"flag": "altar_built"}, {"year_eq": 0}]}
##   {"or": [{"stat_gte": ["chain_integrity", 50]}, {"flag": "noah_taught_law"}]}
##   {"not": {"flag": "altar_built"}}
##   {"flag": "altar_built"}
##   {"flag_eq": ["ham_rebuke_severity", 3]}
##   {"year_eq": 0}, {"year_gte": 10}
##   {"season_eq": 0}
##   {"phase_eq": "ararat"}
##   {"stat_gte": ["ham_centralisation", 20]}
##   {"event_not_fired": "A01"}


static func evaluate(predicate: Dictionary, gs: Node = null) -> bool:
	if predicate.is_empty():
		return true
	if gs == null:
		gs = Engine.get_singleton("GameState") if Engine.has_singleton("GameState") else null
		if gs == null:
			gs = _get_game_state()

	# Logical operators
	if predicate.has("and"):
		for p in predicate["and"]:
			if not evaluate(p, gs):
				return false
		return true

	if predicate.has("or"):
		for p in predicate["or"]:
			if evaluate(p, gs):
				return true
		return false

	if predicate.has("not"):
		return not evaluate(predicate["not"], gs)

	# Flag checks
	if predicate.has("flag"):
		var flag_name: String = predicate["flag"]
		if not gs.flags.has(flag_name):
			push_warning("ConditionChecker: unknown flag '%s' — check for typos" % flag_name)
		var val = gs.flags.get(flag_name, false)
		# Treat null, false, 0, and "" as falsy
		if val == null:
			return false
		if val is bool:
			return val
		if val is int or val is float:
			return val != 0
		if val is String:
			return val != ""
		return true

	if predicate.has("flag_eq"):
		var arr: Array = predicate["flag_eq"]
		return gs.flags.get(arr[0], null) == arr[1]

	if predicate.has("flag_not"):
		var val = gs.flags.get(predicate["flag_not"], false)
		if val == null:
			return true
		if val is bool:
			return not val
		if val is int or val is float:
			return val == 0
		if val is String:
			return val == ""
		return false

	# Time checks
	if predicate.has("year_eq"):
		return gs.year == int(predicate["year_eq"])

	if predicate.has("year_gte"):
		return gs.year >= int(predicate["year_gte"])

	if predicate.has("year_lte"):
		return gs.year <= int(predicate["year_lte"])

	if predicate.has("season_eq"):
		return gs.season_idx == int(predicate["season_eq"])

	# Phase check
	if predicate.has("phase_eq"):
		return gs.phase == predicate["phase_eq"]

	# Stat comparison
	if predicate.has("stat_gte"):
		var arr: Array = predicate["stat_gte"]
		var val = gs.get(arr[0])
		return val != null and val >= arr[1]

	if predicate.has("stat_lte"):
		var arr: Array = predicate["stat_lte"]
		var val = gs.get(arr[0])
		return val != null and val <= arr[1]

	if predicate.has("stat_gt"):
		var arr: Array = predicate["stat_gt"]
		var val = gs.get(arr[0])
		return val != null and val > arr[1]

	if predicate.has("stat_lt"):
		var arr: Array = predicate["stat_lt"]
		var val = gs.get(arr[0])
		return val != null and val < arr[1]

	if predicate.has("stat_eq"):
		var arr: Array = predicate["stat_eq"]
		var val = gs.get(arr[0])
		return val != null and val == arr[1]

	# Year greater/less than
	if predicate.has("year_gt"):
		return gs.year > int(predicate["year_gt"])

	if predicate.has("year_lt"):
		return gs.year < int(predicate["year_lt"])

	# Dictionary key access: {"dict_gte": ["bnei_elohim", "captured", 50]}
	if predicate.has("dict_gte"):
		var arr: Array = predicate["dict_gte"]
		var dict_val = gs.get(arr[0])
		if dict_val is Dictionary:
			return dict_val.get(arr[1], 0) >= arr[2]
		return false

	if predicate.has("dict_lte"):
		var arr: Array = predicate["dict_lte"]
		var dict_val = gs.get(arr[0])
		if dict_val is Dictionary:
			return dict_val.get(arr[1], 0) <= arr[2]
		return false

	if predicate.has("dict_eq"):
		var arr: Array = predicate["dict_eq"]
		var dict_val = gs.get(arr[0])
		if dict_val is Dictionary:
			return dict_val.get(arr[1], 0) == arr[2]
		return false

	if predicate.has("dict_gt"):
		var arr: Array = predicate["dict_gt"]
		var dict_val = gs.get(arr[0])
		if dict_val is Dictionary:
			return dict_val.get(arr[1], 0) > arr[2]
		return false

	if predicate.has("dict_lt"):
		var arr: Array = predicate["dict_lt"]
		var dict_val = gs.get(arr[0])
		if dict_val is Dictionary:
			return dict_val.get(arr[1], 0) < arr[2]
		return false

	# Array any: {"any_lte": ["pillars", 4]} — true if any element <= value
	if predicate.has("any_lte"):
		var arr: Array = predicate["any_lte"]
		var array_val = gs.get(arr[0])
		if array_val is Array:
			for v in array_val:
				if v <= arr[1]:
					return true
		return false

	# Array any assignment type: {"any_assignment": "Explore"}
	if predicate.has("any_assignment"):
		var target: String = predicate["any_assignment"]
		for a in gs.bc_assignments:
			if a.get("type", "") == target:
				return true
		return false

	# Stat-vs-stat comparison: {"stat_lt_stat": ["security", "security_needed"]}
	if predicate.has("stat_lt_stat"):
		var arr: Array = predicate["stat_lt_stat"]
		var a = gs.get(arr[0])
		var b = gs.get(arr[1])
		return a != null and b != null and a < b

	# Event tracking
	if predicate.has("event_not_fired"):
		return predicate["event_not_fired"] not in gs.events_fired

	if predicate.has("event_fired"):
		return predicate["event_fired"] in gs.events_fired

	# Unknown predicate — warn and return false (don't silently pass)
	push_warning("ConditionChecker: unknown predicate keys: %s" % str(predicate.keys()))
	return false


static func _get_game_state() -> Node:
	# Fallback: walk the autoload tree
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("/root/GameState")
	return null
