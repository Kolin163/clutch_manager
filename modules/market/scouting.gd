# ============================================================================
# SCOUTING — Скаутинг (Исправленный: Стабильные значения)
# ============================================================================
extends Node

const DEFAULT_HIDDEN_COMBAT := 2
const DEFAULT_HIDDEN_MENTAL := 3
const DEFAULT_SKILL_VARIANCE := 15
const ANALYST_SKILL_VARIANCE := 5

var scouted_data: Dictionary = {} 

func get_visible_skills(player_data: Dictionary, has_analyst: bool = false) -> Dictionary:
	var player_id: String = player_data.get("id", "")
	var scout_info: Dictionary = scouted_data.get(player_id, {})
	var revealed: Array = scout_info.get("revealed_skills", [])
	
	var variance: int = ANALYST_SKILL_VARIANCE if has_analyst else DEFAULT_SKILL_VARIANCE
	
	var result := {"combat": {}, "mental": {}}
	
	var combat: Dictionary = player_data.get("combat_skills", {})
	for skill in combat.keys():
		var actual = combat[skill]
		var displayed = _get_stable_variance(player_id, skill, actual, variance)
		result["combat"][skill] = {"value": displayed, "accurate": has_analyst}
	
	var potential: int = player_data.get("potential", 50)
	result["potential"] = {"value": _estimate_potential(player_id, potential, has_analyst)}
	
	return result

func get_perceived_overall(player_data: Dictionary, has_analyst: bool) -> int:
	"""Возвращает стабильный примерный оверролл игрока."""
	var combat = player_data.get("combat_skills", {})
	var avg = 0
	for v in combat.values(): avg += v
	avg = avg / maxi(combat.size(), 1)
	
	var variance = ANALYST_SKILL_VARIANCE if has_analyst else DEFAULT_SKILL_VARIANCE
	return _get_stable_variance(player_data["id"], "overall", avg, variance)

# Внутренняя функция для получения всегда одного и того же шума для игрока
func _get_stable_variance(player_id: String, skill_key: String, actual: int, variance: int) -> int:
	if variance <= 0: return actual
	
	# Используем хеш от ID и названия скилла как зерно (seed) для рандома
	var seed_val = (player_id + skill_key).hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var offset = rng.randi_range(-variance, variance)
	return clampi(actual + offset, 1, 100)

func _estimate_potential(player_id: String, actual: int, has_analyst: bool) -> String:
	var perceived = _get_stable_variance(player_id, "potential", actual, 20 if has_analyst else 35)
	
	if not has_analyst: return "???"
	if perceived >= 85: return "Звездный"
	if perceived >= 70: return "Высокий"
	if perceived >= 50: return "Средний"
	return "Низкий"

func clear_scouting_data(): scouted_data.clear()
func to_dict(): return {"scouted": scouted_data}
func from_dict(data): scouted_data = data.get("scouted", {})
