extends Control # Si el nodo raíz es Node2D, cambia 'Control' por 'Node2D'

# Referencias a los nodos hijos de botones
@onready var btn_nueva_partida = $BS
@onready var btn_continuar = $BS2
@onready var btn_configuracion = $BS3
@onready var btn_salir = $BS4

func _ready() -> void:
	# Conectamos la señal 'pressed' de cada botón a sus respectivas funciones
	btn_nueva_partida.pressed.connect(_on_nueva_partida_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_configuracion.pressed.connect(_on_configuracion_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

# 1. Botón: Nueva Partida
func _on_nueva_partida_pressed() -> void:
	print("Iniciando nueva partida...")
	# Cambia a la escena del menú de slots de guardado
	get_tree().change_scene_to_file("res://SPG.tscn")


# 2. Botón: Continuar Partida
func _on_continuar_pressed() -> void:
	print("Cargando partida guardada...")
	# Aquí colocas la lógica para cargar la partida guardada
	get_tree().change_scene_to_file("res://SPG.tscn")
# 3. Botón: Configuración
func _on_configuracion_pressed() -> void:
	print("Abriendo menú de configuración...")
	get_tree().change_scene_to_file("res://Settings.tscn")

# 4. Botón: Salir
func _on_salir_pressed() -> void:
	print("Saliendo del juego...")
	get_tree().quit() # Cierra el juego
