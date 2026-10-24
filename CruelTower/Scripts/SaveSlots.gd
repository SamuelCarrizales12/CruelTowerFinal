extends Control

# Escenas y texturas por UID
const ESCENA_MENU: String = "uid://3v2eg03buwwq"   # Menu_Inicio.tscn
const TEX_NUEVA: String = "uid://pga07rv3qio"     # Boton NP
const TEX_NUEVA_P: String = "uid://yrbxhudfa0cj"  # Boton NPP
const TEX_CONT: String = "uid://b2m635kbjsbc1"    # Boton CP
const TEX_CONT_P: String = "uid://b6fwbx2hafcv3"  # Boton CPP

@onready var slots_box: HBoxContainer = %SlotsHBox

# Ventana para escribir el nombre (ver NombreJugador.gd)
var _dialogo: DialogoNombre = null
var _confirmacion: DialogoConfirmar = null
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
		var nombre_guardado: String = str(d.get("player_name", ""))
		status.text = nombre_guardado.to_upper() if nombre_guardado != "" else "OCUPADO"
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
	if _dialogo != null or _confirmacion != null:
		return
	if SaveLoad.es_nueva_partida:
		# Nueva partida: primero pedimos el nombre
		_pedir_nombre(slot_num, _iniciar_nueva_partida.bind(slot_num))
	else:
		if not SaveLoad.has_save(slot_num):
			return
		if not SaveLoad.load_game(slot_num):
			return
		if SaveLoad.nombre_jugador() == "":
			# Partida guardada antes de existir esta pantalla: se pide el nombre una vez
			_pedir_nombre(slot_num, _nombrar_y_continuar.bind(slot_num))
		else:
			get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)

func _pedir_nombre(slot_num: int, al_confirmar: Callable) -> void:
	_dialogo = DialogoNombre.new()
	_dialogo.slot_num = slot_num
	_dialogo.confirmado.connect(al_confirmar)
	_dialogo.tree_exited.connect(func(): _dialogo = null)
	add_child(_dialogo)

# La señal "confirmado" entrega el nombre primero; bind() agrega la ranura después
func _iniciar_nueva_partida(nombre: String, slot_num: int) -> void:
	SaveLoad.new_game(slot_num, nombre)
	get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)

func _nombrar_y_continuar(nombre: String, slot_num: int) -> void:
	SaveLoad.asignar_nombre(nombre, slot_num)
	get_tree().change_scene_to_file(SaveLoad.ESCENA_JUEGO)

func _handle_delete_slot(slot_num: int) -> void:
	if _dialogo != null or _confirmacion != null:
		return
	var detalle: String = "la Ranura %d" % slot_num
	var nombre: String = str(SaveLoad.get_slot_info(slot_num).get("player_name", ""))
	if nombre != "":
		detalle += " (%s)" % nombre
	_confirmacion = DialogoConfirmar.new()
	_confirmacion.titulo = "¿BORRAR PARTIDA?"
	_confirmacion.mensaje = "¿Seguro que quieres borrar %s?\nEsta acción no se puede deshacer." % detalle
	_confirmacion.texto_confirmar = "BORRAR"
	_confirmacion.confirmado.connect(_borrar_confirmado.bind(slot_num))
	_confirmacion.tree_exited.connect(func(): _confirmacion = null)
	add_child(_confirmacion)

func _borrar_confirmado(slot_num: int) -> void:
	SaveLoad.delete_slot(slot_num)
	update_all_slots_ui()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)
