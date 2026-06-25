# ============================================================================
# POPULARITY MANAGER — Популярность команды и игроков
# ============================================================================
# Расчёт популярности, влияние на мерч и спонсоров.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

const BASE_MERCH_INCOME := 50
const POPULARITY_MERCH_MULTIPLIER := 3.0  # На каждую единицу популярности
const BRAND_GROWTH_PER_SEASON := 2  # Бренд растёт каждый сезон


func _ready() -> void:
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.debug("PopularityManager ready", "POP")


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_team_popularity() -> int:
	return GameManager.player_team_data.get("popularity", 0)


func get_brand_value() -> int:
	return GameManager.player_team_data.get("brand", 0)


func get_merch_income() -> int:
	"""Доход от мерча за игровой день."""
	var pop := get_team_popularity()
	var brand := get_brand_value()
	var stream_bonus: int = 0
	if BaseManager.get_stream_income() > 0:
		stream_bonus = 20
	
	return BASE_MERCH_INCOME + int(float(pop) * POPULARITY_MERCH_MULTIPLIER) + brand + stream_bonus


func get_sponsor_quality_bonus() -> float:
	"""Бонус к качеству спонсорских предложений (0.0 - 1.0)."""
	var pop := get_team_popularity()
	return clampf(float(pop) / 100.0, 0.0, 1.0)


# ----------------------------------------------------------------------------
# POPULARITY CHANGES
# ----------------------------------------------------------------------------
func add_popularity(amount: int, source: String = "") -> void:
	var current: int = GameManager.player_team_data.get("popularity", 0)
	var new_val := clampi(current + amount, 0, 200)
	GameManager.player_team_data["popularity"] = new_val
	
	if amount > 0:
		EventBus.popularity_changed.emit(current, new_val)
		EventBus.debug("Popularity +" + str(amount) + " (" + source + ") -> " + str(new_val), "POP")


func process_season_end(season_data: Dictionary) -> void:
	"""Обновляет популярность по итогам сезона."""
	var position: int = season_data.get("position", 4)
	var wins: int = season_data.get("wins", 0)
	var league: String = season_data.get("old_league", "Open")
	
	# Бонус за место
	var place_bonus: int = 0
	match position:
		1: place_bonus = 15
		2: place_bonus = 10
		3: place_bonus = 5
	
	# Бонус за лигу
	var league_bonus: int = 0
	match league:
		"Champions": league_bonus = 10
		"Elite": league_bonus = 6
		"Pro": league_bonus = 3
		"Rising": league_bonus = 1
	
	# Бонус за победы
	var win_bonus: int = wins / 2
	
	add_popularity(place_bonus + league_bonus + win_bonus, "season_end")
	
	# Бренд растёт всегда
	var brand: int = GameManager.player_team_data.get("brand", 0)
	GameManager.player_team_data["brand"] = brand + BRAND_GROWTH_PER_SEASON


func process_major_result(major_results: Dictionary) -> void:
	"""Популярность от Мажора."""
	if not major_results.get("player_participated", false):
		add_popularity(2, "major_spectator")
		return
	
	var winner: Dictionary = major_results.get("winner", {})
	if winner.get("is_player", false):
		add_popularity(30, "major_winner")
	else:
		add_popularity(10, "major_participant")


func get_player_star_rating(player_data: Dictionary) -> int:
	"""Рейтинг звёздности игрока (0-5)."""
	var pop: int = player_data.get("popularity", 0)
	var combat: Dictionary = player_data.get("combat_skills", {})
	var avg: int = 0
	for v in combat.values():
		avg += v
	if combat.size() > 0:
		avg /= combat.size()
	
	var score: float = float(pop) * 0.3 + float(avg) * 0.7
	
	if score >= 80: return 5
	elif score >= 65: return 4
	elif score >= 50: return 3
	elif score >= 35: return 2
	elif score >= 20: return 1
	return 0


# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_match_ended(result: Dictionary) -> void:
	var winner: String = result.get("winner", "")
	if winner == "player":
		add_popularity(2, "match_win")
		# Бонус за клатчи и яркую игру
		if randf() < 0.2:
			_boost_random_player_pop(3)
	else:
		# Небольшая потеря при поражении
		if get_team_popularity() > 10:
			var current: int = GameManager.player_team_data.get("popularity", 0)
			GameManager.player_team_data["popularity"] = maxi(0, current - 1)


func _boost_random_player_pop(amount: int) -> void:
	var roster = RosterManager.get_roster()
	if roster.is_empty():
		return
	var player: Dictionary = roster[randi() % roster.size()]
	player["popularity"] = player.get("popularity", 0) + amount
	EventBus.viral_moment.emit(player.get("id", ""), amount)


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {}  # Популярность хранится в player_team_data

func from_dict(_data: Dictionary) -> void:
	pass
