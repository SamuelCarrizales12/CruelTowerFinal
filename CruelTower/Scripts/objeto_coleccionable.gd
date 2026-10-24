extends StaticBody3D

@export var nombre_objeto: String = "Objeto Misterioso"
@export var imagen_objeto: Texture2D

@onready var sprite = $Sprite3D

func _ready():
	if imagen_objeto != null:
		sprite.texture = imagen_objeto

func recoger(jugador: Node3D):
	Telemetria.evento("collectible", {"name": nombre_objeto})
	jugador.coleccionables_obtenidos.append(nombre_objeto)
	
	print("¡Has encontrado: ", nombre_objeto, "!")
	print("Tu mochila ahora tiene: ", jugador.coleccionables_obtenidos)
	
	queue_free()
