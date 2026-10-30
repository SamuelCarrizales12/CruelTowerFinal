class_name PuntoTrepar
extends Marker3D

## Punto de transición entre navegación terrestre y movimiento en superficie (pared/techo).
## Guarda la normal de la superficie a la que da acceso y si permite subir o bajar.

@export var normal_superficie: Vector3 = Vector3.UP
@export var es_entrada_suelo: bool = true   ## Permite a la araña subir a la superficie desde el suelo
@export var es_salida_suelo: bool = true    ## Permite a la araña bajar al suelo desde la superficie
@export var id_zona: String = ""            ## Opcional para filtrar por zona
@export var puntos_conectados: Array[NodePath] = [] ## Puntos de enlace recomendados en la superficie


func _ready() -> void:
	add_to_group("punto_trepar")
