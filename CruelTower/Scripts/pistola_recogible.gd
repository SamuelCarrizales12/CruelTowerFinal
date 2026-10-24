extends StaticBody3D

func recoger(jugador: Node3D):
	jugador.tiene_pistola = true
	print("¡Pistola recogida!")
	queue_free()
