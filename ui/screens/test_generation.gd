# ============================================================================
# TEST GENERATION — Тестовый экран генерации игроков
# ============================================================================
# Кнопки для генерации разных типов игроков.
# Показывает карточки сгенерированных игроков.
# ============================================================================

extends Control

# ----------------------------------------------------------------------------
# PRELOADS
# ----------------------------------------------------------------------------
const PlayerCardScene := preload("res://ui/components/player_card.tscn")

# ----------------------------------------------------------------------------
# NODES
# ----------------------------------------------------------------------------
@onready var card_container: HBoxContainer = $VBox/ScrollContainer/CardContainer
@onready var count_label: Label = $VBox/Controls/CountLabel
@onready var debug_log: RichTextLabel = $DebugPanel/VBox/DebugLog

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var _generated_count: int = 0
var _debug_messages: Array[String] = []
const MAX_DEBUG_LINES := 15


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.debug_message.connect(_on_debug_message)
	_log("Test generation screen ready")
	_log("Click buttons to generate players")


# ----------------------------------------------------------------------------
# BUTTON HANDLERS
# ----------------------------------------------------------------------------
func _on_back_pressed() -> void:
	GameManager.return_to_menu()


func _on_generate_pressed() -> void:
	_clear_cards()
	var player_data := PlayerGenerator.generate_random_player()
	_add_player_card(player_data)
	_log_player(player_data)


func _on_generate_5_pressed() -> void:
	_clear_cards()
	var roster := PlayerGenerator.generate_roster(5)
	
	for player_data in roster:
		_add_player_card(player_data)
	
	_log("Generated roster of 5 players")
	for player_data in roster:
		_log("  - " + player_data["nickname"] + " (" + player_data["role"] + ")")


func _on_young_pressed() -> void:
	_clear_cards()
	var player_data := PlayerGenerator.generate_young_talent()
	_add_player_card(player_data)
	_log_player(player_data)
	_log("[color=cyan]Young talent (16-19, high potential)[/color]")


func _on_veteran_pressed() -> void:
	_clear_cards()
	var player_data := PlayerGenerator.generate_veteran()
	_add_player_card(player_data)
	_log_player(player_data)
	_log("[color=orange]Veteran (28-32)[/color]")


# ----------------------------------------------------------------------------
# CARD MANAGEMENT
# ----------------------------------------------------------------------------
func _add_player_card(player_data: Dictionary) -> void:
	var card := PlayerCardScene.instantiate()
	card_container.add_child(card)
	card.set_player_data(player_data)
	
	_generated_count += 1
	_update_count_label()


func _clear_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()


func _update_count_label() -> void:
	count_label.text = "Generated: " + str(_generated_count)


# ----------------------------------------------------------------------------
# DEBUG LOGGING
# ----------------------------------------------------------------------------
func _log(message: String) -> void:
	_debug_messages.append(message)
	
	while _debug_messages.size() > MAX_DEBUG_LINES:
		_debug_messages.pop_front()
	
	if debug_log:
		debug_log.clear()
		debug_log.append_text("\n".join(_debug_messages))


func _log_player(data: Dictionary) -> void:
	var nick: String = data.get("nickname", "?")
	var nation: String = data.get("nationality", "?").to_upper().left(3)
	var age: int = data.get("age", 0)
	var role: String = data.get("role", "?")
	var potential: int = data.get("potential", 0)
	
	var combat: Dictionary = data.get("combat_skills", {})
	var avg_combat: int = 0
	for v in combat.values():
		avg_combat += v
	avg_combat = avg_combat / maxi(combat.size(), 1)
	
	_log("[color=yellow]%s[/color] | %s | %d y.o. | %s | Pot: %d | Avg: %d" % [
		nick, nation, age, role, potential, avg_combat
	])


func _on_debug_message(message: String, category: String) -> void:
	var color := "aaaaaa"
	match category:
		"ERROR":
			color = "ff6666"
		"WARN":
			color = "ffff66"
	
	_log("[color=#%s][%s][/color] %s" % [color, category, message])
