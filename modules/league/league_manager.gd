# ============================================================================
# LEAGUE MANAGER — Управление лигой и сезоном (Исправленная версия)
# ============================================================================
extends Node

const TEAMS_IN_LEAGUE := 8
const MATCHES_PER_SEASON := 14
const POINTS_WIN := 3
const LEAGUES := ["Open", "Rising", "Pro", "Elite", "Champions"]

var current_league: String = "Open"
var league_teams: Array = []
var schedule: Array = []
var standings: Array = []
var current_match_day: int = 0
var season_finalized: bool = false
var match_results: Array = []
var season_summary: Dictionary = {}

func _ready() -> void:
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.debug("LeagueManager ready", "LEAGUE")

func init_league(league_name: String) -> void:
	current_league = league_name
	current_match_day = 0
	match_results.clear()
	season_finalized = false
	season_summary = {}
	
	if not AIWorld.initialized:
		AIWorld.init_world(league_name)
	
	_generate_league_teams_from_world(league_name)
	_generate_schedule()
	_init_standings()
	
	EventBus.debug("League initialized: " + league_name, "LEAGUE")

func _generate_league_teams_from_world(league_name: String) -> void:
	league_teams.clear()
	league_teams.append(_create_player_team_entry())
	
	var world_data = AIWorld.world_leagues.get(league_name, {})
	var world_teams = world_data.get("teams", [])
	
	for team in world_teams:
		if team.get("id") == "player": continue
		if league_teams.size() >= TEAMS_IN_LEAGUE: break
		league_teams.append(team)

func _create_player_team_entry() -> Dictionary:
	var td = GameManager.player_team_data
	return {
		"id": "player", "name": td.get("name", "My Team"), "logo": td.get("logo", "res://icon.svg"),
		"is_player": true, "roster": RosterManager.get_roster(),
		"strength_val": RosterManager.get_team_overall()
	}

func _generate_schedule() -> void:
	schedule.clear()
	var team_indices = range(TEAMS_IN_LEAGUE)
	
	for round_num in range(TEAMS_IN_LEAGUE - 1):
		_add_round(team_indices, round_num + 1, false)
		var last = team_indices.pop_back()
		team_indices.insert(1, last)
	
	team_indices = range(TEAMS_IN_LEAGUE)
	for round_num in range(TEAMS_IN_LEAGUE - 1):
		_add_round(team_indices, round_num + TEAMS_IN_LEAGUE, true)
		var last = team_indices.pop_back()
		team_indices.insert(1, last)

func _add_round(indices, day, swap):
	for i in range(TEAMS_IN_LEAGUE / 2):
		var h = indices[i]
		var a = indices[TEAMS_IN_LEAGUE - 1 - i]
		if swap: var t = h; h = a; a = t
		schedule.append({
			"match_day": day, "home_team_idx": h, "away_team_idx": a,
			"home_team": league_teams[h], "away_team": league_teams[a],
			"played": false, "result": {}
		})

func _init_standings() -> void:
	standings.clear()
	for i in range(league_teams.size()):
		standings.append({"team_idx": i, "team": league_teams[i], "played": 0, "wins": 0, "losses": 0, "points": 0, "round_diff": 0})

func get_next_player_match():
	for m in schedule:
		if not m["played"] and (m["home_team"]["id"] == "player" or m["away_team"]["id"] == "player"):
			return m
	return {}

func simulate_current_match_day(include_player: bool = false) -> Array:
	var day_results = []
	for m in schedule:
		if not m["played"] and m["match_day"] == current_match_day:
			var is_p = m["home_team"]["id"] == "player" or m["away_team"]["id"] == "player"
			if is_p and not include_player: continue
			_simulate_match(m)
			day_results.append(m["result"])
	return day_results

func simulate_ai_matches():
	for m in schedule:
		if not m["played"] and m["home_team"]["id"] != "player" and m["away_team"]["id"] != "player" and m["match_day"] == current_match_day:
			_simulate_match(m)

func _simulate_match(m):
	var s1 = m["home_team"].get("strength_val", 50.0) + randf_range(-5, 5)
	var s2 = m["away_team"].get("strength_val", 50.0) + randf_range(-5, 5)
	var win1 = randf() < (s1 / (s1 + s2))
	var res = {"home_score": 13 if win1 else randi_range(0, 11), "away_score": 13 if not win1 else randi_range(0, 11)}
	m["played"] = true; m["result"] = res
	match_results.append(res)
	_update_standings(m["home_team_idx"], m["away_team_idx"], res["home_score"], res["away_score"])

func _update_standings(h_idx, a_idx, h_s, a_s):
	var h = _get_st(h_idx); var a = _get_st(a_idx)
	h["played"] += 1; a["played"] += 1
	if h_s > a_s: 
		h["wins"] += 1; h["points"] += 3
		a["losses"] += 1
	else: 
		a["wins"] += 1; a["points"] += 3
		h["losses"] += 1
	h["round_diff"] += (h_s - a_s); a["round_diff"] += (a_s - h_s)
	standings.sort_custom(func(a,b): return a["points"] > b["points"] if a["points"] != b["points"] else a["round_diff"] > b["round_diff"])

func _get_st(idx):
	for s in standings: if s["team_idx"] == idx: return s
	return {}

func finalize_season() -> Dictionary:
	var pos = get_player_position()
	var st = get_player_standing()
	var old = current_league
	var next = old
	var l_idx = LEAGUES.find(old)
	
	var movement = "stayed"
	if pos == 1 and l_idx < LEAGUES.size() - 1:
		next = LEAGUES[l_idx + 1]; movement = "promoted"
	elif pos == 8 and l_idx > 0:
		next = LEAGUES[l_idx - 1]; movement = "relegated"
		
	GameManager.player_team_data["league"] = next
	var prize = EconomyManager.receive_prize_money(pos, old)
	
	season_summary = {
		"old_league": old, "new_league": next, "position": pos,
		"wins": st["wins"], "losses": st["losses"], "prize_money": prize,
		"movement": movement
	}
	season_finalized = true
	AIWorld.finalize_world_season(season_summary)
	return season_summary

func get_player_position():
	for i in range(standings.size()): if standings[i]["team"]["id"] == "player": return i + 1
	return 0

func get_player_standing():
	for s in standings: if s["team"]["id"] == "player": return s
	return {}

func advance_match_day():
	current_match_day += 1
	EventBus.match_day_started.emit(current_match_day)

func is_season_complete(): return current_match_day >= MATCHES_PER_SEASON
func get_standings(): return standings

func _on_match_ended(res):
	var m = get_next_player_match()
	if m.is_empty(): return
	m["played"] = true
	var h_s = res["player_score"] if m["home_team"]["id"] == "player" else res["enemy_score"]
	var a_s = res["enemy_score"] if m["home_team"]["id"] == "player" else res["player_score"]
	var result_data = {"home_team": m["home_team"], "away_team": m["away_team"], "home_score": h_s, "away_score": a_s}
	m["result"] = result_data
	match_results.append(result_data)
	_update_standings(m["home_team_idx"], m["away_team_idx"], h_s, a_s)

func to_dict(): return {"league": current_league, "day": current_match_day, "standings": standings, "schedule": schedule, "results": match_results, "summary": season_summary}
func from_dict(data):
	current_league = data["league"]; current_match_day = data["day"]
	standings = data["standings"]; schedule = data["schedule"]
	match_results = data.get("results", []); season_summary = data.get("summary", {})
