extends Control

# Referencias a los nodos hijos de botones
@onready var btn_nueva_partida = $BS
@onready var btn_continuar = $BS2
@onready var btn_configuracion = $BS3
@onready var btn_salir = $BS4

func _ready() -> void:
	btn_nueva_partida.pressed.connect(_on_nueva_partida_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_configuracion.pressed.connect(_on_configuracion_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

# 1. Botón: Nueva Partida
func _on_nueva_partida_pressed() -> void:
	SaveLoad.es_nueva_partida = true
	get_tree().change_scene_to_file("res://SPG.tscn")

# 2. Botón: Continuar Partida
func _on_continuar_pressed() -> void:
	SaveLoad.es_nueva_partida = false
	get_tree().change_scene_to_file("res://SPG.tscn")

# 3. Botón: Configuración
func _on_configuracion_pressed() -> void:
	get_tree().change_scene_to_file("res://Settings.tscn")

# 4. Botón: Salir
func _on_salir_pressed() -> void:
	get_tree().quit()
