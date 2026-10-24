extends StaticBody3D


@export var cantidad_balas := 12 

func recoger(jugador: Node3D):
	Telemetria.evento("ammo_pickup", {"amount": cantidad_balas})
	jugador.municion_reserva += cantidad_balas
	print("Balas recogidas. Nueva reserva: ", jugador.municion_reserva)
	
	queue_free()
