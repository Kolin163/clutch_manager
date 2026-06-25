# ============================================================================
# SAVE MANAGER — Сохранение через Bridge (пока заглушка)
# ============================================================================
# Использует Bridge.storage API. Сейчас Bridge = BridgeMock (заглушка).
# На этапе ~14 BridgeMock заменится на настоящий Playgama Bridge.
#
# Методы: set_value/get_value (в реальном Bridge будет обёртка)
# ============================================================================
extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const SAVE_KEY := "game_save"
const SETTINGS_KEY := "game_settings"

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var is_saving: bool = false
var is_loading: bool = false

# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	_connect_signals()
	EventBus.debug("SaveManager ready", "SAVE")

func _connect_signals() -> void:
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)

# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func save_game(data: Dictionary) -> void:
	if is_saving:
		EventBus.debug("Save already in progress", "SAVE")
		return
	
	is_saving = true
	var save_data := data.duplicate(true)
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	save_data["version"] = "0.1.0"
	
	var json_string := JSON.stringify(save_data)
	Bridge.storage.set_value(SAVE_KEY, json_string, Callable(self, "_on_save_completed"))
	EventBus.debug("Saving...", "SAVE")

func load_game() -> void:
	if is_loading:
		EventBus.debug("Load already in progress", "SAVE")
		return
	
	is_loading = true
	Bridge.storage.get_value(SAVE_KEY, Callable(self, "_on_load_completed"))
	EventBus.debug("Loading...", "SAVE")

func check_save_exists(callback: Callable) -> void:
	Bridge.storage.get_value(SAVE_KEY, Callable(self, "_on_check_save").bind(callback))

func delete_save() -> void:
	Bridge.storage.delete_value(SAVE_KEY, Callable(self, "_on_delete_completed"))

# ----------------------------------------------------------------------------
# BRIDGE CALLBACKS
# ----------------------------------------------------------------------------
func _on_save_completed(success: bool) -> void:
	is_saving = false
	if success:
		EventBus.debug("Saved!", "SAVE")
	else:
		EventBus.debug("Save failed!", "ERROR")
	EventBus.save_completed.emit(success)

func _on_load_completed(success: bool, data) -> void:
	is_loading = false
	if not success or data == null:
		EventBus.debug("No save found", "SAVE")
		EventBus.load_completed.emit(false, {})
		return
	
	var json := JSON.new()
	var error := json.parse(str(data))
	if error != OK:
		EventBus.debug("JSON parse error", "ERROR")
		EventBus.load_completed.emit(false, {})
		return
	
	EventBus.debug("Loaded!", "SAVE")
	EventBus.load_completed.emit(true, json.data)

func _on_check_save(success: bool, data, original_callback: Callable) -> void:
	var exists := success and data != null
	original_callback.call(exists)

func _on_delete_completed(success: bool) -> void:
	if success:
		EventBus.debug("Save deleted", "SAVE")
	else:
		EventBus.debug("Delete failed", "ERROR")

# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_save_requested() -> void:
	var save_data := {
		"team": GameManager.player_team_data,
		"season": GameManager.current_season,
		"match_day": GameManager.current_match_day,
		"state": GameManager.get_current_state_name(),
		"roster": RosterManager.to_dict(),
		"economy": EconomyManager.to_dict(),
		"agent_pool": AgentPool.to_dict(),
		"scouting": Scouting.to_dict(),
		"league": LeagueManager.to_dict(),
		"base": BaseManager.to_dict(),
		"training": TrainingManager.to_dict(),
		"aging": AgingManager.to_dict(),
		"staff": StaffManager.to_dict(),
		"sponsors": SponsorManager.to_dict(),
		"meta": MetaManager.to_dict(),
		"major": MajorManager.to_dict(),
		"offmatch_events": OffMatchEventManager.to_dict(),
		"ai_world": AIWorld.to_dict(),
		"last_match_result": GameManager.last_match_result,
		"season_results": GameManager.season_results_data
	}
	save_game(save_data)

func _on_load_requested() -> void:
	load_game()

# ----------------------------------------------------------------------------
# TEST
# ----------------------------------------------------------------------------
func test_save_load() -> void:
	EventBus.debug("Testing save system...", "SAVE")
	var test_data := {
		"test_key": "test_value",
		"test_number": 42
	}
	var json_string := JSON.stringify(test_data)
	Bridge.storage.set_value("test_save", json_string, Callable(self, "_on_test_save_completed"))

func _on_test_save_completed(success: bool) -> void:
	EventBus.debug("Test save: " + str(success), "SAVE")
	if success:
		Bridge.storage.get_value("test_save", Callable(self, "_on_test_load_completed"))

func _on_test_load_completed(success: bool, data) -> void:
	if success and data != null:
		var json := JSON.new()
		if json.parse(str(data)) == OK:
			var parsed: Dictionary = json.data
			if parsed.get("test_key") == "test_value":
				EventBus.debug("[color=green]TEST PASSED![/color]", "SAVE")
				return
	EventBus.debug("[color=red]TEST FAILED![/color]", "SAVE")
