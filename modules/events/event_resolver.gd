# ============================================================================
# EVENT RESOLVER — Применение решений ивентов
# ============================================================================
# Обрабатывает выбор игрока и применяет эффекты.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node


func _ready() -> void:
	EventBus.debug("EventResolver ready", "EVENT")


func resolve_managed_event(event: Dictionary, choice_id: String) -> Dictionary:
	"""Обрабатывает выбор в управляемом ивенте."""
	var choices: Array = event.get("choices", [])
	var chosen: Dictionary = {}
	
	for c in choices:
		if c.get("id", "") == choice_id:
			chosen = c
			break
	
	if chosen.is_empty():
		return {"success": false, "error": "Choice not found"}
	
	var effect: Dictionary = chosen.get("effect", {})
	var result := _apply_effect(effect)
	
	EventBus.random_event_resolved.emit(event.get("id", ""), choice_id, result)
	EventBus.debug("Event resolved: " + event.get("id", "?") + " -> " + choice_id, "EVENT")
	return result


func resolve_unmanaged_event(event: Dictionary) -> Dictionary:
	"""Автоматически применяет неуправляемый ивент."""
	var effect: Dictionary = event.get("effect", {})
	var result := _apply_effect(effect)
	
	EventBus.random_event_resolved.emit(event.get("id", ""), "auto", result)
	EventBus.debug("Unmanaged event applied: " + event.get("id", "?"), "EVENT")
	return result


func _apply_effect(effect: Dictionary) -> Dictionary:
	var result := {"applied": true, "details": []}
	var action: String = effect.get("action", "")
	
	# Стоимость
	var cost: int = effect.get("cost", 0)
	if cost > 0:
		if EconomyManager.can_afford(cost):
			EconomyManager.spend_money(cost, "event_" + action)
			result["details"].append("Потрачено $" + str(cost))
		else:
			result["applied"] = false
			result["details"].append("Не хватает денег!")
			return result
	
	# Деньги
	var money: int = effect.get("money", 0)
	if money > 0:
		EconomyManager.add_money(money, "event_" + action)
		result["details"].append("Получено $" + str(money))
	
	# Популярность
	var pop_boost: int = effect.get("popularity_boost", 0)
	if pop_boost > 0:
		var current: int = GameManager.player_team_data.get("popularity", 0)
		GameManager.player_team_data["popularity"] = current + pop_boost
		result["details"].append("Популярность +" + str(pop_boost))
	
	# Моральный дух
	var morale_boost: int = effect.get("morale_boost", 0)
	var morale_penalty: int = effect.get("morale_penalty", 0)
	if morale_boost > 0 or morale_penalty > 0:
		_apply_to_roster_mental("morale", morale_boost - morale_penalty)
	
	# Мотивация
	var mot_boost: int = effect.get("motivation_boost", 0)
	var mot_penalty: int = effect.get("motivation_penalty", 0)
	if mot_boost > 0 or mot_penalty > 0:
		_apply_to_roster_mental("motivation", mot_boost - mot_penalty)
	
	# Коммуникация
	var comm_boost: int = effect.get("comm_boost", 0)
	var comm_penalty: int = effect.get("comm_penalty", 0)
	if comm_boost > 0 or comm_penalty > 0:
		_apply_to_roster_mental("communication", comm_boost - comm_penalty)
	
	# Дисциплина
	var disc_boost: int = effect.get("discipline_boost", 0)
	if disc_boost > 0:
		_apply_to_roster_mental("discipline", disc_boost)
	
	# Скиллы
	var skill_boost: int = effect.get("skill_boost", 0)
	if skill_boost > 0:
		_apply_to_roster_combat_all(skill_boost)
		result["details"].append("Скиллы +" + str(skill_boost))
	
	var aim_penalty: int = effect.get("aim_penalty", 0)
	if aim_penalty > 0:
		_apply_to_random_player_combat("aim", -aim_penalty)
		result["details"].append("Aim -" + str(aim_penalty) + " у случайного игрока")
	
	# Ментальный штраф
	var mental_penalty: int = effect.get("mental_penalty", 0)
	if mental_penalty > 0:
		_apply_to_roster_mental("tilt_resistance", -mental_penalty)
	
	# Усталость
	var fatigue: int = effect.get("fatigue", 0)
	if fatigue > 0:
		_apply_fatigue(fatigue)
	
	var fatigue_recovery: int = effect.get("fatigue_recovery", 0)
	if fatigue_recovery > 0:
		_apply_fatigue(-fatigue_recovery)
	
	# Популярность игрока
	var player_pop: int = effect.get("player_popularity", 0)
	if player_pop > 0:
		_boost_random_player_popularity(player_pop)
	
	# Тильт-риск
	if effect.get("risk_tilt", false) or effect.get("tilt_risk", false):
		if randf() < 0.3:
			AgingManager._increase_tilt_all()
			result["details"].append("Тильт!")
	
	# Специальные действия
	match action:
		"add_talent_to_pool":
			var talent := PlayerGenerator.generate_young_talent()
			AgentPool.add_to_pool(talent)
			result["details"].append("Молодой талант добавлен на рынок")
		"scout_talent":
			var talent := PlayerGenerator.generate_player({"potential": randi_range(65, 90), "age": randi_range(18, 23)})
			AgentPool.add_to_pool(talent)
			result["details"].append("Сильный агент добавлен на рынок")
		"salary_raise":
			var raise_pct: int = effect.get("raise_percent", 20)
			_raise_random_salary(raise_pct)
			result["details"].append("Зарплата игрока повышена на " + str(raise_pct) + "%")
	
	return result


func _apply_to_roster_mental(skill_name: String, amount: int) -> void:
	for player in RosterManager.get_roster():
		var mental: Dictionary = player.get("mental_skills", {})
		if mental.has(skill_name):
			mental[skill_name] = clampi(mental[skill_name] + amount, 1, 100)
		player["mental_skills"] = mental


func _apply_to_roster_combat_all(amount: int) -> void:
	for player in RosterManager.get_roster():
		var combat: Dictionary = player.get("combat_skills", {})
		for skill in combat.keys():
			combat[skill] = clampi(combat[skill] + amount, 1, 100)
		player["combat_skills"] = combat


func _apply_to_random_player_combat(skill_name: String, amount: int) -> void:
	var roster = RosterManager.get_roster()
	if roster.is_empty():
		return
	var player: Dictionary = roster[randi() % roster.size()]
	var combat: Dictionary = player.get("combat_skills", {})
	if combat.has(skill_name):
		combat[skill_name] = clampi(combat[skill_name] + amount, 1, 100)
	player["combat_skills"] = combat


func _apply_fatigue(amount: int) -> void:
	for player in RosterManager.get_roster():
		var current: int = player.get("fatigue", 0)
		player["fatigue"] = clampi(current + amount, 0, 100)


func _boost_random_player_popularity(amount: int) -> void:
	var roster = RosterManager.get_roster()
	if roster.is_empty():
		return
	var player: Dictionary = roster[randi() % roster.size()]
	player["popularity"] = player.get("popularity", 0) + amount


func _raise_random_salary(percent: int) -> void:
	var roster = RosterManager.get_roster()
	if roster.is_empty():
		return
	var player: Dictionary = roster[randi() % roster.size()]
	var contract: Dictionary = player.get("contract", {})
	var salary: int = contract.get("salary", 500)
	contract["salary"] = int(float(salary) * (1.0 + float(percent) / 100.0))
	player["contract"] = contract
