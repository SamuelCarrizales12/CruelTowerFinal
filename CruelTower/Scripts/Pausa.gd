extends Node

const SETTINGS_PATH: String = "res://Settings.tscn"
const ESCENA_MENU: String = "uid://3v2eg03buwwq" # Menu_Inicio.tscn
const FUENTE_PATH: String = "res://Recursos/Cinzel.ttf"

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
	Telemetria.evento("pause")
	
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
	_agregar_botones_salida()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _cerrar_pausa() -> void:
	print("[Pausa] Cerrando menú de pausa")
	Telemetria.evento("resume")
	get_tree().paused = false
	if capa != null:
		capa.queue_free()
		capa = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- BOTONES DE SALIDA (se muestran debajo del menú de pausa) ---

func _agregar_botones_salida() -> void:
	var fuente: Font = null
	if ResourceLoader.exists(FUENTE_PATH):
		fuente = load(FUENTE_PATH)
	
	# Contenedores que no bloquean el menú de atrás: solo los botones reciben clics
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_bottom", 36)
	capa.add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vertical := VBoxContainer.new()
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.alignment = BoxContainer.ALIGNMENT_END
	margen.add_child(vertical)
	
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fila.add_theme_constant_override("separation", 24)
	vertical.add_child(fila)
	
	var btn_guardar := _crear_boton("GUARDAR Y SALIR", Color(0.42, 0.30, 0.12), fuente)
	btn_guardar.pressed.connect(_guardar_y_salir)
	fila.add_child(btn_guardar)
	
	var btn_salir := _crear_boton("SALIR SIN GUARDAR", Color(0.5, 0.14, 0.16), fuente)
	btn_salir.pressed.connect(_salir_sin_guardar)
	fila.add_child(btn_salir)

func _guardar_y_salir() -> void:
	SaveLoad.guardar_partida_actual()
	_salir_al_menu("guardar_y_salir")

func _salir_sin_guardar() -> void:
	_salir_al_menu("salir_sin_guardar")

func _salir_al_menu(motivo: String) -> void:
	Telemetria.finalizar_run("quit", motivo)  # queda registrado en la base de datos
	_cerrar_pausa()
	get_tree().change_scene_to_file(ESCENA_MENU)

func _crear_boton(texto: String, color: Color, fuente: Font) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(250, 50)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	if fuente:
		b.add_theme_font_override("font", fuente)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color(0.45, 0.35, 0.2, 0.8)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	return b
