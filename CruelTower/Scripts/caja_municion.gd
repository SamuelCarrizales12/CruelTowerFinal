extends StaticBody3D


@export var cantidad_balas := 12 

func recoger(jugador: Node3D):
	jugador.municion_reserva += cantidad_balas
	print("Balas recogidas. Nueva reserva: ", jugador.municion_reserva)
	
	queue_free()
