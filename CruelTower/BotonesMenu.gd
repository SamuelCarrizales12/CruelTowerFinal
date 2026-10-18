extends Control # Cambia a Node2D si tu nodo padre "Botones" es de tipo Node2D

@onready var btn_nueva_partida = $BS
@onready var btn_continuar = $BS2
@onready var btn_configuracion = $BS3
@onready var btn_salir = $BS4

func _ready() -> void:
	# Conectamos la señal pressed de cada TextureButton
	btn_nueva_partida.pressed.connect(_on_nueva_partida_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_configuracion.pressed.connect(_on_configuracion_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

func _on_nueva_partida_pressed() -> void:
	print("Nueva Partida presionada")
	# get_tree().change_scene_to_file("res://Nivel1.tscn")

func _on_continuar_pressed() -> void:
	print("Continuar Partida presionada")

func _on_configuracion_pressed() -> void:
	print("Configuración presionada")

func _on_salir_pressed() -> void:
	print("Saliendo del juego...")
	get_tree().quit()
