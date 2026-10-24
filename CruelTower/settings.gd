extends Control

# Se emite en modo pausa cuando el jugador quiere volver al juego
signal reanudar_solicitado

const CONFIG_PATH: String = "user://settings.cfg"
const ESCENA_MENU: String = "uid://3v2eg03buwwq" # Menu_Inicio.tscn

# Pausa.gd pone esto en true ANTES de agregar el menú a la escena
var es_pausa: bool = false

# La escena nueva usa nombres únicos (%)
@onready var volume_slider: HSlider = %Volume
@onready var volume_percent: Label = %VolumePercent
@onready var mute_checkbox: CheckBox = %Mute
@onready var resolutions_option: OptionButton = %Resolutions

func _ready() -> void:
	if es_pausa:
		process_mode = Node.PROCESS_MODE_ALWAYS
		# En pausa se ve el juego detrás, no el fondo de pergamino
		var fondo := get_node_or_null("BackgroundTexture")
		if fondo:
			fondo.visible = false
	_load_settings()

# ESC cierra el menú cuando está en modo pausa
func _unhandled_input(event: InputEvent) -> void:
	if es_pausa and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		reanudar_solicitado.emit()

# --- AUDIO ---

func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))
	volume_percent.text = "%d%%" % roundi(value * 100.0)
	_save_setting("audio", "volume", value)

func _on_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, toggled_on)
	_save_setting("audio", "mute", toggled_on)

# --- RESOLUCIÓN ---

func _on_resolutions_item_selected(index: int) -> void:
	match index:
		0: DisplayServer.window_set_size(Vector2i(1920, 1080))
		1: DisplayServer.window_set_size(Vector2i(1600, 900))
		2: DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(DisplayServer.screen_get_size() / 2.0 - DisplayServer.window_get_size() / 2.0)
	_save_setting("video", "resolution_index", index)

# --- GUARDAR Y CARGAR ---

func _save_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	
	var saved_volume: float = 0.8
	var saved_mute: bool = false
	var saved_res: int = 2
	if err == OK:
		saved_volume = config.get_value("audio", "volume", 0.8)
		saved_mute = config.get_value("audio", "mute", false)
		saved_res = config.get_value("video", "resolution_index", 2)
	
	volume_slider.set_value_no_signal(saved_volume)
	volume_percent.text = "%d%%" % roundi(saved_volume * 100.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(saved_volume))
	
	mute_checkbox.set_pressed_no_signal(saved_mute)
	AudioServer.set_bus_mute(0, saved_mute)
	
	resolutions_option.select(saved_res)
	# Solo cambia el tamaño de ventana si hay una resolución guardada
	if err == OK:
		_on_resolutions_item_selected(saved_res)

func _on_return_pressed() -> void:
	if es_pausa:
		reanudar_solicitado.emit()
	else:
		get_tree().change_scene_to_file(ESCENA_MENU)
