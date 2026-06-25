# ============================================================================
# MAJOR MANAGER — Управление Мажором (Исправленная версия)
# ============================================================================
extends Node

const TOTAL_TEAMS := 12
const ADVANCE_PER_GROUP := 4

enum Phase { NONE, QUALIFICATION, GROUPS, QUARTERFINAL, SEMIFINAL, FINAL, FINISHED }

var major_phase: Phase = Phase.NONE
var is_major_active: bool = false
var major_teams: Array = []
var groups: Array = []
var bracket: Array = []
var player_in_major: bool = false
var major_winner: Dictionary = {}

func _ready() -> void:
	EventBus.debug("MajorManager ready", "MAJOR")

func start_major() -> void:
	reset_major()
	is_major_active = true
	_collect_participants()
	_setup_groups()
	major_phase = Phase.GROUPS
	EventBus.debug("Major started: Group Stage", "MAJOR")

func simulate_group_stage() -> void:
	if major_phase != Phase.GROUPS: return
	
	for group in groups:
		var teams = group["teams"]
		var standings = group["standings"]
		if teams.is_empty(): 
			group["complete"] = true
			continue
			
		for i in range(teams.size()):
			for j in range(i + 1, teams.size()):
				var result = _simulate_bo1(teams[i], teams[j])
				_update_group_standing(standings, teams[i], teams[j], result)
		
		group["complete"] = true
		standings.sort_custom(_sort_standings)
		
	_check_groups_complete()

func setup_playoffs() -> void:
	bracket.clear()
	if groups.size() < 2: return
	
	var group_a_advancers = groups[0]["standings"].slice(0, ADVANCE_PER_GROUP)
	var group_b_advancers = groups[1]["standings"].slice(0, ADVANCE_PER_GROUP)
	
	if group_a_advancers.size() < 4 or group_b_advancers.size() < 4:
		EventBus.debug("Not enough teams for playoffs!", "ERROR")
		major_phase = Phase.FINISHED
		return

	for i in range(ADVANCE_PER_GROUP):
		bracket.append({
			"round": "qf",
			"team_a": group_a_advancers[i]["team"],
			"team_b": group_b_advancers[ADVANCE_PER_GROUP - 1 - i]["team"],
			"played": false,
			"bo": 3,
			"result": {}
		})
	
	major_phase = Phase.QUARTERFINAL

func simulate_playoff() -> void:
	# Ограничение итераций для предотвращения зависания
	var safety_break := 0
	while major_phase != Phase.FINISHED and safety_break < 10:
		safety_break += 1
		
		var current_round_matches = _get_current_round_matches()
		if current_round_matches.is_empty():
			# Если мы в фазе, где нет матчей (например, только что закончили группы), пробуем продвинуться
			_advance_bracket()
			continue
			
		for match_data in current_round_matches:
			if match_data["played"]: continue
			match_data["result"] = _simulate_bo_series(match_data["team_a"], match_data["team_b"], match_data["bo"])
			match_data["played"] = true
		
		_advance_bracket()
	
	if safety_break >= 10:
		EventBus.debug("Major simulation safety break triggered!", "WARN")
		major_phase = Phase.FINISHED

func _collect_participants() -> void:
	major_teams.clear()
	
	# Пытаемся собрать из лиг
	var champions = AIWorld.get_league_standings("Champions")
	var elite = AIWorld.get_league_standings("Elite")
	
	for i in range(mini(6, champions.size())):
		major_teams.append(champions[i]["team"].duplicate(true))
	for i in range(mini(2, elite.size())):
		major_teams.append(elite[i]["team"].duplicate(true))
		
	# Добиваем до 12 если мир еще не полон (первый сезон)
	while major_teams.size() < TOTAL_TEAMS:
		var random_team = PlayerGenerator.generate_player({"potential": 50}) # Упрощенно
		major_teams.append({
			"name": "Team " + NameGenerator.generate_template_nickname(),
			"logo": "🤖",
			"strength": randf_range(40, 70),
			"roster": []
		})
		
	player_in_major = false
	for team in major_teams:
		if team.get("is_player", false):
			player_in_major = true
			break

func _setup_groups() -> void:
	var shuffled = major_teams.duplicate()
	shuffled.shuffle()
	var g1 = shuffled.slice(0, 6)
	var g2 = shuffled.slice(6, 12)
	groups = [
		{"name": "A", "teams": g1, "standings": _init_group_standings(g1), "complete": false},
		{"name": "B", "teams": g2, "standings": _init_group_standings(g2), "complete": false}
	]

func _init_group_standings(teams: Array) -> Array:
	var s = []
	for t in teams: s.append({"team": t, "wins": 0, "losses": 0, "points": 0})
	return s

func _simulate_bo1(a, b) -> String:
	var str_a = a.get("strength_val", 50.0)
	var str_b = b.get("strength_val", 50.0)
	return "a" if randf() < (str_a / (str_a + str_b)) else "b"

func _simulate_bo_series(a, b, bo: int) -> Dictionary:
	var wins_a = 0
	var wins_b = 0
	var needed = (bo / 2) + 1
	while wins_a < needed and wins_b < needed:
		if _simulate_bo1(a, b) == "a": wins_a += 1
		else: wins_b += 1
	return {
		"winner": "a" if wins_a > wins_b else "b",
		"score": str(wins_a) + ":" + str(wins_b),
		"winner_team": a if wins_a > wins_b else b
	}

func _advance_bracket() -> void:
	if major_phase == Phase.FINISHED: return
	
	var current_matches = _get_current_round_matches()
	var winners = []
	for m in current_matches:
		if m["played"]: winners.append(m["result"]["winner_team"])
	
	if major_phase == Phase.QUARTERFINAL and winners.size() == 4:
		bracket.append({"round": "sf", "team_a": winners[0], "team_b": winners[1], "played": false, "bo": 3, "result": {}})
		bracket.append({"round": "sf", "team_a": winners[2], "team_b": winners[3], "played": false, "bo": 3, "result": {}})
		major_phase = Phase.SEMIFINAL
	elif major_phase == Phase.SEMIFINAL and winners.size() == 2:
		bracket.append({"round": "final", "team_a": winners[0], "team_b": winners[1], "played": false, "bo": 5, "result": {}})
		major_phase = Phase.FINAL
	elif major_phase == Phase.FINAL and winners.size() == 1:
		major_winner = winners[0]
		major_phase = Phase.FINISHED
		is_major_active = false
	elif current_matches.is_empty() and major_phase == Phase.GROUPS:
		# Если группы закончены, но мы еще не в плей-офф
		setup_playoffs()

func _get_current_round_matches() -> Array:
	var target = ""
	match major_phase:
		Phase.QUARTERFINAL: target = "qf"
		Phase.SEMIFINAL: target = "sf"
		Phase.FINAL: target = "final"
	if target == "": return []
	var res = []
	for m in bracket:
		if m["round"] == target: res.append(m)
	return res

func _update_group_standing(standings, a, b, winner) -> void:
	for s in standings:
		if s["team"]["name"] == a["name"]:
			if winner == "a": s["wins"] += 1; s["points"] += 3
			else: s["losses"] += 1
		if s["team"]["name"] == b["name"]:
			if winner == "b": s["wins"] += 1; s["points"] += 3
			else: s["losses"] += 1

func _sort_standings(a, b): return a["points"] > b["points"]
func _check_groups_complete() -> void:
	if groups[0]["complete"] and groups[1]["complete"]: setup_playoffs()
func reset_major() -> void:
	major_phase = Phase.NONE
	major_teams = []; groups = []; bracket = []; major_winner = {}; is_major_active = false
func get_group_stage_data() -> Array: return groups
func get_playoff_bracket() -> Array: return bracket
func get_major_winner() -> Dictionary: return major_winner
func get_major_results() -> Dictionary:
	return {"winner": major_winner, "player_participated": player_in_major, "phase_reached": major_phase}

func to_dict() -> Dictionary:
	return {"phase": major_phase, "active": is_major_active, "teams": major_teams, "groups": groups, "bracket": bracket, "winner": major_winner}
func from_dict(data: Dictionary) -> void:
	major_phase = data.get("phase", 0); is_major_active = data.get("active", false)
	major_teams = data.get("teams", []); groups = data.get("groups", [])
	bracket = data.get("bracket", []); major_winner = data.get("winner", {})

func apply_manual_match_result(winner_side: String, match_res: Dictionary) -> void:
	if major_phase == Phase.GROUPS:
		var groups_data = get_group_stage_data()
		for g in groups_data:
			if g["complete"]: continue
			var has_player = false
			var player_team = {}
			for t in g["teams"]:
				if t.get("is_player", false):
					has_player = true
					player_team = t
					break
			if has_player:
				var opponent = match_res.get("opponent", {})
				var a = player_team
				var b = opponent
				_update_group_standing(g["standings"], a, b, winner_side)
				
				# ИИ матчи в группе симулируются параллельно
				simulate_group_stage()
				return
				
	elif major_phase >= Phase.QUARTERFINAL and major_phase <= Phase.FINAL:
		var matches = _get_current_round_matches()
		for m in matches:
			if not m["played"] and (m["team_a"].get("is_player", false) or m["team_b"].get("is_player", false)):
				m["played"] = true
				var w_team = m["team_a"] if winner_side == "a" else m["team_b"]
				m["result"] = {
					"winner": winner_side,
					"score": str(match_res.get("player_score", 0)) + ":" + str(match_res.get("enemy_score", 0)),
					"winner_team": w_team
				}
				simulate_playoff()
				return
