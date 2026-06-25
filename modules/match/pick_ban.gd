# ============================================================================
# PICK BAN — Система пиков и банов карт
# ============================================================================
# Bo3: ban-ban-ban-ban-pick-pick-decider
# Bo5: ban-ban-pick-pick-pick-pick-decider
# ============================================================================

class_name PickBan
extends RefCounted

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
enum Action { BAN, PICK, DECIDER }

const BO3_SEQUENCE := [
	{"action": "ban", "team": "a"},
	{"action": "ban", "team": "b"},
	{"action": "ban", "team": "a"},
	{"action": "ban", "team": "b"},
	{"action": "pick", "team": "a"},
	{"action": "pick", "team": "b"},
	{"action": "decider", "team": "none"}
]

const BO5_SEQUENCE := [
	{"action": "ban", "team": "a"},
	{"action": "ban", "team": "b"},
	{"action": "pick", "team": "a"},
	{"action": "pick", "team": "b"},
	{"action": "pick", "team": "a"},
	{"action": "pick", "team": "b"},
	{"action": "decider", "team": "none"}
]


# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var available_maps: Array[Dictionary] = []
var banned_maps: Array[Dictionary] = []
var picked_maps: Array[Dictionary] = []
var decider_map: Dictionary = {}
var current_step: int = 0
var best_of: int = 3
var sequence: Array = []
var is_complete: bool = false
var team_a_name: String = "Team A"
var team_b_name: String = "Team B"
var history: Array[Dictionary] = []


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func start(bo: int, maps: Array[Dictionary], a_name: String, b_name: String) -> void:
	best_of = bo
	team_a_name = a_name
	team_b_name = b_name
	sequence = BO5_SEQUENCE.duplicate(true) if bo == 5 else BO3_SEQUENCE.duplicate(true)
	
	available_maps.clear()
	for m in maps:
		available_maps.append(m.duplicate(true))
	
	banned_maps.clear()
	picked_maps.clear()
	decider_map = {}
	current_step = 0
	is_complete = false
	history.clear()


func get_current_action() -> Dictionary:
	if current_step >= sequence.size():
		return {}
	return sequence[current_step]


func get_current_team_name() -> String:
	var action := get_current_action()
	var team: String = action.get("team", "none")
	if team == "a":
		return team_a_name
	elif team == "b":
		return team_b_name
	return ""


func get_current_action_text() -> String:
	var action := get_current_action()
	var act: String = action.get("action", "")
	var team_name := get_current_team_name()
	
	match act:
		"ban":
			return team_name + " банит карту"
		"pick":
			return team_name + " выбирает карту"
		"decider":
			return "Решающая карта выбирается случайно"
		_:
			return ""


func select_map(map_id: String) -> Dictionary:
	"""Игрок или ИИ выбирает карту. Возвращает результат шага."""
	if is_complete or current_step >= sequence.size():
		return {}
	
	var action := get_current_action()
	var act: String = action.get("action", "")
	
	var selected_map := _find_and_remove_map(map_id)
	if selected_map.is_empty():
		return {}
	
	var result := {
		"step": current_step,
		"action": act,
		"team": action.get("team", "none"),
		"map": selected_map
	}
	
	match act:
		"ban":
			banned_maps.append(selected_map)
		"pick":
			picked_maps.append(selected_map)
		"decider":
			decider_map = selected_map
			picked_maps.append(selected_map)
	
	history.append(result)
	current_step += 1
	
	# Проверяем decider
	if current_step < sequence.size():
		var next = sequence[current_step]
		if next.get("action", "") == "decider":
			_auto_decider()
	
	# Проверяем завершение
	if current_step >= sequence.size():
		is_complete = true
	
	return result


func auto_select() -> Dictionary:
	"""ИИ автоматически выбирает карту."""
	if available_maps.is_empty():
		return {}
	
	var action := get_current_action()
	var act: String = action.get("action", "")
	
	# Простая логика ИИ: банит сильную карту, пикает удобную
	var map_id: String
	if act == "ban":
		# Банит первую доступную (упрощённо)
		map_id = available_maps[randi() % available_maps.size()].get("id", "")
	else:
		map_id = available_maps[randi() % available_maps.size()].get("id", "")
	
	return select_map(map_id)


func get_final_maps() -> Array[Dictionary]:
	"""Возвращает финальный набор карт для матча."""
	return picked_maps


func get_available_maps() -> Array[Dictionary]:
	return available_maps


func get_history() -> Array[Dictionary]:
	return history


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
func _find_and_remove_map(map_id: String) -> Dictionary:
	for i in range(available_maps.size()):
		if available_maps[i].get("id", "") == map_id:
			var found := available_maps[i]
			available_maps.remove_at(i)
			return found
	return {}


func _auto_decider() -> void:
	"""Автоматически выбирает решающую карту."""
	if available_maps.is_empty():
		return
	
	var random_map := available_maps[randi() % available_maps.size()]
	select_map(random_map.get("id", ""))


# ----------------------------------------------------------------------------
# FULL AUTO (для ИИ-матчей)
# ----------------------------------------------------------------------------
static func auto_pick_ban(bo: int, maps: Array[Dictionary], a_name: String, b_name: String) -> Array[Dictionary]:
	"""Полностью автоматический пик/бан. Возвращает набор карт."""
	var pb := PickBan.new()
	pb.start(bo, maps, a_name, b_name)
	
	while not pb.is_complete:
		pb.auto_select()
	
	return pb.get_final_maps()
