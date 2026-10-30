extends Node3D

## Controlador de la escena de prueba res://Escenas/test_trepar.tscn
## Teclas:
##   T = La araña va hasta la pared trepable, sube, cruza al techo y avanza hacia el marcador.
##   G = La araña termina de trepar y baja al suelo por la pared (pasando por esquina convexa).
##   Y = Alterna dibujar los raycasts y la normal actual.
##   B = Camina hacia la pared NO trepable para comprobar que la bloquea normalmente.
##   R = Reinicia posición en el suelo.

enum MarchaSuelo {
	NINGUNA,
	HACIA_PARED_TREPABLE,
	HACIA_PARED_NO_TREPABLE
}

@onready var spider: CharacterBody3D = $EnemigoSpider
@onready var marcador: Node3D = $Marcador
@onready var pared_trepable: StaticBody3D = $ParedTrepable
@onready var pared_no_trepable: StaticBody3D = $ParedNoTrepable
@onready var label_debug_3d: Label3D = $LabelDebugSpider
@onready var label_hud: Label = $CanvasLayer/PanelHUD/LabelHUD

var mov_sup: MovimientoSuperficie = null
var mov_nav: Node = null
var visual_spider: Node3D = null
var animador_spider: Node = null

var marcha_suelo: MarchaSuelo = MarchaSuelo.NINGUNA
var ultima_senal: String = "ninguna"
var estado_accion: String = "En espera en el suelo"
var _tiempo_bloqueo_pared: float = 0.0


func _ready() -> void:
	if spider:
		mov_sup = spider.get_node_or_null("MovimientoSuperficie") as MovimientoSuperficie
		mov_nav = spider.get_node_or_null("MovimientoNav")
		visual_spider = spider.get_node_or_null("Visual") as Node3D
		if visual_spider and visual_spider.has_method("reproducir"):
			animador_spider = visual_spider

	if mov_sup:
		mov_sup.pausar_padre = true
		mov_sup.subio_a_pared.connect(func():
			ultima_senal = "subio_a_pared"
		)
		mov_sup.llego_al_techo.connect(func():
			ultima_senal = "llego_al_techo"
		)
		mov_sup.volvio_al_suelo.connect(func():
			ultima_senal = "volvio_al_suelo"
			estado_accion = "De vuelta en el suelo (gravedad normal)"
		)
		mov_sup.destino_superficie_alcanzado.connect(func():
			if mov_sup.trepando:
				estado_accion = "En el marcador del techo (bocabajo)"
		)

	_actualizar_textos()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	match event.keycode:
		KEY_T:
			iniciar_secuencia_subir_al_marcador()
		KEY_G:
			iniciar_secuencia_bajar_al_suelo()
		KEY_Y:
			alternar_visualizacion_raycasts()
		KEY_B:
			iniciar_prueba_pared_no_trepable()
		KEY_R:
			reiniciar_arana()


func iniciar_secuencia_subir_al_marcador() -> void:
	if not spider or not mov_sup:
		return

	if mov_sup.trepando:
		estado_accion = "Avanzando por superficie hacia el marcador"
		mov_sup.ir_a_superficie(marcador.global_position)
		return

	# Si está en el suelo, caminar hacia la pared trepable (-X)
	estado_accion = "Yendo hacia pared trepable..."
	_activar_marcha_suelo(MarchaSuelo.HACIA_PARED_TREPABLE)


func iniciar_secuencia_bajar_al_suelo() -> void:
	if not spider or not mov_sup:
		return

	marcha_suelo = MarchaSuelo.NINGUNA
	if not mov_sup.trepando:
		estado_accion = "Ya se encuentra en el suelo"
		return

	estado_accion = "Bajando al suelo por la pared..."
	var n: Vector3 = mov_sup.normal_superficie

	if n.y < -0.5:
		# Está bocabajo en el techo: avanza al borde convexo derecho, rodea hacia arriba,
		# cruza a la esquina convexa techo->pared exterior y desciende hasta el suelo.
		var ruta_bajada: Array[Vector3] = [
			Vector3(1.40, 4.75, 0.0),
			Vector3(0.60, 5.20, 0.0),
			Vector3(-4.20, 4.30, 0.0),
			Vector3(-4.20, 0.05, 0.0)
		]
		mov_sup.seguir_ruta_superficie(ruta_bajada, true)
	elif n.y > 0.5:
		# Está sobre la cara superior del techo: va a la esquina convexa y baja por la pared
		var ruta_desde_arriba: Array[Vector3] = [
			Vector3(-4.20, 4.30, 0.0),
			Vector3(-4.20, 0.05, 0.0)
		]
		mov_sup.seguir_ruta_superficie(ruta_desde_arriba, true)
	else:
		# Ya está en una pared vertical: baja directamente al suelo
		mov_sup.seguir_ruta_superficie([Vector3(spider.global_position.x, 0.05, spider.global_position.z)], true)


func alternar_visualizacion_raycasts() -> bool:
	if not mov_sup:
		return false
	return mov_sup.alternar_debug_rayos()


func iniciar_prueba_pared_no_trepable() -> void:
	if not spider or not mov_sup:
		return
	if mov_sup.trepando:
		mov_sup.terminar_trepar()
	_tiempo_bloqueo_pared = 0.0
	estado_accion = "Caminando hacia pared NO trepable (+X)..."
	_activar_marcha_suelo(MarchaSuelo.HACIA_PARED_NO_TREPABLE)


func reiniciar_arana() -> void:
	if not spider or not mov_sup:
		return
	marcha_suelo = MarchaSuelo.NINGUNA
	if mov_sup.trepando:
		mov_sup.terminar_trepar()
	spider.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	spider.up_direction = Vector3.UP
	spider.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.5, 0.02, 0.0))
	spider.velocity = Vector3.ZERO
	if visual_spider:
		visual_spider.position = Vector3.ZERO
		visual_spider.scale = Vector3(0.075, 0.075, 0.075)
		visual_spider.rotation = Vector3(0.0, PI, 0.0)
	if mov_nav:
		mov_nav.set_physics_process(true)
	spider.set_physics_process(true)
	estado_accion = "Reiniciada en el suelo"
	ultima_senal = "ninguna"


func _activar_marcha_suelo(modo: MarchaSuelo) -> void:
	marcha_suelo = modo
	# Pausar temporalmente IA y Nav mientras este controlador dirige la caminata de prueba en suelo
	if mov_nav:
		if mov_nav.has_method("detener"):
			mov_nav.detener()
		mov_nav.set_physics_process(false)
	spider.set_physics_process(false)


func _restaurar_ia_suelo() -> void:
	marcha_suelo = MarchaSuelo.NINGUNA
	if mov_nav:
		mov_nav.set_physics_process(true)
	spider.set_physics_process(true)


func _physics_process(delta: float) -> void:
	if spider and marcha_suelo != MarchaSuelo.NINGUNA:
		_procesar_marcha_suelo(delta)

	_actualizar_textos()


func _procesar_marcha_suelo(delta: float) -> void:
	var dir_x: float = -1.0 if marcha_suelo == MarchaSuelo.HACIA_PARED_TREPABLE else 1.0
	var dir_mov := Vector3(dir_x, 0.0, 0.0)

	if not spider.is_on_floor():
		spider.velocity += spider.get_gravity() * delta
	else:
		if spider.velocity.y < 0.0:
			spider.velocity.y = 0.0

	spider.velocity.x = dir_mov.x * mov_sup.velocidad_trepar
	spider.velocity.z = 0.0

	# Orientar Visual suavemente hacia la dirección de avance (-Z de Godot + PI del modelo Spider)
	if visual_spider:
		var angulo_obj: float = atan2(-dir_mov.x, -dir_mov.z) + PI
		visual_spider.rotation.y = lerp_angle(visual_spider.rotation.y, angulo_obj, 10.0 * delta)

	if animador_spider and animador_spider.get("animacion_actual") != "caminar":
		animador_spider.reproducir("caminar", clampf(mov_sup.velocidad_trepar / 1.5, 0.8, 1.8))

	spider.move_and_slide()

	# Raycast horizontal desde el centro de la araña para detectar pared frente a ella
	var centro: Vector3 = spider.global_position + Vector3(0.0, mov_sup.radio_cuerpo, 0.0)
	var fin_rayo: Vector3 = centro + dir_mov * (mov_sup.radio_cuerpo + 0.18)
	var query := PhysicsRayQueryParameters3D.create(centro, fin_rayo, 1)
	query.exclude = [spider.get_rid()]
	var hit: Dictionary = spider.get_world_3d().direct_space_state.intersect_ray(query)

	if marcha_suelo == MarchaSuelo.HACIA_PARED_TREPABLE:
		# Si alcanzó el lado exterior o interior de ParedTrepable, comenzar a trepar
		if not hit.is_empty():
			var col: Node = hit["collider"] as Node
			if col and col.is_in_group("trepable"):
				# Restaurar banderas base justo antes de iniciar_trepar para que al terminar las reactive
				_restaurar_ia_suelo()
				estado_accion = "Trepando pared hacia el techo y marcador..."
				mov_sup.iniciar_trepar(hit["normal"])
				mov_sup.ir_a_superficie(marcador.global_position)
				return
		# Si está a la izquierda de la pared exterior (ej. tras bajar por fuera en x < -4.2), caminar hacia +X
		if spider.global_position.x < -4.2:
			spider.velocity.x = +mov_sup.velocidad_trepar
			if visual_spider:
				visual_spider.rotation.y = lerp_angle(visual_spider.rotation.y, atan2(-1.0, 0.0) + PI, 10.0 * delta)
			spider.move_and_slide()
			var fin_der: Vector3 = centro + Vector3(mov_sup.radio_cuerpo + 0.18, 0.0, 0.0)
			var q_der := PhysicsRayQueryParameters3D.create(centro, fin_der, 1)
			q_der.exclude = [spider.get_rid()]
			var hit_der: Dictionary = spider.get_world_3d().direct_space_state.intersect_ray(q_der)
			if not hit_der.is_empty() and (hit_der["collider"] as Node).is_in_group("trepable"):
				_restaurar_ia_suelo()
				estado_accion = "Trepando pared exterior hacia el marcador..."
				mov_sup.iniciar_trepar(hit_der["normal"])
				var ruta_ext: Array[Vector3] = [
					Vector3(-3.30, 5.20, 0.0),
					Vector3(1.40, 4.65, 0.0),
					Vector3(0.85, 4.20, 0.0),
					marcador.global_position
				]
				mov_sup.seguir_ruta_superficie(ruta_ext, false)

	elif marcha_suelo == MarchaSuelo.HACIA_PARED_NO_TREPABLE:
		if spider.is_on_wall() or not hit.is_empty():
			_tiempo_bloqueo_pared += delta
			estado_accion = "Bloqueada por pared NO trepable (no sube)"
			if _tiempo_bloqueo_pared >= 1.2:
				_restaurar_ia_suelo()
				if animador_spider:
					animador_spider.reproducir("idle", 1.0)


func _actualizar_textos() -> void:
	if not spider or not mov_sup:
		return

	var modo_txt: String = mov_sup.obtener_modo_texto()
	var n: Vector3 = mov_sup.normal_superficie if mov_sup.trepando else Vector3.UP
	var normal_txt: String = "(%.2f, %.2f, %.2f)" % [n.x, n.y, n.z]

	if label_debug_3d:
		# Colocar el Label3D cerca de la araña hacia la cámara (+Z) para que nunca quede tapado
		var offset_label: Vector3 = n * 1.15 + Vector3(0.0, 0.25, 0.9)
		if n.y < -0.5:
			offset_label = Vector3(0.0, -1.25, 0.9)
		label_debug_3d.global_position = spider.global_position + offset_label
		label_debug_3d.text = "Modo: %s\nNormal: %s" % [modo_txt, normal_txt]

		match modo_txt:
			"SUELO":
				label_debug_3d.modulate = Color(0.55, 1.0, 0.65)
			"PARED":
				label_debug_3d.modulate = Color(1.0, 0.85, 0.35)
			"TECHO", "TECHO (SUP.)":
				label_debug_3d.modulate = Color(0.45, 0.9, 1.0)

	if label_hud:
		var rayos_txt: String = "ACTIVO" if mov_sup.dibujar_debug else "INACTIVO"
		var fps: int = Engine.get_frames_per_second()
		label_hud.text = (
			"=== TEST TREPAR SPIDER ===   [FPS: %d]\n" % fps +
			"Modo actual : %s   |   Normal: %s\n" % [modo_txt, normal_txt] +
			"Última señal: %s   |   Raycasts (Y): %s\n" % [ultima_senal, rayos_txt] +
			"Estado      : %s\n" % estado_accion +
			"----------------------------------------------------------\n" +
			"[T] Ir a pared trepable -> subir -> techo -> marcador\n" +
			"[G] Terminar y bajar al suelo por la pared (esq. convexa)\n" +
			"[Y] Alternar dibujo de raycasts y normal\n" +
			"[B] Probar choque con pared NO trepable   |   [R] Reiniciar"
		)
