extends Node3D

const EnemigoIAScript = preload("res://Scripts/enemigo_ia.gd")

@onready var jugador: CharacterBody3D = $Jugador
@onready var escorpion: CharacterBody3D = $EnemigoScorpion
@onready var arana: CharacterBody3D = $EnemigoSpider
@onready var camara_cenital: Camera3D = $CamaraCenital

@onready var lbl_fps: Label = $UI/Panel/Margin/VBox/LblFPS
@onready var lbl_escorpion: Label = $UI/Panel/Margin/VBox/LblEscorpion
@onready var lbl_arana: Label = $UI/Panel/Margin/VBox/LblArana
@onready var lbl_evento: Label = $UI/Panel/Margin/VBox/LblEvento
@onready var lbl_camara: Label = $UI/Panel/Margin/VBox/LblCamara

var camara_cenital_activa: bool = true
var ultimo_evento: String = "Simulación iniciada"
var modo_inmune_activo: bool = false


func _ready() -> void:
	# Activar debug de navegación para ver la malla
	NavigationServer3D.set_debug_enabled(true)
	
	# Conectar señales de escorpión
	if escorpion:
		escorpion.estado_cambiado.connect(func(ant, nvo):
			ultimo_evento = "Escorpión cambió: %s -> %s" % [_nombre_estado(ant, escorpion), _nombre_estado(nvo, escorpion)]
		)
		escorpion.jugador_alcanzado.connect(func():
			ultimo_evento = "¡Escorpión impactó o alcanzó al jugador!"
		)
		
	# Conectar señales de araña
	if arana:
		arana.estado_cambiado.connect(func(ant, nvo):
			ultimo_evento = "Araña cambió: %s -> %s" % [_nombre_estado(ant, arana), _nombre_estado(nvo, arana)]
		)
		arana.jugador_alcanzado.connect(func():
			ultimo_evento = "¡Araña impactó o alcanzó al jugador!"
		)

	_actualizar_camaras()


func _process(_delta: float) -> void:
	_actualizar_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				camara_cenital_activa = not camara_cenital_activa
				_actualizar_camaras()
			KEY_1:
				# Jugador detrás de la pared (oculto de ambos)
				jugador.global_position = Vector3(2.5, 0.5, 2.0)
				ultimo_evento = "Jugador detrás de pared (oculto)"
			KEY_2:
				# Jugador en el cono de visión del escorpión
				jugador.global_position = Vector3(-10.0, 0.5, 0.0)
				ultimo_evento = "Jugador en cono de visión del escorpión"
			KEY_3:
				# Disparo lejano / ruido fuerte (radio 20 m)
				var ev = get_node_or_null("/root/EventosSonido")
				if ev:
					ev.emitir_ruido(jugador.global_position, 20.0)
				ultimo_evento = "Ruido emitido (disparo: 20 m)"
			KEY_4:
				# Jugador escapa lejos (fuerza BÚSQUEDA y regreso a PATRULLA)
				jugador.global_position = Vector3(10.0, 0.5, 8.0)
				ultimo_evento = "Jugador escapó lejos (Búsqueda -> Patrulla)"
			KEY_5:
				# Aturdir al escorpión
				escorpion.aturdir(2.5)
				ultimo_evento = "Escorpión aturdido por 2.5 s"
			KEY_6:
				# Matar a la araña
				arana.morir()
				ultimo_evento = "Araña eliminada (MUERTO)"
			KEY_J:
				# Alternar modo inmune para pruebas
				modo_inmune_activo = not modo_inmune_activo
				if escorpion:
					escorpion.modo_inmune = modo_inmune_activo
				if arana:
					arana.modo_inmune = modo_inmune_activo
				ultimo_evento = "Modo Inmune: %s" % ("ACTIVADO (sin daño)" if modo_inmune_activo else "DESACTIVADO")
			KEY_K:
				# Forzar estado de ATAQUE en el enemigo más cercano
				var d_scorp = escorpion.global_position.distance_to(jugador.global_position) if escorpion else 999.0
				var d_spider = arana.global_position.distance_to(jugador.global_position) if arana else 999.0
				var cercano = escorpion if d_scorp < d_spider else arana
				if cercano and cercano.estado_actual != EnemigoIAScript.Estado.MUERTO:
					cercano._posicion_sospecha = jugador.global_position
					cercano.cambiar_estado(EnemigoIAScript.Estado.ATAQUE)
					ultimo_evento = "Ataque forzado en: %s" % cercano.name


func _actualizar_camaras() -> void:
	camara_cenital.current = camara_cenital_activa
	if camara_cenital_activa:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _actualizar_ui() -> void:
	if not lbl_fps:
		return
	
	lbl_fps.text = "FPS: %d  |  Modo Inmune [J]: %s" % [Engine.get_frames_per_second(), "ACTIVO" if modo_inmune_activo else "INACTIVO"]
	
	if escorpion and jugador:
		var d = escorpion.global_position.distance_to(jugador.global_position)
		lbl_escorpion.text = "Escorpión: %s  (Dist: %.1f m)" % [_nombre_estado(escorpion.estado_actual, escorpion), d]
		
	if arana and jugador:
		var d = arana.global_position.distance_to(jugador.global_position)
		lbl_arana.text = "Araña:     %s  (Dist: %.1f m)" % [_nombre_estado(arana.estado_actual, arana), d]
		
	lbl_evento.text = "Evento: %s" % ultimo_evento
	lbl_camara.text = "Cámara: %s ([V] para alternar)" % ("Cenital" if camara_cenital_activa else "Primera Persona")


func _nombre_estado(st: int, enemigo: CharacterBody3D = null) -> String:
	match st:
		EnemigoIAScript.Estado.PATRULLA: return "PATRULLA"
		EnemigoIAScript.Estado.SOSPECHA: return "SOSPECHA"
		EnemigoIAScript.Estado.PERSECUCION: return "PERSECUCIÓN"
		EnemigoIAScript.Estado.BUSQUEDA: return "BÚSQUEDA"
		EnemigoIAScript.Estado.ATURDIDO: return "ATURDIDO"
		EnemigoIAScript.Estado.MUERTO: return "MUERTO"
		EnemigoIAScript.Estado.ATAQUE:
			if enemigo:
				match enemigo.fase_ataque:
					enemigo.FaseAtaque.PREPARACION: return "ATAQUE: PREPARACIÓN"
					enemigo.FaseAtaque.GOLPE: return "ATAQUE: GOLPE"
					enemigo.FaseAtaque.RECUPERACION: return "ATAQUE: RECUPERACIÓN"
			return "ATAQUE"
	return "DESCONOCIDO"
