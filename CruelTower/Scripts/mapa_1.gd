extends Node3D

func _ready() -> void:
	# Asegura que las mallas dentro de 'Sin colisiones' tengan StaticBody3D y colisiones
	# tanto para física en tiempo de ejecución como para detección de suelo.
	var sc = find_child("Sin colisiones", true, false)
	if sc:
		_asegurar_colisiones(sc)

func _asegurar_colisiones(nodo: Node) -> void:
	if nodo is MeshInstance3D and nodo.mesh != null:
		var tiene_sb = false
		for hijo in nodo.get_children():
			if hijo is StaticBody3D:
				tiene_sb = true
				break
		if not tiene_sb:
			var sb = StaticBody3D.new()
			sb.name = "StaticBody3D"
			sb.collision_layer = 1
			var cs = CollisionShape3D.new()
			cs.name = "CollisionShape3D"
			cs.shape = nodo.mesh.create_trimesh_shape()
			sb.add_child(cs)
			nodo.add_child(sb)
	for hijo in nodo.get_children():
		_asegurar_colisiones(hijo)
