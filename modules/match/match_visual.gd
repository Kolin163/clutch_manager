# ============================================================================
# MATCH VISUAL — Визуализация матча
# ============================================================================
# Управляет отображением карты, иконок игроков и анимаций.
# Используется match_screen.tscn для рендера.
# ============================================================================

class_name MatchVisual
extends RefCounted

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const PLAYER_ICON_SIZE := Vector2(24, 24)
const ANIMATION_DURATION := 0.5

# Цвета команд
const TEAM_COLORS := {
	"player_attack": Color(0.2, 0.6, 1.0),   # Синий
	"player_defense": Color(0.2, 0.8, 0.4),  # Зелёный
	"enemy_attack": Color(1.0, 0.3, 0.2),    # Красный
	"enemy_defense": Color(1.0, 0.6, 0.2)    # Оранжевый
}

# Позиции на карте (нормализованные 0-1)
const MAP_POSITIONS := {
	"t_spawn": Vector2(0.1, 0.5),
	"ct_spawn": Vector2(0.9, 0.5),
	"a_site": Vector2(0.75, 0.25),
	"b_site": Vector2(0.75, 0.75),
	"mid": Vector2(0.5, 0.5),
	"a_long": Vector2(0.4, 0.2),
	"b_tunnels": Vector2(0.3, 0.8),
	"a_short": Vector2(0.5, 0.3),
	"b_window": Vector2(0.6, 0.7)
}

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var _player_icons: Array[Dictionary] = []
var _enemy_icons: Array[Dictionary] = []
var _current_animation: String = ""


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func setup_round(player_side: String, player_tactic: String, enemy_tactic: String) -> Dictionary:
	"""Возвращает данные для отображения раунда."""
	var player_positions := _get_tactic_positions(player_tactic, player_side == "attack")
	var enemy_side := "defense" if player_side == "attack" else "attack"
	var enemy_positions := _get_tactic_positions(enemy_tactic, enemy_side == "attack")
	
	return {
		"player_team": {
			"side": player_side,
			"color": TEAM_COLORS["player_" + player_side],
			"positions": player_positions
		},
		"enemy_team": {
			"side": enemy_side,
			"color": TEAM_COLORS["enemy_" + enemy_side],
			"positions": enemy_positions
		}
	}


func get_round_animation(round_result: Dictionary) -> Dictionary:
	"""Возвращает данные анимации для результата раунда."""
	var winner: String = round_result.get("winner", "player")
	var player_tactic: String = round_result.get("player_tactic", "default")
	var event: Dictionary = round_result.get("event", {})
	
	var animation := {
		"type": "round_end",
		"winner": winner,
		"duration": ANIMATION_DURATION,
		"highlights": []
	}
	
	# Добавляем подсветку ивента
	if not event.is_empty():
		animation["highlights"].append({
			"type": "event",
			"event_id": event.get("id", ""),
			"position": _get_event_position(event)
		})
	
	# Добавляем анимацию по тактике
	animation["movement"] = _get_tactic_movement(player_tactic, winner == "player")
	
	return animation


func get_player_positions_for_tactic(tactic: String, is_attacking: bool) -> Array[Vector2]:
	"""Возвращает позиции 5 игроков для тактики."""
	return _get_tactic_positions(tactic, is_attacking)


# ----------------------------------------------------------------------------
# TACTIC POSITIONS
# ----------------------------------------------------------------------------
func _get_tactic_positions(tactic: String, is_attacking: bool) -> Array[Vector2]:
	"""Возвращает позиции игроков для тактики."""
	var positions: Array[Vector2] = []
	
	if is_attacking:
		match tactic:
			"rush":
				# Все близко к точке входа
				positions = [
					MAP_POSITIONS["t_spawn"] + Vector2(0.1, -0.1),
					MAP_POSITIONS["t_spawn"] + Vector2(0.1, 0.0),
					MAP_POSITIONS["t_spawn"] + Vector2(0.1, 0.1),
					MAP_POSITIONS["t_spawn"] + Vector2(0.15, -0.05),
					MAP_POSITIONS["t_spawn"] + Vector2(0.15, 0.05)
				]
			"split":
				# Разделены на две группы
				positions = [
					MAP_POSITIONS["a_long"],
					MAP_POSITIONS["a_long"] + Vector2(0.05, 0.05),
					MAP_POSITIONS["mid"],
					MAP_POSITIONS["b_tunnels"],
					MAP_POSITIONS["b_tunnels"] + Vector2(0.05, -0.05)
				]
			"slow_execute":
				# Рядом с mid, собирают информацию
				positions = [
					MAP_POSITIONS["mid"] + Vector2(-0.1, 0.0),
					MAP_POSITIONS["mid"] + Vector2(-0.05, -0.1),
					MAP_POSITIONS["mid"] + Vector2(-0.05, 0.1),
					MAP_POSITIONS["a_short"],
					MAP_POSITIONS["b_window"]
				]
			_:  # default
				positions = [
					MAP_POSITIONS["t_spawn"] + Vector2(0.15, 0.0),
					MAP_POSITIONS["a_long"],
					MAP_POSITIONS["mid"],
					MAP_POSITIONS["b_tunnels"],
					MAP_POSITIONS["t_spawn"] + Vector2(0.1, 0.15)
				]
	else:
		# Defense positions
		match tactic:
			"stack":
				# Все на одном сайте
				var site := MAP_POSITIONS["a_site"] if randf() > 0.5 else MAP_POSITIONS["b_site"]
				positions = [
					site + Vector2(-0.05, -0.05),
					site + Vector2(-0.05, 0.05),
					site + Vector2(0.0, 0.0),
					site + Vector2(0.05, -0.05),
					site + Vector2(0.05, 0.05)
				]
			"aggressive_ct":
				# Вперёд, агрессивно
				positions = [
					MAP_POSITIONS["a_long"] + Vector2(0.1, 0.0),
					MAP_POSITIONS["mid"] + Vector2(0.1, 0.0),
					MAP_POSITIONS["b_tunnels"] + Vector2(0.15, 0.0),
					MAP_POSITIONS["a_site"],
					MAP_POSITIONS["b_site"]
				]
			_:  # passive, default
				positions = [
					MAP_POSITIONS["a_site"],
					MAP_POSITIONS["a_site"] + Vector2(-0.1, 0.0),
					MAP_POSITIONS["mid"] + Vector2(0.15, 0.0),
					MAP_POSITIONS["b_site"],
					MAP_POSITIONS["b_site"] + Vector2(-0.1, 0.0)
				]
	
	return positions


func _get_tactic_movement(tactic: String, is_success: bool) -> Array[Dictionary]:
	"""Возвращает данные движения для анимации."""
	var movements: Array[Dictionary] = []
	
	# Базовое движение к цели
	var target: Vector2
	if is_success:
		target = MAP_POSITIONS["a_site"]  # Успешно захватили
	else:
		target = MAP_POSITIONS["t_spawn"]  # Откатились
	
	for i in range(5):
		movements.append({
			"from_index": i,
			"to": target + Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)),
			"speed": 1.0 if tactic == "rush" else 0.5
		})
	
	return movements


func _get_event_position(event: Dictionary) -> Vector2:
	"""Возвращает позицию для отображения ивента."""
	var event_type: String = event.get("type", "")
	
	match event_type:
		"clutch":
			return MAP_POSITIONS["a_site"]
		"combat":
			return MAP_POSITIONS["mid"]
		_:
			return MAP_POSITIONS["mid"]


# ----------------------------------------------------------------------------
# ROUND TYPE INDICATORS
# ----------------------------------------------------------------------------
static func get_round_type_color(round_type: String) -> Color:
	"""Возвращает цвет для типа раунда."""
	match round_type:
		"pistol":
			return Color(1.0, 0.8, 0.2)  # Жёлтый
		"eco":
			return Color(0.6, 0.6, 0.6)  # Серый
		"force":
			return Color(1.0, 0.5, 0.2)  # Оранжевый
		"gun":
			return Color(0.3, 0.8, 0.3)  # Зелёный
		_:
			return Color(1.0, 1.0, 1.0)


static func get_round_type_name(round_type: String) -> String:
	"""Возвращает название типа раунда."""
	match round_type:
		"pistol":
			return "Пистолетный"
		"eco":
			return "Эко"
		"force":
			return "Форс"
		"gun":
			return "Полная закупка"
		_:
			return "Раунд"
