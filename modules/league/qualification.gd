# ============================================================================
# QUALIFICATION — Открытая квалификация на Мажор
# ============================================================================
# Bo1 турнир среди команд не прошедших напрямую.
# Выявляет 4 участника Мажора.
# ============================================================================

class_name Qualification
extends RefCounted

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const QUAL_SLOTS := 4  # Сколько мест из квалификации
const QUAL_TEAMS := 16  # Сколько команд участвует в квале


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
static func run_qualification(all_teams: Array, direct_invite_ids: Array) -> Array[Dictionary]:
	"""Проводит квалификацию. Возвращает 4 команды-победителя."""
	
	# Собираем команды, которые НЕ в прямых инвайтах
	var qual_candidates: Array[Dictionary] = []
	for team in all_teams:
		var team_id: String = team.get("id", "")
		if team_id in direct_invite_ids:
			continue
		qual_candidates.append(team)
	
	# Перемешиваем и берём до QUAL_TEAMS
	qual_candidates.shuffle()
	if qual_candidates.size() > QUAL_TEAMS:
		qual_candidates.resize(QUAL_TEAMS)
	
	if qual_candidates.size() < QUAL_SLOTS:
		return qual_candidates
	
	# Bo1 Swiss-стиль: 3 победы = прошёл, 3 поражения = вылетел
	var qualified: Array[Dictionary] = []
	var eliminated: Array[Dictionary] = []
	var win_counts: Dictionary = {}  # team_id -> wins
	var loss_counts: Dictionary = {}  # team_id -> losses
	
	for team in qual_candidates:
		var tid: String = team.get("id", "")
		win_counts[tid] = 0
		loss_counts[tid] = 0
	
	var active := qual_candidates.duplicate()
	var round_num := 0
	
	while qualified.size() < QUAL_SLOTS and active.size() >= 2:
		round_num += 1
		active.shuffle()
		
		var next_active: Array[Dictionary] = []
		var i := 0
		
		while i + 1 < active.size():
			var team_a: Dictionary = active[i]
			var team_b: Dictionary = active[i + 1]
			var winner := _simulate_bo1(team_a, team_b)
			var loser := team_b if winner.get("id", "") == team_a.get("id", "") else team_a
			
			var w_id: String = winner.get("id", "")
			var l_id: String = loser.get("id", "")
			
			win_counts[w_id] = win_counts.get(w_id, 0) + 1
			loss_counts[l_id] = loss_counts.get(l_id, 0) + 1
			
			if win_counts[w_id] >= 3:
				qualified.append(winner)
			else:
				next_active.append(winner)
			
			if loss_counts[l_id] >= 3:
				eliminated.append(loser)
			else:
				next_active.append(loser)
			
			i += 2
		
		# Нечётная команда получает bye
		if i < active.size():
			next_active.append(active[i])
		
		active = next_active
		
		if round_num > 10:
			break
	
	# Если не хватило квалифицированных, добавляем оставшихся
	while qualified.size() < QUAL_SLOTS and not active.is_empty():
		qualified.append(active.pop_front())
	
	EventBus.debug("Qualification done: " + str(qualified.size()) + " teams qualified", "MAJOR")
	return qualified


static func _simulate_bo1(team_a: Dictionary, team_b: Dictionary) -> Dictionary:
	"""Симулирует Bo1 матч, возвращает победителя."""
	var str_a: float = team_a.get("strength", 50.0)
	var str_b: float = team_b.get("strength", 50.0)
	
	var total := str_a + str_b
	var chance_a := clampf(str_a / total + randf_range(-0.15, 0.15), 0.25, 0.75)
	
	if randf() < chance_a:
		return team_a
	return team_b
