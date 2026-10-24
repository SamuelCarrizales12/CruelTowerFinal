extends Node

const SETTINGS_PATH: String = "res://Settings.tscn"

var capa: CanvasLayer = null

func _ready() -> void:
	# Que este nodo siga recibiendo teclas aunque el juego esté en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if capa != null:
		return
	if not _estamos_en_el_juego():
		return
	
	get_viewport().set_input_as_handled()
	_abrir_pausa()

# Solo se activa dentro de la escena del juego, no en los menús
func _estamos_en_el_juego() -> bool:
	var escena = get_tree().current_scene
	if escena == null or escena.scene_file_path == "":
		return false
	var uid_actual: int = ResourceLoader.get_resource_uid(escena.scene_file_path)
	var uid_juego: int = ResourceUID.text_to_id(SaveLoad.ESCENA_JUEGO)
	return uid_actual == uid_juego

func _abrir_pausa() -> void:
	print("[Pausa] Abriendo menú de pausa")
	
	capa = CanvasLayer.new()
	capa.layer = 100
	add_child(capa)
	
	# Fondo oscuro
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	capa.add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Menú de configuración en modo pausa
	var menu = load(SETTINGS_PATH).instantiate()
	menu.es_pausa = true
	menu.reanudar_solicitado.connect(_cerrar_pausa)
	capa.add_child(menu)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _cerrar_pausa() -> void:
	print("[Pausa] Cerrando menú de pausa")
	get_tree().paused = false
	if capa != null:
		capa.queue_free()
		capa = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
