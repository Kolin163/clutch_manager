# ============================================================================
# PATCH NOTES SCREEN — Экран обновлений сезона
# ============================================================================
extends Control

@onready var season_lbl: Label = $SafeArea/VBox/Header/SeasonLabel
@onready var meta_title: Label = $SafeArea/VBox/Header/MetaTitle
@onready var meta_desc: Label = $SafeArea/VBox/Header/MetaDesc
@onready var blocks_grid: GridContainer = $SafeArea/VBox/BlocksScroll/BlocksGrid

func _ready() -> void:
	_update_ui()

func _update_ui() -> void:
	season_lbl.text = "ОБНОВЛЕНИЕ СЕЗОНА " + str(GameManager.current_season)
	meta_title.text = MetaManager.get_meta_name().to_upper()
	meta_desc.text = MetaManager.get_meta_description()
	
	for child in blocks_grid.get_children():
		child.queue_free()
	
	var raw_notes = MetaManager.get_patch_notes()
	
	var current_title := ""
	var current_lines: Array[String] = []
	
	for line in raw_notes:
		var txt = line.strip_edges()
		if txt == "":
			continue
		
		if txt.begins_with("==="):
			continue # Пропускаем главный заголовок (уже есть в meta_title)
			
		# Пропускаем описание, оно уже есть в meta_desc. Описание обычно идет до первого блока [..]
		if current_title == "" and not txt.begins_with("["):
			continue
			
		if txt.begins_with("[") and txt.ends_with("]"):
			if current_title != "" or current_lines.size() > 0:
				_create_block(current_title, current_lines)
			current_title = txt.replace("[", "").replace("]", "")
			current_lines = []
		else:
			current_lines.append(txt)
			
	if current_title != "" or current_lines.size() > 0:
		_create_block(current_title, current_lines)

func _create_block(title: String, lines: Array[String]) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Добавляем стиль для панели (опционально)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 15
	style.content_margin_top = 15
	style.content_margin_right = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 1.0)) # Светло-синий
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	
	# Разделитель
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.2, 0.25, 0.3, 1.0)
	vbox.add_child(sep)
	
	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var formatted_text = ""
	for l in lines:
		var colored_line = l
		if "+" in l:
			colored_line = "[color=#4DFF80]" + l + "[/color]"
		elif "-" in l:
			colored_line = "[color=#FF6666]" + l + "[/color]"
		elif "✅" in l:
			colored_line = "[color=#80FF80]" + l + "[/color]"
		elif "❌" in l:
			colored_line = "[color=#CC6666]" + l + "[/color]"
		
		formatted_text += "• " + colored_line + "\n"
		
	content.text = "[font_size=15]" + formatted_text.strip_edges() + "[/font_size]"
	vbox.add_child(content)
	
	blocks_grid.add_child(panel)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")
