extends Node3D

@onready var enemigos: Array[Node] = [
	$EnemigoScorpion,
	$EnemigoCoat,
	$EnemigoMoth,
	$EnemigoZombie,
	$EnemigoPriestess,
	$EnemigoSpider,
	$EnemigoVoid,
	$EnemigoCorpse
]

func _ready() -> void:
	print("--- TEST ENEMIGOS INICIADO ---")
	print("Controles interactivos disponibles:")
	print("  Tecla 1 -> Reproducir 'idle'")
	print("  Tecla 2 -> Reproducir 'caminar'")
	print("  Tecla 3 -> Reproducir 'correr'")
	print("  Tecla 4 -> Reproducir 'atacar'")
	print("  Tecla 5 -> Reproducir 'morir'")
	
	# Actualizar etiquetas de todos los enemigos con su estado inicial
	_actualizar_labels("idle")
	
	# Esperar varios frames para estabilizar renderizado y animación inicial
	for i in range(35):
		await get_tree().process_frame
		
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://test_enemigos_capture.png")
		print("CAPTURE_ALL_SUCCESS")
	
	for arg in OS.get_cmdline_args():
		if arg == "--capture-and-quit":
			print("Auto-quitting after capture...")
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				_cambiar_animacion_global("idle")
			KEY_2:
				_cambiar_animacion_global("caminar")
			KEY_3:
				_cambiar_animacion_global("correr")
			KEY_4:
				_cambiar_animacion_global("atacar")
			KEY_5:
				_cambiar_animacion_global("morir")

func _cambiar_animacion_global(nombre_logico: String) -> void:
	print("\n>>> Solicitando animación global: '", nombre_logico, "' <<<")
	for e in enemigos:
		if is_instance_valid(e):
			var visual = e.get_node_or_null("Visual")
			if visual and visual.has_method("reproducir"):
				visual.reproducir(nombre_logico)
	_actualizar_labels(nombre_logico)

func _actualizar_labels(nombre_logico: String) -> void:
	for e in enemigos:
		if is_instance_valid(e):
			var label = e.get_node_or_null("Label3D") as Label3D
			var visual = e.get_node_or_null("Visual")
			if label and visual:
				var info_clip = ""
				var mapa = visual.get("mapa_animaciones")
				if mapa != null and typeof(mapa) == TYPE_DICTIONARY:
					var clip = mapa.get(nombre_logico, "")
					var respaldo_dict = visual.get("respaldo")
					if clip == "" and respaldo_dict != null and respaldo_dict.has(nombre_logico):
						var resp = respaldo_dict[nombre_logico]
						clip = mapa.get(resp, "") + " [respaldo]"
					if clip == "":
						clip = "Ninguno"
					info_clip = clip
				elif visual.has_method("reproducir"):
					info_clip = "Procedural (" + nombre_logico + ")"
				label.text = e.name.replace("Enemigo", "") + "\n" + info_clip
