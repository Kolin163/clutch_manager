# ============================================================================
# SPONSOR SCREEN — Обновленный интерфейс сделок
# ============================================================================
extends Control

@onready var active_list: VBoxContainer = $SafeArea/MainVBox/ContentHBox/ActiveSection/Scroll/ActiveList
@onready var offers_list: VBoxContainer = $SafeArea/MainVBox/ContentHBox/OffersSection/Scroll/OffersList
@onready var income_lbl: Label = $SafeArea/MainVBox/Header/TotalIncomeLabel
@onready var refresh_btn: Button = $SafeArea/MainVBox/ContentHBox/OffersSection/Header/RefreshBtn

func _ready() -> void:
	if SponsorManager.get_offers().is_empty():
		SponsorManager.generate_offers(3)
	update_ui()

func update_ui() -> void:
	income_lbl.text = "ДОХОД: $" + str(SponsorManager.get_total_sponsor_income()) + "/СЕЗОН"
	
	var can_reroll = SponsorManager.rerolls_this_season < SponsorManager.MAX_REROLLS_PER_SEASON
	refresh_btn.disabled = not can_reroll
	refresh_btn.modulate.a = 1.0 if can_reroll else 0.4
	
	_build_lists()

func _build_lists() -> void:
	for child in active_list.get_children(): child.queue_free()
	for child in offers_list.get_children(): child.queue_free()
	
	# Действующие
	var active = SponsorManager.get_active_sponsors()
	if active.is_empty():
		_add_empty_msg(active_list, "Нет активных контрактов")
	else:
		for s in active: active_list.add_child(_create_card(s, true))
		
	# Предложения
	var offers = SponsorManager.get_offers()
	if offers.is_empty():
		_add_empty_msg(offers_list, "Нет новых предложений")
	else:
		for o in offers: offers_list.add_child(_create_card(o, false))

func _create_card(data: Dictionary, is_active: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.2, 0.15, 1) if is_active else Color(0.1, 0.12, 0.18, 1)
	style.border_color = Color(0.3, 0.6, 0.4, 1) if is_active else Color(0.2, 0.3, 0.4, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Header: Название и Деньги
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var name_lbl := Label.new()
	name_lbl.text = "🤝 " + data.get("name", "Sponsor").to_upper()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	header.add_child(name_lbl)
	
	var pay_lbl := Label.new()
	pay_lbl.text = "+$" + str(data.get("payment", 0))
	pay_lbl.add_theme_color_override("font_color", Color.html("#4DFF80"))
	pay_lbl.add_theme_font_size_override("font_size", 16)
	header.add_child(pay_lbl)
	
	# Условие
	var cond_lbl := Label.new()
	cond_lbl.text = "🎯 ЦЕЛЬ: " + data.get("condition_text", "Без условий")
	cond_lbl.add_theme_font_size_override("font_size", 12)
	cond_lbl.add_theme_color_override("font_color", Color.html("#FFCC66"))
	vbox.add_child(cond_lbl)
	
	# Срок и Штраф
	var footer := HBoxContainer.new()
	vbox.add_child(footer)
	
	var time_lbl := Label.new()
	time_lbl.text = "Срок: %d сез." % data.get("seasons_left", 1)
	time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.modulate = Color(0.7, 0.7, 0.8, 1)
	footer.add_child(time_lbl)
	
	var penalty_lbl := Label.new()
	penalty_lbl.text = "Штраф: -$" + str(data.get("penalty", 0))
	penalty_lbl.add_theme_font_size_override("font_size", 11)
	penalty_lbl.add_theme_color_override("font_color", Color.html("#FF6666"))
	footer.add_child(penalty_lbl)
	
	if not is_active:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 5
		vbox.add_child(spacer)
		
		var btn := Button.new()
		btn.text = "ПОДПИСАТЬ КОНТРАКТ"
		btn.custom_minimum_size.y = 35
		btn.disabled = SponsorManager.get_active_sponsors().size() >= SponsorManager.MAX_ACTIVE_SPONSORS
		btn.pressed.connect(_on_accept.bind(data.get("id", "")))
		vbox.add_child(btn)
	
	return panel

func _add_empty_msg(container: Control, msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.5, 0.5, 0.6, 1)
	lbl.add_theme_font_size_override("font_size", 13)
	container.add_child(lbl)

func _on_accept(offer_id: String) -> void:
	if SponsorManager.accept_offer(offer_id):
		update_ui()

func _on_refresh_pressed() -> void:
	SponsorManager.rerolls_this_season += 1
	SponsorManager.generate_offers(3)
	update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")
