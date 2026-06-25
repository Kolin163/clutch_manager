# ============================================================================
# BRIDGE MOCK — Заглушка Playgama Bridge для разработки
# ============================================================================
# Имитирует API Bridge.storage для тестирования без реального SDK.
# На этапе интеграции (~14) заменится на настоящий Playgama Bridge.
#
# ВАЖНО: Методы названы set_value/get_value (не set/get) чтобы не
# конфликтовать с Object.set/get. При интеграции реального Bridge
# сделаем обёртку.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# MOCK STORAGE (в памяти, сбрасывается при перезапуске)
# ----------------------------------------------------------------------------
var _mock_storage: Dictionary = {}

# ----------------------------------------------------------------------------
# STORAGE API (имитация Bridge.storage)
# ----------------------------------------------------------------------------
var storage: BridgeStorageMock


func _ready() -> void:
	storage = BridgeStorageMock.new()
	storage._parent = self
	EventBus.debug("BridgeMock ready (dev mode)", "BRIDGE")


# ----------------------------------------------------------------------------
# INNER CLASS: Storage Mock
# ----------------------------------------------------------------------------
class BridgeStorageMock extends RefCounted:
	var _parent: Node
	
	
	func set_value(key, value, callback: Callable, _storage_type = null) -> void:
		# Имитируем асинхронность через call_deferred
		if key is Array:
			for i in range(key.size()):
				_parent._mock_storage[key[i]] = value[i]
		else:
			_parent._mock_storage[key] = value
		
		_parent.call_deferred("_call_callback_success", callback)
	
	
	func get_value(key, callback: Callable, _storage_type = null) -> void:
		if key is Array:
			var results := []
			for k in key:
				results.append(_parent._mock_storage.get(k, null))
			_parent.call_deferred("_call_callback_data", callback, true, results)
		else:
			var data = _parent._mock_storage.get(key, null)
			_parent.call_deferred("_call_callback_data", callback, true, data)
	
	
	func delete_value(key, callback: Callable, _storage_type = null) -> void:
		if _parent._mock_storage.has(key):
			_parent._mock_storage.erase(key)
		_parent.call_deferred("_call_callback_success", callback)


# ----------------------------------------------------------------------------
# CALLBACK HELPERS
# ----------------------------------------------------------------------------
func _call_callback_success(callback: Callable) -> void:
	callback.call(true)


func _call_callback_data(callback: Callable, success: bool, data) -> void:
	callback.call(success, data)


# ----------------------------------------------------------------------------
# DEBUG
# ----------------------------------------------------------------------------
func get_mock_storage_keys() -> Array:
	return _mock_storage.keys()


func clear_mock_storage() -> void:
	_mock_storage.clear()
	EventBus.debug("Mock storage cleared", "BRIDGE")
