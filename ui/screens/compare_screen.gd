# ============================================================================
# COMPARE SCREEN — Экран сравнения (Исправленный Grid)
# ============================================================================
extends Control

@onready var nick1: Label = $Center/Panel/Margin/VBox/NicksHBox/Nick1
@onready var nick2: Label = $Center/Panel/Margin/VBox/NicksHBox/Nick2
@onready var compare_grid: GridContainer = $Center/Panel/Margin/VBox/CompareGrid

func setup(p1: Dictionary, p2: Dictionary) -> void:
	nick1.text = p1["nickname"]
	nick2.text = p2["nickname"]
	
	for child in compare_grid.get_children(): child.queue_free()
	
	var c1 = p1.get("combat_skills", {})
	var c2 = p2.get("combat_skills", {})
	
	_add_row("AIM", c1.get("aim", 0), c2.get("aim", 0))
	_add_row("UTILITY", c1.get("utility", 0), c2.get("utility", 0))
	_add_row("SENSE", c1.get("game_sense", 0), c2.get("game_sense", 0))
	_add_row("AGE", p1.get("age", 0), p2.get("age", 0), true) # Меньше = лучше

func _add_row(label_text: String, val1: int, val2: int, reverse: bool = false) -> void:
	# 1. Значение игрока 1
	var l1 := Label.new()
	l1.text = str(val1)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 2. Название параметра
	var mid := Label.new()
	mid.text = label_text
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_theme_color_override("font_color", Color.html("#666680"))
	mid.custom_minimum_size = Vector2(100, 0)
	
	# 3. Значение игрока 2
	var l2 := Label.new()
	l2.text = str(val2)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Раскраска
	if val1 > val2:
		l1.add_theme_color_override("font_color", Color.html("#FF6666") if reverse else Color.html("#4DFF80"))
		l2.add_theme_color_override("font_color", Color.html("#4DFF80") if reverse else Color.html("#FF6666"))
	elif val1 < val2:
		l1.add_theme_color_override("font_color", Color.html("#4DFF80") if reverse else Color.html("#FF6666"))
		l2.add_theme_color_override("font_color", Color.html("#FF6666") if reverse else Color.html("#4DFF80"))
		
	compare_grid.add_child(l1)
	compare_grid.add_child(mid)
	compare_grid.add_child(l2)

func _on_close_pressed() -> void:
	queue_free()
