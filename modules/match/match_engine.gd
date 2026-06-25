# ============================================================================
# MATCH ENGINE — Основной движок матча (State Machine Pattern)
# ============================================================================
extends Node

# ----------------------------------------------------------------------------
# ENUMS & CONSTANTS
# ----------------------------------------------------------------------------
enum MatchState {
	INIT,
	TACTIC_SELECTION,
	SIMULATING,
	EVENT_WAIT,
	ROUND_END,
	MATCH_END
}

const ROUNDS_PER_HALF := 12
const ROUNDS_TO_WIN := 13

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var current_state: MatchState = MatchState.INIT

var current_round: int = 0
var current_half: int = 1
var player_score: int = 0
var enemy_score: int = 0
var player_side: String = "attack"
var player_tactic: String = "default"
var enemy_tactic: String = "default"

var current_map: Dictionary = {}
var enemy_team: Dictionary = {}
var round_history: Array[Dictionary] = []

var current_event: Dictionary = {}
var round_modifier: float = 0.0
var momentum: int = 0

# ----------------------------------------------------------------------------
# SIGNALS
# ----------------------------------------------------------------------------
signal state_changed(new_state: MatchState)
signal match_started(map_data: Dictionary, enemy_data: Dictionary)
signal tactic_requested(side: String)
signal simulation_started()
signal event_triggered(event_data: Dictionary)
signal event_resolved(success: bool)
signal round_ended(round_num: int, winner: String, player_score: int, enemy_score: int)
signal half_ended(half: int, player_score: int, enemy_score: int)
signal match_ended(result: Dictionary)

# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.debug("MatchEngine (FSM) ready", "MATCH")

# ----------------------------------------------------------------------------
# PUBLIC API - STATE TRANSITIONS
# ----------------------------------------------------------------------------
func start_match(map_data: Dictionary, enemy_data: Dictionary) -> void:
	_reset_state()
	current_map = map_data
	enemy_team = enemy_data
	player_side = "attack" if randf() > 0.5 else "defense"
	
	_change_state(MatchState.INIT)
	match_started.emit(current_map, enemy_team)
	
	_next_round_setup()

func confirm_tactic(tactic_id: String) -> void:
	if current_state != MatchState.TACTIC_SELECTION:
		return
	player_tactic = tactic_id
	_start_simulation()

func resolve_event(choice_id: String) -> void:
	if current_state != MatchState.EVENT_WAIT:
		return
		
	if choice_id == "timeout":
		round_modifier += -0.05
		event_resolved.emit(false)
		current_event = {}
		_finish_round_simulation()
		return
		
	var choice := _find_choice(current_event, choice_id)
	var p_pow := _calculate_team_power(true)
	var risk: float = choice.get("risk", 0.5)
	
	var base_chance := clampf(p_pow / 100.0, 0.3, 0.8)
	var final_chance := clampf(base_chance - (risk * 0.3) + 0.1, 0.1, 0.95)
	
	var success := randf() < final_chance
	
	if not choice.is_empty():
		round_modifier += choice.get("success_bonus", 0.1) if success else choice.get("fail_penalty", -0.1)
		
	event_resolved.emit(success)
	current_event = {}
	_finish_round_simulation()

func proceed_to_next_round() -> void:
	if current_state == MatchState.ROUND_END or current_state == MatchState.INIT:
		_next_round_setup()

# ----------------------------------------------------------------------------
# INTERNAL LOGIC
# ----------------------------------------------------------------------------
func get_match_state() -> Dictionary:
	return {
		"is_active": current_state != MatchState.INIT and current_state != MatchState.MATCH_END,
		"round": current_round,
		"half": current_half,
		"player_score": player_score,
		"enemy_score": enemy_score,
		"player_side": player_side,
		"player_tactic": player_tactic,
		"momentum": momentum,
		"map": current_map,
		"enemy": enemy_team
	}

func _change_state(new_state: MatchState) -> void:
	current_state = new_state
	state_changed.emit(current_state)

func _next_round_setup() -> void:
	current_round += 1
	round_modifier = 0.0
	current_event = {}
	
	_change_state(MatchState.TACTIC_SELECTION)
	tactic_requested.emit(player_side)

func _start_simulation() -> void:
	_change_state(MatchState.SIMULATING)
	simulation_started.emit()
	
	enemy_tactic = "default" # TODO: AI Logic
	
	if _should_trigger_event():
		_trigger_event()
	else:
		_finish_round_simulation()

func _trigger_event() -> void:
	_change_state(MatchState.EVENT_WAIT)
	
	var round_type = "gun" 
	var ev = MatchEvent.get_random_event(round_type, player_side)
	
	if ev.is_empty():
		ev = {
			"id": "clutch_fallback",
			"title": "СИТУАЦИЯ",
			"text": "Игрок остался 1 в 2. Что делать?",
			"type": "clutch",
			"choices": [
				{"id": "aggressive", "text": "Агрессивный пик", "success_bonus": 0.3, "fail_penalty": -0.2, "risk": 0.7, "skill_check": "aim"},
				{"id": "save", "text": "Сохранить оружие", "success_bonus": 0.0, "fail_penalty": -0.1, "risk": 0.1, "skill_check": "game_sense"}
			]
		}
		
	current_event = ev
	event_triggered.emit(current_event)

func _finish_round_simulation() -> void:
	var p_pow := _calculate_team_power(true)
	var e_pow := _calculate_team_power(false)
	
	p_pow *= (1.0 + MetaManager.get_tactic_modifier(player_tactic))
	p_pow *= (1.0 + float(momentum) * 0.03 + round_modifier)
	
	var p_win_chance := p_pow / (p_pow + e_pow) if (p_pow + e_pow) > 0 else 0.5
	var p_wins := randf() < p_win_chance
	
	var winner := "player" if p_wins else "enemy"
	
	if p_wins:
		player_score += 1
		momentum = mini(momentum + 1, 3)
	else:
		enemy_score += 1
		momentum = maxi(momentum - 1, -3)
		
	round_history.append({"round": current_round, "winner": winner, "player_score": player_score, "enemy_score": enemy_score})
	
	_change_state(MatchState.ROUND_END)
	round_ended.emit(current_round, winner, player_score, enemy_score)
	
	_check_match_status()

func _check_match_status() -> void:
	if player_score >= ROUNDS_TO_WIN or enemy_score >= ROUNDS_TO_WIN:
		_change_state(MatchState.MATCH_END)
		var winner := "player" if player_score > enemy_score else "enemy"
		match_ended.emit({
			"winner": winner,
			"player_score": player_score,
			"enemy_score": enemy_score
		})
		return
		
	if current_round == ROUNDS_PER_HALF and current_half == 1:
		current_half = 2
		player_side = "defense" if player_side == "attack" else "attack"
		half_ended.emit(1, player_score, enemy_score)

# ----------------------------------------------------------------------------
# UTILITIES
# ----------------------------------------------------------------------------
func _calculate_team_power(is_player: bool) -> float:
	var roster = RosterManager.get_roster() if is_player else enemy_team.get("roster", [])
	if roster.size() < 5: return 50.0
	var total_power = 0.0
	for p in roster:
		var combat = p.get("combat_skills", {})
		var avg = 0.0
		for v in combat.values(): avg += v
		total_power += (avg / maxi(combat.size(), 1))
	return total_power / roster.size()

func _should_trigger_event() -> bool:
	return randf() < 0.25

func _find_choice(ev: Dictionary, id: String) -> Dictionary:
	for c in ev.get("choices", []):
		if c.get("id", "") == id: return c
	return {}

func _reset_state() -> void:
	current_round = 0
	current_half = 1
	player_score = 0
	enemy_score = 0
	momentum = 0
	round_history.clear()
