extends StaticBody3D

@export var nombre_objeto := "Botiquin"

func recoger(jugador: Node3D):
	jugador.coleccionables_obtenidos.append(nombre_objeto)
	print("Recogiste: ", nombre_objeto)
	
	queue_free()
