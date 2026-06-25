# ============================================================================
# BASE SCREEN — Информативный интерфейс штаба
# ============================================================================
extends Control

const RoomTileScene := preload("res://ui/components/room_tile.tscn")

@onready var budget_lbl: Label = $SafeArea/MainVBox/TopBar/BudgetLabel
@onready var base_name_lbl: Label = $SafeArea/MainVBox/TopBar/TitleVBox/BaseName
@onready var room_grid: GridContainer = $SafeArea/MainVBox/ContentHBox/BlueprintPanel/RoomGrid
@onready var upgrade_info: Label = $SafeArea/MainVBox/ContentHBox/ControlScroll/ControlPanel/UpgradeCard/VBox/Info
@onready var upgrade_btn: Button = $SafeArea/MainVBox/ContentHBox/ControlScroll/ControlPanel/UpgradeCard/VBox/UpgradeBtn
@onready var transport_name: Label = $SafeArea/MainVBox/ContentHBox/ControlScroll/ControlPanel/TransportCard/VBox/Name
@onready var transport_effect: Label = $SafeArea/MainVBox/ContentHBox/ControlScroll/ControlPanel/TransportCard/VBox/Effect
@onready var transport_btn: Button = $SafeArea/MainVBox/ContentHBox/ControlScroll/ControlPanel/TransportCard/VBox/UpgradeBtn
@onready var effects_list: VBoxContainer = $SafeArea/MainVBox/ContentHBox/ControlScroll/ControlPanel/EffectsCard/VBox/List
@onready var build_popup: PanelContainer = $BuildPopup
@onready var popup_list: VBoxContainer = $BuildPopup/VBox/Scroll/List
@onready var popup_overlay: ColorRect = $PopupOverlay

func _ready() -> void:
	_update_ui()

func _update_ui() -> void:
	budget_lbl.text = "$" + str(EconomyManager.get_budget())
	base_name_lbl.text = "УРОВЕНЬ: " + BaseManager.get_base_name().to_upper()
	_build_room_grid()
	_update_base_upgrade()
	_update_transport()
	_update_effects()

func _build_room_grid() -> void:
	for child in room_grid.get_children(): child.queue_free()
	var max_rooms = BaseManager.get_max_rooms()
	var built_rooms = BaseManager.get_built_rooms()
	for room in built_rooms:
		var tile = RoomTileScene.instantiate()
		room_grid.add_child(tile)
		tile.setup_built(room)
		tile.action_requested.connect(_on_tile_action)
	for i in range(max_rooms - built_rooms.size()):
		var tile = RoomTileScene.instantiate()
		room_grid.add_child(tile)
		tile.setup_empty(built_rooms.size() + i)
		tile.action_requested.connect(_on_tile_action)
	for i in range(7 - max_rooms):
		var tile = RoomTileScene.instantiate()
		room_grid.add_child(tile)
		tile.setup_locked()

func _update_base_upgrade() -> void:
	if BaseManager.can_upgrade_base():
		var cost = BaseManager.get_base_upgrade_cost()
		var next_idx = BaseManager.get_base_level() + 1
		var next_data = BaseManager.BASE_LEVELS[next_idx]
		upgrade_info.text = "СЛЕДУЮЩИЙ УРОВЕНЬ: %s\nНОВЫХ СЛОТОВ: +%d" % [
			next_data["name"], 
			next_data["max_rooms"] - BaseManager.get_max_rooms()
		]
		upgrade_btn.text = "ПЕРЕЕХАТЬ ЗА $" + str(cost)
		upgrade_btn.disabled = not EconomyManager.can_afford(cost)
		upgrade_btn.visible = true
	else:
		upgrade_info.text = "ШТАБ ПОЛНОСТЬЮ РАЗВИТ"
		upgrade_btn.visible = false

func _update_transport() -> void:
	var t = BaseManager.get_transport()
	transport_name.text = t.get_transport_name().to_upper()
	
	var pen_m = t.get_mental_penalty()
	var pen_f = t.get_fatigue_penalty()
	
	if pen_m == 0:
		transport_effect.text = "✅ Игроки не устают в дороге"
		transport_effect.modulate = Color.html("#4DFF80")
	else:
		transport_effect.text = "⚠️ Потеря ментала: %d\n⚠️ Усталость: +%d" % [abs(pen_m), pen_f]
		transport_effect.modulate = Color.html("#FF9966")
		
	if t.can_upgrade() and BaseManager.has_garage():
		var next = t.get_next_upgrade()
		transport_btn.text = "УЛУЧШИТЬ ЗА $" + str(next["cost"])
		transport_btn.disabled = not EconomyManager.can_afford(next["cost"])
		transport_btn.visible = true
	else:
		transport_btn.visible = false

func _update_effects() -> void:
	for child in effects_list.get_children(): child.queue_free()
	
	var effs = [
		{"icon": "🎮", "name": "Скорость тренировок", "val": BaseManager.get_training_speed_bonus(), "fmt": "+%d%%"},
		{"icon": "🖥️", "name": "Качество обучения", "val": BaseManager.get_training_quality_bonus(), "fmt": "+%d%%"},
		{"icon": "📹", "name": "Пассивный доход", "val": BaseManager.get_stream_income(), "fmt": "+$%d/день"},
		{"icon": "☕", "name": "Восстановление", "val": BaseManager.get_mental_recovery_bonus(), "fmt": "+%d%%"},
		{"icon": "💼", "name": "Слоты персонала", "val": BaseManager.get_staff_slots(), "fmt": "%d"},
		{"icon": "🤝", "name": "Скидка контрактов", "val": BaseManager.get_contract_discount(), "fmt": "-%d%%"}
	]
	
	for e in effs:
		if e.val <= 0: continue
		var lbl := Label.new()
		var display_val = e.val * 100 if "%" in e.fmt else e.val
		lbl.text = "%s %s: %s" % [e.icon, e.name, e.fmt % display_val]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color.html("#80E6B3")
		effects_list.add_child(lbl)

func _on_tile_action(room_id: String, action: String) -> void:
	if action == "build_menu": _show_build_popup()
	elif action == "upgrade": 
		BaseManager.upgrade_room(room_id)
		_update_ui()

func _show_build_popup() -> void:
	for child in popup_list.get_children(): child.queue_free()
	var available = BaseManager.get_available_to_build()
	
	for config in available:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.15, 1)
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.3, 0.4, 1)
		card.add_theme_stylebox_override("panel", style)
		popup_list.add_child(card)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		card.add_child(vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = config["name"].to_upper()
		name_lbl.add_theme_color_override("font_color", Color.html("#80CCFF"))
		vbox.add_child(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = config["description"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_lbl)
		
		var effect_lbl := Label.new()
		var val = config["levels"][0]["effect_value"]
		var display_val = val * 100 if val < 2 else val
		effect_lbl.text = "БОНУС: " + str(display_val) + ("%" if val < 2 else " шт")
		effect_lbl.add_theme_font_size_override("font_size", 11)
		effect_lbl.add_theme_color_override("font_color", Color.html("#4DFF80"))
		vbox.add_child(effect_lbl)
		
		var btn := Button.new()
		var cost = config["levels"][0]["cost"]
		btn.text = "ПОСТРОИТЬ ЗА $" + str(cost)
		btn.disabled = not EconomyManager.can_afford(cost)
		btn.pressed.connect(_on_build_confirm.bind(config["id"]))
		vbox.add_child(btn)
		
	popup_overlay.visible = true
	build_popup.visible = true

func _on_build_confirm(id: String) -> void:
	BaseManager.build_room(id)
	_on_popup_close_pressed()
	_update_ui()

func _on_popup_close_pressed() -> void:
	popup_overlay.visible = false
	build_popup.visible = false

func _on_base_upgrade_pressed() -> void:
	BaseManager.upgrade_base()
	_update_ui()

func _on_transport_upgrade_pressed() -> void:
	BaseManager.upgrade_transport()
	_update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")
