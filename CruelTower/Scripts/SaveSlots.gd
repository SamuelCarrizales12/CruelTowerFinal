extends Control

# Usamos get_node_or_null para evitar que el motor falle si no encuentra un nodo
@onready var label_slot_1: Label = $HBoxContainer/Slot1/Ssc.get_node_or_null("Label") if has_node("HBoxContainer/Slot1/Ssc") else null
@onready var label_slot_2: Label = $HBoxContainer/Ssc2.get_node_or_null("Label") if has_node("HBoxContainer/Ssc2") else null
@onready var label_slot_3: Label = $HBoxContainer/Ssc3.get_node_or_null("Label") if has_node("HBoxContainer/Ssc3") else null

func _ready() -> void:
	update_all_slots_ui()

func update_all_slots_ui() -> void:
	_update_slot_label(1, label_slot_1)
	_update_slot_label(2, label_slot_2)
	_update_slot_label(3, label_slot_3)

func _update_slot_label(slot_num: int, label_node: Label) -> void:
	# Si la etiqueta no existe en la escena, simplemente se ignora sin romper el juego
	if label_node == null:
		return
		
	if SaveLoad.has_save(slot_num):
		label_node.text = "Slot " + str(slot_num) + " - Ocupado"
	else:
		label_node.text = "VACÍO"

# --- MÉTODOS DE BOTONES ---

func _on_selecc_p_pressed_slot_1() -> void: _handle_select_slot(1)
func _on_selecc_p_pressed_slot_2() -> void: _handle_select_slot(2)
func _on_selecc_p_pressed_slot_3() -> void: _handle_select_slot(3)

func _handle_select_slot(slot_num: int) -> void:
	if SaveLoad.has_save(slot_num):
		SaveLoad.load_game(slot_num)
	else:
		SaveLoad.save_game(slot_num)
	get_tree().change_scene_to_file("res://Menu Inicio.tscn")

func _on_borrar_p_pressed_slot_1() -> void: _handle_delete_slot(1)
func _on_borrar_p_pressed_slot_2() -> void: _handle_delete_slot(2)
func _on_borrar_p_pressed_slot_3() -> void: _handle_delete_slot(3)

func _handle_delete_slot(slot_num: int) -> void:
	SaveLoad.delete_slot(slot_num)
	update_all_slots_ui()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu Inicio.tscn")
