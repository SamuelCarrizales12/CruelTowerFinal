extends Control

# Se emite en modo pausa cuando el jugador quiere volver al juego
signal reanudar_solicitado

# Ruta del archivo donde se guardarán los ajustes del jugador
const CONFIG_PATH: String = "user://settings.cfg"

# El juego pone esto en true ANTES de agregar el menú a la escena
var es_pausa: bool = false

# Referencias a los nodos de tu escena
@onready var volume_slider: HSlider = $VBoxContainer/Volume
@onready var mute_checkbox: CheckBox = $Mute
@onready var resolutions_option: OptionButton = $VBoxContainer/Resolutions

func _ready() -> void:
	if es_pausa:
		# Que el menú siga funcionando aunque el juego esté en pausa
		process_mode = Node.PROCESS_MODE_ALWAYS
	
	# El slider por defecto va de 0 a 100, pero el código espera de 0 a 1
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	
	_setup_resolutions_menu()
	_load_settings()

# Con ESC se cierra el menú cuando está en modo pausa
func _unhandled_input(event: InputEvent) -> void:
	if es_pausa and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		reanudar_solicitado.emit()

# Llena las opciones del OptionButton de Resoluciones
func _setup_resolutions_menu() -> void:
	resolutions_option.clear()
	resolutions_option.add_item("1920x1080 (Full HD)")
	resolutions_option.add_item("1600x900")
	resolutions_option.add_item("1280x720 (HD)")
	resolutions_option.select(2) # 1280x720 por defecto

# --- MANEJO DE AUDIO ---

func _on_volume_value_changed(value: float) -> void:
	# Convierte la escala lineal (0 a 1) a decibeles
	AudioServer.set_bus_volume_db(0, linear_to_db(value))
	_save_setting("audio", "volume", value)

func _on_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, toggled_on)
	_save_setting("audio", "mute", toggled_on)

# --- MANEJO DE RESOLUCIÓN ---

func _on_resolutions_item_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_size(Vector2i(1920, 1080))
		1:
			DisplayServer.window_set_size(Vector2i(1600, 900))
		2:
			DisplayServer.window_set_size(Vector2i(1280, 720))
			
	# Centra la ventana en el monitor si no está en pantalla completa
	DisplayServer.window_set_position(DisplayServer.screen_get_size() / 2.0 - DisplayServer.window_get_size() / 2.0)
	_save_setting("video", "resolution_index", index)

# --- GUARDAR Y CARGAR CONFIGURACIÓN ---

func _save_setting(section: String, key: String, value: Variant) -> void:
	var config = ConfigFile.new()
	# Cargamos los datos existentes para no sobrescribir otras secciones
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK:
		print("No hay configuración guardada previa. Usando valores por defecto.")
		volume_slider.set_value_no_signal(0.8)
		AudioServer.set_bus_volume_db(0, linear_to_db(0.8))
		return
		
	# Cargar Volumen
	var saved_volume = config.get_value("audio", "volume", 0.8)
	volume_slider.set_value_no_signal(saved_volume)
	AudioServer.set_bus_volume_db(0, linear_to_db(saved_volume))
	
	# Cargar Mute
	var saved_mute = config.get_value("audio", "mute", false)
	mute_checkbox.set_pressed_no_signal(saved_mute)
	AudioServer.set_bus_mute(0, saved_mute)
	
	# Cargar Resolución
	var saved_res_index = config.get_value("video", "resolution_index", 2)
	resolutions_option.select(saved_res_index)
	_on_resolutions_item_selected(saved_res_index)

func _on_return_pressed() -> void:
	if es_pausa:
		# Dentro del juego: volver a la partida
		reanudar_solicitado.emit()
	else:
		# Desde el menú principal
		get_tree().change_scene_to_file("res://Menu Inicio.tscn")
