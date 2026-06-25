# ============================================================================
# ROSTER MANAGER — Управление составом команды
# ============================================================================
# Хранит состав из 5 игроков. Методы добавления/удаления.
# Синглтон — добавить в Autoload.
# ============================================================================
extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const MAX_ROSTER_SIZE := 5
const ROLES := ["entry", "awper", "support", "lurker", "igl"]

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var roster: Array[Dictionary] = []  # Массив player_data словарей

# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.debug("RosterManager ready", "TEAM")

# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_roster() -> Array[Dictionary]:
	return roster

func get_roster_size() -> int:
	return roster.size()

func is_roster_full() -> bool:
	return roster.size() >= MAX_ROSTER_SIZE

func is_roster_empty() -> bool:
	return roster.is_empty()

func is_complete() -> bool:
	"""Проверяет, готов ли состав к игре (ровно 5 человек)."""
	return roster.size() == MAX_ROSTER_SIZE

func get_player_by_id(player_id: String) -> Dictionary:
	for player in roster:
		if player.get("id", "") == player_id:
			return player
	return {}

func get_player_by_role(role: String) -> Dictionary:
	for player in roster:
		if player.get("role", "") == role:
			return player
	return {}

func get_player_at_index(index: int) -> Dictionary:
	if index >= 0 and index < roster.size():
		return roster[index]
	return {}

# ----------------------------------------------------------------------------
# ROSTER MODIFICATION
# ----------------------------------------------------------------------------
func add_player(player_data: Dictionary) -> bool:
	if is_roster_full():
		EventBus.debug("Roster full, cannot add player", "WARN")
		return false
	
	if player_data.is_empty():
		EventBus.debug("Cannot add empty player data", "ERROR")
		return false
	
	# Проверяем дубликат
	var player_id: String = player_data.get("id", "")
	if not player_id.is_empty() and has_player(player_id):
		EventBus.debug("Player already in roster: " + player_id, "WARN")
		return false
	
	roster.append(player_data)
	EventBus.roster_updated.emit(roster)
	EventBus.player_hired.emit(player_data)
	EventBus.debug("Player added: " + player_data.get("nickname", "?"), "TEAM")
	return true

func remove_player(player_id: String) -> bool:
	for i in range(roster.size()):
		if roster[i].get("id", "") == player_id:
			var removed := roster[i]
			roster.remove_at(i)
			EventBus.roster_updated.emit(roster)
			EventBus.player_fired.emit(player_id)
			EventBus.debug("Player removed: " + removed.get("nickname", "?"), "TEAM")
			return true
	
	EventBus.debug("Player not found: " + player_id, "WARN")
	return false

func remove_player_at_index(index: int) -> bool:
	if index < 0 or index >= roster.size():
		return false
	
	var player_id: String = roster[index].get("id", "")
	return remove_player(player_id)

func has_player(player_id: String) -> bool:
	for player in roster:
		if player.get("id", "") == player_id:
			return true
	return false

func clear_roster() -> void:
	roster.clear()
	EventBus.roster_updated.emit(roster)
	EventBus.debug("Roster cleared", "TEAM")

func set_roster(new_roster: Array) -> void:
	roster.clear()
	for player_data in new_roster:
		if player_data is Dictionary:
			roster.append(player_data)
	EventBus.roster_updated.emit(roster)
	EventBus.debug("Roster set: " + str(roster.size()) + " players", "TEAM")

# ----------------------------------------------------------------------------
# ROLE MANAGEMENT
# ----------------------------------------------------------------------------
func change_player_role(player_id: String, new_role: String) -> bool:
	if not new_role in ROLES:
		EventBus.debug("Invalid role: " + new_role, "ERROR")
		return false
	
	for player in roster:
		if player.get("id", "") == player_id:
			player["role"] = new_role
			EventBus.player_stats_changed.emit(player_id, {"role": new_role})
			EventBus.debug("Role changed: " + player.get("nickname", "?") + " -> " + new_role, "TEAM")
			return true
	
	return false

func get_missing_roles() -> Array[String]:
	var filled_roles: Array[String] = []
	for player in roster:
		var role: String = player.get("role", "")
		if not role in filled_roles:
			filled_roles.append(role)
	
	var missing: Array[String] = []
	for role in ROLES:
		if not role in filled_roles:
			missing.append(role)
	
	return missing

func has_igl() -> bool:
	return not get_player_by_role("igl").is_empty()

func has_awper() -> bool:
	return not get_player_by_role("awper").is_empty()

# ----------------------------------------------------------------------------
# STATS
# ----------------------------------------------------------------------------
func get_average_skill(skill_name: String, skill_type: String = "combat") -> float:
	if roster.is_empty():
		return 0.0
	
	var total: float = 0.0
	var count: int = 0
	
	for player in roster:
		var skills: Dictionary
		if skill_type == "combat":
			skills = player.get("combat_skills", {})
		else:
			skills = player.get("mental_skills", {})
		
		if skills.has(skill_name):
			total += float(skills[skill_name])
			count += 1
	
	if count == 0:
		return 0.0
	
	return total / float(count)

func get_team_overall() -> int:
	if roster.is_empty():
		return 0
	
	var total: float = 0.0
	
	for player in roster:
		var combat: Dictionary = player.get("combat_skills", {})
		var player_total: float = 0.0
		for value in combat.values():
			player_total += float(value)
		if combat.size() > 0:
			total += player_total / float(combat.size())
	
	return int(total / float(roster.size()))

func get_total_salaries() -> int:
	var total: int = 0
	for player in roster:
		var contract: Dictionary = player.get("contract", {})
		total += contract.get("salary", 0)
	return total

# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"roster": roster.duplicate(true)
	}

func from_dict(data: Dictionary) -> void:
	var roster_data: Array = data.get("roster", [])
	set_roster(roster_data)
