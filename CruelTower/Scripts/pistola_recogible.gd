extends StaticBody3D

func recoger(jugador: Node3D):
	Telemetria.evento("weapon_pickup")
	jugador.tiene_pistola = true
	print("¡Pistola recogida!")
	queue_free()
