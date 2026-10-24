class_name SettingsMenu
extends Control

## Ruta del archivo donde se guardarán los ajustes del jugador
const CONFIG_PATH: String = "user://settings.cfg"
const MAIN_MENU_SCENE_PATH: String = "res://Menu Inicio.tscn"

# Referencias a los nodos de la interfaz con soporte para unique_id y rutas anteriores
@onready var volume_slider: HSlider = %Volume if has_node("%Volume") else get_node_or_null("VBoxContainer/Volume")
@onready var volume_percent_label: Label = %VolumePercent if has_node("%VolumePercent") else null
@onready var mute_checkbox: CheckBox = %Mute if has_node("%Mute") else get_node_or_null("Mute")
@onready var resolutions_option: OptionButton = %Resolutions if has_node("%Resolutions") else get_node_or_null("VBoxContainer/Resolutions")
@onready var btn_return: TextureButton = %BtnReturn if has_node("%BtnReturn") else get_node_or_null("Return/Return")

# Diccionario de tweens activos
var _tweens: Dictionary = {}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_return_button()
	_setup_resolutions_menu()
	_load_settings()
	if is_instance_valid(volume_slider):
		_update_volume_label(volume_slider.value)

## Configura el botón de regreso con animaciones hover y pulsación suaves
func _setup_return_button() -> void:
	if not is_instance_valid(btn_return):
		return
		
	btn_return.pivot_offset = btn_return.size / 2.0
	btn_return.resized.connect(func():
		if is_instance_valid(btn_return):
			btn_return.pivot_offset = btn_return.size / 2.0
	)
	
	# Conexión directa en caso de no venir por señal de escena
	if not btn_return.pressed.is_connected(_on_return_pressed):
		btn_return.pressed.connect(_on_return_pressed)
		
	btn_return.mouse_entered.connect(_on_widget_hovered.bind(btn_return, 1.06, Color(1.15, 1.10, 1.02, 1.0)))
	btn_return.mouse_exited.connect(_on_widget_unhovered.bind(btn_return))
	btn_return.focus_entered.connect(_on_widget_hovered.bind(btn_return, 1.06, Color(1.15, 1.10, 1.02, 1.0)))
	btn_return.focus_exited.connect(_on_widget_unhovered.bind(btn_return))
	btn_return.button_down.connect(_on_widget_pressed.bind(btn_return, 0.95))
	btn_return.button_up.connect(_on_widget_hovered.bind(btn_return, 1.06, Color(1.15, 1.10, 1.02, 1.0)))

## Llena las opciones del OptionButton de Resoluciones
func _setup_resolutions_menu() -> void:
	if not is_instance_valid(resolutions_option):
		return
	resolutions_option.clear()
	resolutions_option.add_item("1920x1080 (Full HD)")
	resolutions_option.add_item("1600x900")
	resolutions_option.add_item("1280x720 (HD)")

## Actualiza la etiqueta de porcentaje de volumen
func _update_volume_label(value: float) -> void:
	if is_instance_valid(volume_percent_label):
		volume_percent_label.text = "%d%%" % int(round(value * 100.0))

# --- MANEJO DE AUDIO ---

func _on_volume_value_changed(value: float) -> void:
	# Convierte la escala lineal (0 a 1) a decibeles
	AudioServer.set_bus_volume_db(0, linear_to_db(value))
	_update_volume_label(value)
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
		if is_instance_valid(volume_slider):
			_update_volume_label(volume_slider.value)
		return
		
	# Cargar Volumen
	var saved_volume = config.get_value("audio", "volume", 0.8)
	if is_instance_valid(volume_slider):
		volume_slider.value = saved_volume
	_update_volume_label(saved_volume)
	AudioServer.set_bus_volume_db(0, linear_to_db(saved_volume))
	
	# Cargar Mute
	var saved_mute = config.get_value("audio", "mute", false)
	if is_instance_valid(mute_checkbox):
		mute_checkbox.button_pressed = saved_mute
	AudioServer.set_bus_mute(0, saved_mute)
	
	# Cargar Resolución
	var saved_res_index = config.get_value("video", "resolution_index", 2)
	if is_instance_valid(resolutions_option):
		resolutions_option.select(saved_res_index)
	_on_resolutions_item_selected(saved_res_index)

## Regreso al Menú Principal
func _on_return_pressed() -> void:
	print("Regresando al Menú Principal...")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

## Helpers de Tweens
func _on_widget_hovered(node: Control, scale_mult: float, mod_color: Color) -> void:
	if not is_instance_valid(node):
		return
	_kill_tween(node)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(scale_mult, scale_mult), 0.18)
	tween.tween_property(node, "modulate", mod_color, 0.18)
	_tweens[node] = tween

func _on_widget_unhovered(node: Control) -> void:
	if not is_instance_valid(node):
		return
	_kill_tween(node)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.2)
	tween.tween_property(node, "modulate", Color.WHITE, 0.2)
	_tweens[node] = tween

func _on_widget_pressed(node: Control, scale_mult: float) -> void:
	if not is_instance_valid(node):
		return
	_kill_tween(node)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(scale_mult, scale_mult), 0.08)
	_tweens[node] = tween

func _kill_tween(node: Control) -> void:
	if _tweens.has(node) and is_instance_valid(_tweens[node]):
		_tweens[node].kill()
	_tweens.erase(node)
