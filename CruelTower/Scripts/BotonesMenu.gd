extends Control

# El menú nuevo usa nombres únicos (%) en vez de BS, BS2, BS3, BS4
@onready var btn_nueva_partida: TextureButton = %BtnNuevaPartida
@onready var btn_continuar: TextureButton = %BtnContinuar
@onready var btn_configuracion: TextureButton = %BtnConfiguracion
@onready var btn_salir: TextureButton = %BtnSalir

# Escenas por UID: siguen funcionando aunque muevas los archivos de carpeta
const ESCENA_SLOTS: String = "uid://bwl233hilqxww"    # SPG.tscn
const ESCENA_AJUSTES: String = "uid://csmla3jyvng5r"  # Settings.tscn

func _ready() -> void:
	btn_nueva_partida.pressed.connect(_on_nueva_partida_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_configuracion.pressed.connect(_on_configuracion_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

func _on_nueva_partida_pressed() -> void:
	SaveLoad.es_nueva_partida = true
	get_tree().change_scene_to_file(ESCENA_SLOTS)

func _on_continuar_pressed() -> void:
	SaveLoad.es_nueva_partida = false
	get_tree().change_scene_to_file(ESCENA_SLOTS)

func _on_configuracion_pressed() -> void:
	get_tree().change_scene_to_file(ESCENA_AJUSTES)

func _on_salir_pressed() -> void:
	Telemetria.salir_del_juego()
