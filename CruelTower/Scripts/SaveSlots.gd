extends Control

# Escenas y texturas por UID
const ESCENA_MENU: String = "uid://3v2eg03buwwq"   # Menu_Inicio.tscn
const TEX_NUEVA: String = "uid://pga07rv3qio"     # Boton NP
const TEX_NUEVA_P: String = "uid://yrbxhudfa0cj"  # Boton NPP
const TEX_CONT: String = "uid://b2m635kbjsbc1"    # Boton CP
const TEX_CONT_P: String = "uid://b6fwbx2hafcv3"  # Boton CPP

@onready var slots_box: HBoxContainer = %SlotsHBox
@onready var btn_return: TextureButton = %BtnReturn

func _ready() -> void:
	btn_return.pressed.connect(_on_return_pressed)
	# Los botones no tienen señales conectadas en la escena: se conectan aquí
	for i in range(1, 4):
		var slot: Control = slots_box.get_node("Slot%d" % i)
		slot.get_node("BottomFrame/BtnAction").pressed.connect(_handle_select_slot.bind(i))
		slot.get_node("TopRightFrame/BtnDelete").pressed.connect(_handle_delete_slot.bind(i))
	update_all_slots_ui()

func update_all_slots_ui() -> void:
	for i in range(1, 4):
		_update_slot(i)

func _update_slot(slot_num: int) -> void:
	var slot: Control = slots_box.get_node("Slot%d" % slot_num)
	var status: Label = slot.get_node("TopLeftFrame/SlotStatus")
	var nivel: Label = slot.get_node("BottomFrame/InfoContainer/LevelLabel")
	var meta: Label = slot.get_node("BottomFrame/InfoContainer/MetaLabel")
	var btn: TextureButton = slot.get_node("BottomFrame/BtnAction")
	var borrar: TextureButton = slot.get_node("TopRightFrame/BtnDelete")
	
	var ocupado: bool = SaveLoad.has_save(slot_num)
	if ocupado:
		var d: Dictionary = SaveLoad.get_slot_info(slot_num)
		status.text = "OCUPADO"
		nivel.text = str(d.get("level_name", "Nivel 1"))
		meta.text = "%s | Tiempo: %s" % [d.get("save_date", "--"), d.get("play_time", "00:00")]
	else:
		status.text = "VACÍO"
		nivel.text = "Ranura disponible"
		meta.text = "Sin partida guardada"
	
	borrar.visible = ocupado
	
	# El botón cambia según el modo: Nueva Partida o Continuar Partida
	var nueva: bool = SaveLoad.es_nueva_partida
	btn.texture_normal = load(TEX_NUEVA if nueva else TEX_CONT)
	btn.texture_pressed = load(TEX_NUEVA_P if nueva else TEX_CONT_P)
	btn.disabled = (not nueva) and (not ocupado)
	btn.modulate = Color(1, 1, 1, 0.4) if btn.disabled else Color.WHITE

func _handle_select_slot(slot_num: int) -> void:
	if SaveLoad.es_nueva_partida:
		SaveLoad.new_game(slot_num)
		get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)
	else:
		if not SaveLoad.has_save(slot_num):
			return
		if SaveLoad.load_game(slot_num):
			get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)

func _handle_delete_slot(slot_num: int) -> void:
	SaveLoad.delete_slot(slot_num)
	update_all_slots_ui()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)
