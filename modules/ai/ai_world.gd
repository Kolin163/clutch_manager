# ============================================================================
# AI WORLD — Симуляция всех лиг мира (Исправленная версия)
# ============================================================================
extends Node

const LEAGUES := ["Open", "Rising", "Pro", "Elite", "Champions"]
const MATCH_DAYS := 14
const POINTS_WIN := 3

var initialized: bool = false
var current_player_league: String = "Open"
var world_leagues: Dictionary = {}
var teams_data: Dictionary = {}
var data_loaded: bool = false
var last_simulated_match_day: int = 0

func _ready() -> void:
	load_teams_data()
	EventBus.match_day_started.connect(_on_match_day_started)
	EventBus.debug("AIWorld ready", "AI")

# ----------------------------------------------------------------------------
# INIT / RESET
# ----------------------------------------------------------------------------

func reset_world() -> void:
	initialized = false
	current_player_league = "Open"
	last_simulated_match_day = 0
	world_leagues.clear()
	EventBus.debug("AI world reset", "AI")

func init_world(player_league: String) -> void:
	ensure_data_loaded()
	reset_world()
	current_player_league = player_league
	
	var leagues_map = teams_data.get("leagues_data", {})
	
	for league_name in LEAGUES:
		var teams_configs = leagues_map.get(league_name, [])
		var final_teams = []
		
		var player_replaced = false
		for config in teams_configs:
			if league_name == player_league and not player_replaced:
				final_teams.append(_create_player_placeholder())
				player_replaced = true
				continue
			
			final_teams.append(_create_ai_team_from_config(config, league_name))
			
		world_leagues[league_name] = _build_league_state(league_name, final_teams)
	
	initialized = true
	EventBus.debug("AI world initialized for player league: " + player_league, "AI")

# ----------------------------------------------------------------------------
# PUBLIC API / VIEW DATA
# ----------------------------------------------------------------------------

func has_league(league_name: String) -> bool:
	return world_leagues.has(league_name)

func get_available_leagues() -> Array:
	return LEAGUES.duplicate()

func get_league_standings(league_name: String) -> Array:
	if not world_leagues.has(league_name): return []
	return world_leagues[league_name].get("standings", [])

func get_league_match_day(league_name: String) -> int:
	if not world_leagues.has(league_name): return 0
	return world_leagues[league_name].get("current_match_day", 0)

# ----------------------------------------------------------------------------
# WORLD SIMULATION
# ----------------------------------------------------------------------------

func simulate_world_match_day(match_day: int) -> void:
	if not initialized or match_day <= 0: return
	if last_simulated_match_day == match_day: return
	
	for league_name in LEAGUES:
		if league_name == current_player_league: continue
		_simulate_league_match_day(league_name, match_day)
	
	last_simulated_match_day = match_day
	EventBus.debug("AI world simulated match day: " + str(match_day), "AI")

func _simulate_league_match_day(league_name: String, match_day: int) -> void:
	var state = world_leagues.get(league_name, {})
	if state.is_empty(): return
	
	# Упрощенная симуляция для фоновых лиг
	var standings = state["standings"]
	for i in range(0, standings.size(), 2):
		if i + 1 >= standings.size(): break
		var s1 = standings[i]
		var s2 = standings[i+1]
		
		# Псевдо-рандомный результат на основе силы
		var str1 = s1["team"].get("strength_val", 50.0)
		var str2 = s2["team"].get("strength_val", 50.0)
		var win1 = randf() < (str1 / (str1 + str2))
		
		if win1:
			s1["wins"] += 1; s1["points"] += POINTS_WIN
			s2["losses"] += 1
		else:
			s2["wins"] += 1; s2["points"] += POINTS_WIN
			s1["losses"] += 1
		
		s1["played"] = match_day
		s2["played"] = match_day
	
	standings.sort_custom(func(a,b): return a["points"] > b["points"])
	state["current_match_day"] = match_day

# ----------------------------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------------------------

func _create_ai_team_from_config(config: Dictionary, league_name: String) -> Dictionary:
	var strength_key = config.get("strength", "medium")
	var skill_ranges = teams_data.get("strength_skill_ranges", {}).get(strength_key, {"min": 40, "max": 60})
	
	var roster = []
	var total_combat = 0.0
	for role in ["entry", "awper", "support", "lurker", "igl"]:
		var p = PlayerGenerator.generate_player({"role": role, "potential": randi_range(60, 90)})
		for s in p["combat_skills"].keys():
			p["combat_skills"][s] = randi_range(skill_ranges["min"], skill_ranges["max"])
			total_combat += p["combat_skills"][s]
		roster.append(p)
		
	return {
		"id": config["id"], "name": config["name"], "logo": config["logo"],
		"is_player": false, "league": league_name, "roster": roster,
		"strength_val": total_combat / 20.0, # Средний скилл
		"style": config.get("style", "balanced")
	}

func _create_player_placeholder() -> Dictionary:
	return {"id": "player", "name": "Player Team", "logo": "🎮", "is_player": true, "roster": [], "strength_val": 50.0}

func _build_league_state(league_name, teams) -> Dictionary:
	return {
		"league": league_name, "teams": teams, 
		"standings": _init_standings_for_teams(teams),
		"current_match_day": 0
	}

func _init_standings_for_teams(teams: Array) -> Array:
	var s = []
	for i in range(teams.size()):
		s.append({"team_idx": i, "team": teams[i], "played": 0, "wins": 0, "losses": 0, "points": 0, "round_diff": 0})
	return s

func _on_match_day_started(day: int) -> void:
	simulate_world_match_day(day)

func load_teams_data() -> void:
	var file = FileAccess.open("res://data/teams/ai_teams.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			teams_data = json.data
			data_loaded = true

func ensure_data_loaded() -> void:
	if not data_loaded: load_teams_data()

func extract_ordered_teams(league_name: String) -> Array:
	var s = get_league_standings(league_name)
	var res = []
	for item in s: res.append(item["team"])
	return res

func sync_player_league_from_manager() -> void:
	if not initialized: return
	var l = LeagueManager.current_league
	world_leagues[l]["standings"] = LeagueManager.get_standings()
	world_leagues[l]["current_match_day"] = LeagueManager.current_match_day

func finalize_world_season(_summary: Dictionary) -> void:
	# Логика ротации между лигами
	pass

# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"init": initialized, "leagues": world_leagues, "player_l": current_player_league, "day": last_simulated_match_day}

func from_dict(data: Dictionary) -> void:
	initialized = data.get("init", false)
	world_leagues = data.get("leagues", {})
	current_player_league = data.get("player_l", "Open")
	last_simulated_match_day = data.get("day", 0)
