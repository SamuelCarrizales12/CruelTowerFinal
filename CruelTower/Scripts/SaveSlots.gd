extends Control

@onready var label_slot_1: Label = get_node_or_null("HBoxContainer/Slot1/Ssc/Label")
@onready var label_slot_2: Label = get_node_or_null("HBoxContainer/Slot2/Ssc2/Label2")
@onready var label_slot_3: Label = get_node_or_null("HBoxContainer/Slot3/Ssc3/Label3")

@onready var btn_borrar_1: TextureButton = get_node_or_null("HBoxContainer/Slot1/Ssc/BorrarP")
@onready var btn_borrar_2: TextureButton = get_node_or_null("HBoxContainer/Slot2/Ssc2/BorrarP2")
@onready var btn_borrar_3: TextureButton = get_node_or_null("HBoxContainer/Slot3/Ssc3/BorrarP3")

func _ready() -> void:
	# Los botones de borrar no estaban conectados en la escena
	if btn_borrar_1: btn_borrar_1.pressed.connect(_on_borrar_p_pressed_slot_1)
	if btn_borrar_2: btn_borrar_2.pressed.connect(_on_borrar_p_pressed_slot_2)
	if btn_borrar_3: btn_borrar_3.pressed.connect(_on_borrar_p_pressed_slot_3)
	update_all_slots_ui()

func update_all_slots_ui() -> void:
	_update_slot_label(1, label_slot_1)
	_update_slot_label(2, label_slot_2)
	_update_slot_label(3, label_slot_3)

func _update_slot_label(slot_num: int, label_node: Label) -> void:
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
	if SaveLoad.es_nueva_partida:
		# Nueva partida: reinicia datos, crea el guardado y entra al juego
		SaveLoad.new_game(slot_num)
		get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)
	else:
		# Continuar: solo si el slot tiene una partida guardada
		if not SaveLoad.has_save(slot_num):
			return
		if SaveLoad.load_game(slot_num):
			get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)

func _on_borrar_p_pressed_slot_1() -> void: _handle_delete_slot(1)
func _on_borrar_p_pressed_slot_2() -> void: _handle_delete_slot(2)
func _on_borrar_p_pressed_slot_3() -> void: _handle_delete_slot(3)

func _handle_delete_slot(slot_num: int) -> void:
	SaveLoad.delete_slot(slot_num)
	update_all_slots_ui()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu Inicio.tscn")
