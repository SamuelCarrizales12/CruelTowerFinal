class_name EnemigoIA
extends CharacterBody3D

## Máquina de estados reutilizable para enemigos con visión, oído, persecución,
## búsqueda, ataque, alerta de grupo y locomoción en paredes/techos (Spider).
## Utiliza MovimientoNav en el suelo y MovimientoSuperficie en paredes/techos.

signal estado_cambiado(anterior: Estado, nuevo: Estado)
signal jugador_alcanzado
signal sin_camino

enum Estado {
	PATRULLA,
	SOSPECHA,
	PERSECUCION,
	BUSQUEDA,
	ATURDIDO,
	MUERTO,
	ATAQUE,
	TREPANDO,
	EMBOSCADA
}

enum FaseAtaque {
	NINGUNA,
	PREPARACION,
	GOLPE,
	RECUPERACION
}

enum SubfaseTrepar {
	NINGUNA,
	SUBIENDO,
	EN_SUPERFICIE,
	BAJANDO
}

# --- PARÁMETROS EXPORTADOS ---
@export_group("Velocidades")
@export var vel_patrulla: float = 1.8
@export var vel_persecucion: float = 3.2
@export var vel_busqueda: float = 2.0

@export_group("Percepción")
@export var rango_vision: float = 12.0
@export var angulo_vision: float = 90.0  # Cono de visión en grados
@export var rango_oido: float = 8.0
@export var altura_ojos: float = 0.8
@export var mascara_vision: int = 3  # Capa 1 (Paredes/Entorno) + Capa 2 (Jugador)

@export_group("Tiempos")
@export var tiempo_sospecha: float = 1.5
@export var tiempo_busqueda: float = 8.0
@export var tiempo_espera_patrulla: float = 2.0

@export_group("Contacto y Grupo")
@export var distancia_contacto: float = 1.5
@export var grupo_alerta: String = "manada_1"

@export_group("Salud")
@export var vida_maxima: float = 100.0

@export_group("Ataque")
@export var dano: float = 15.0
@export var distancia_ataque: float = 1.8
@export var alcance_golpe: float = 2.2
@export var angulo_golpe: float = 60.0
@export var tiempo_preparacion: float = 0.5
@export var tiempo_recuperacion: float = 0.8
@export var cooldown_ataque: float = 1.0

@export_group("Superficie y Trepado")
@export var puede_trepar: bool = false
@export var vel_trepar_patrulla: float = 2.0
@export var vel_trepar_persecucion: float = 3.0
@export var anim_trepar_correr: bool = false

@export_group("Emboscada")
@export var emboscada: bool = false
@export var radio_emboscada: float = 2.5
@export var altura_max_emboscada: float = 8.0
@export var dano_caida: float = 20.0
@export var descubrir_si_mira: bool = true

@export_group("Patrulla")
@export var puntos_patrulla: Array[NodePath] = []

@export_group("Animación")
@export var animaciones_reales: bool = false

@export_group("Depuración")
@export var mostrar_debug: bool = true


# --- VARIABLES INTERNAS ---
var estado_actual: Estado = Estado.PATRULLA
var fase_ataque: FaseAtaque = FaseAtaque.NINGUNA
var subfase_trepar: SubfaseTrepar = SubfaseTrepar.NINGUNA
var modo_inmune: bool = false
var vida_actual: float = 100.0

var _nav: Node
var _visual: Node3D
var _animador: Node
var _jugador: CharacterBody3D
var _colision: CollisionShape3D
var _label_debug: Label3D
var _mov_sup: MovimientoSuperficie = null

var _timer_estado: float = 0.0
var _timer_vision: float = 0.0
var _timer_ataque_fase: float = 0.0
var _timer_cooldown_ataque: float = 0.0
var _jugador_en_vision: bool = false
var _posicion_sospecha: Vector3 = Vector3.ZERO
var _ultima_posicion_jugador: Vector3 = Vector3.ZERO

# Trepado y Emboscada
var _punto_trepar_subida: Node3D = null
var _punto_trepar_bajada: Node3D = null
var _posicion_meta_superficie: Vector3 = Vector3.ZERO
var _timer_chequeo_trepar: float = 0.0
var _tiempo_en_superficie_sin_ver: float = 0.0
var _fase_emboscada: int = 0 # 0=ACECHO, 1=AVISO, 2=CAIDA, 3=ATERRIZAJE
var _timer_emboscada: float = 0.0
var _normal_emboscada: Vector3 = Vector3.DOWN
var _muriendo_en_caida: bool = false

# Telegrafía y Visual
var _visual_pos_base: Vector3 = Vector3.ZERO
var _visual_scale_base: Vector3 = Vector3.ONE
var _tween_telegrafia: Tween
var _indicador_pivot: Node3D
var _mesh_indicador: MeshInstance3D

# Audio preparado
var audio_aviso: AudioStreamPlayer3D
var audio_golpe: AudioStreamPlayer3D
var audio_grunido: AudioStreamPlayer3D

# Patrulla
var _indice_patrulla: int = 0
var _esperando_patrulla: bool = false
var _timer_espera_patrulla: float = 0.0
var _puntos_cache: Array[Vector3] = []

# Búsqueda
var _puntos_busqueda_restantes: int = 0

# Alerta
var _ya_alerto_grupo: bool = false


func _ready() -> void:
	vida_actual = vida_maxima

	# Unirse al grupo de alerta
	if grupo_alerta != "":
		add_to_group(grupo_alerta)
	add_to_group("enemigos")

	# Obtener componentes
	_nav = get_node_or_null("MovimientoNav")
	if not _nav:
		_nav = find_child("MovimientoNav", true, false)

	_mov_sup = get_node_or_null("MovimientoSuperficie") as MovimientoSuperficie
	if not _mov_sup:
		_mov_sup = find_child("MovimientoSuperficie", true, false) as MovimientoSuperficie

	_visual = get_node_or_null("Visual") as Node3D
	if not _visual:
		_visual = find_child("Visual", true, false) as Node3D

	if _visual:
		_visual_pos_base = _visual.position
		_visual_scale_base = _visual.scale

	_colision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not _colision:
		_colision = find_child("CollisionShape3D", true, false) as CollisionShape3D

	# Preparar reproductores de audio para telegrafía y combate
	audio_aviso = get_node_or_null("AudioAviso") as AudioStreamPlayer3D
	if not audio_aviso:
		audio_aviso = AudioStreamPlayer3D.new()
		audio_aviso.name = "AudioAviso"
		add_child(audio_aviso)

	audio_golpe = get_node_or_null("AudioGolpe") as AudioStreamPlayer3D
	if not audio_golpe:
		audio_golpe = AudioStreamPlayer3D.new()
		audio_golpe.name = "AudioGolpe"
		add_child(audio_golpe)

	audio_grunido = get_node_or_null("AudioGrunido") as AudioStreamPlayer3D
	if not audio_grunido:
		audio_grunido = AudioStreamPlayer3D.new()
		audio_grunido.name = "AudioGrunido"
		add_child(audio_grunido)

	# Crear indicador visual de alcance de ataque (debug)
	_crear_indicador_ataque()

	# Buscar animador
	_animador = _buscar_animador(self)

	# Cachear puntos de patrulla
	_inicializar_puntos_patrulla()

	# Buscar jugador
	_buscar_jugador()

	# Conectar con eventos de sonido globales
	var eventos_sonido = get_node_or_null("/root/EventosSonido")
	if eventos_sonido and eventos_sonido.has_signal("ruido_emitido"):
		eventos_sonido.ruido_emitido.connect(_on_ruido_emitido)

	# Conectar señales de navegación
	if _nav:
		_nav.destino_alcanzado.connect(_on_nav_destino_alcanzado)
		if _nav.has_signal("sin_camino"):
			_nav.sin_camino.connect(func(): sin_camino.emit())

	# Conectar señales de movimiento en superficie si puede trepar
	if _mov_sup and puede_trepar:
		_mov_sup.pausar_padre = false
		_mov_sup.subio_a_pared.connect(_on_sup_subio_a_pared)
		_mov_sup.llego_al_techo.connect(_on_sup_llego_al_techo)
		_mov_sup.volvio_al_suelo.connect(_on_sup_volvio_al_suelo)
		_mov_sup.destino_superficie_alcanzado.connect(_on_sup_destino_superficie_alcanzado)

	# Label 3D de depuración
	if mostrar_debug:
		_crear_label_debug()

	# Iniciar en emboscada o patrulla
	if puede_trepar and emboscada:
		estado_actual = Estado.EMBOSCADA
		_entrar_estado(Estado.EMBOSCADA, Estado.EMBOSCADA)
	else:
		_entrar_estado(Estado.PATRULLA, Estado.PATRULLA)
	_actualizar_label_debug()


func _physics_process(delta: float) -> void:
	# Manejo de caída mortal previa a desvanecerse
	if _muriendo_en_caida:
		velocity += get_gravity() * delta
		move_and_slide()
		if is_on_floor():
			_muriendo_en_caida = false
			morir()
		return

	if estado_actual == Estado.MUERTO:
		return

	# Reducción de cooldown de ataque
	if _timer_cooldown_ataque > 0.0:
		_timer_cooldown_ataque -= delta

	# Comprobación de visión periódica (cada 0.1 s)
	_timer_vision += delta
	if _timer_vision >= 0.1:
		_timer_vision = 0.0
		_jugador_en_vision = _verificar_vision()

	# Posicionar Label3D de depuración respecto al lomo actual
	if _label_debug and mostrar_debug:
		var up_lbl = _mov_sup.normal_superficie if (_mov_sup and _mov_sup.trepando) else Vector3.UP
		_label_debug.position = up_lbl * (altura_ojos + 0.5)

	# Procesamiento según estado actual
	match estado_actual:
		Estado.PATRULLA:
			_proceso_patrulla(delta)
		Estado.SOSPECHA:
			_proceso_sospecha(delta)
		Estado.PERSECUCION:
			_proceso_persecucion(delta)
		Estado.BUSQUEDA:
			_proceso_busqueda(delta)
		Estado.ATURDIDO:
			_proceso_aturdido(delta)
		Estado.ATAQUE:
			_proceso_ataque(delta)
		Estado.TREPANDO:
			_proceso_trepando(delta)
		Estado.EMBOSCADA:
			_proceso_emboscada(delta)


# ==============================================================================
# MÁQUINA DE ESTADOS (CAMBIO Y ENTRADA)
# ==============================================================================

func cambiar_estado(nuevo: Estado) -> void:
	if estado_actual == nuevo and nuevo != Estado.SOSPECHA and nuevo != Estado.ATAQUE:
		return
	if estado_actual == Estado.MUERTO:
		return

	var anterior = estado_actual
	_salir_estado(anterior)
	estado_actual = nuevo
	_actualizar_label_debug()
	_entrar_estado(anterior, nuevo)
	estado_cambiado.emit(anterior, nuevo)


func _salir_estado(anterior: Estado) -> void:
	if anterior == Estado.ATAQUE:
		_cancelar_ataque()
	if _mov_sup:
		_mov_sup.animacion_bloqueada = false


func _entrar_estado(anterior: Estado, nuevo: Estado) -> void:
	match nuevo:
		Estado.PATRULLA:
			if _mov_sup and _mov_sup.trepando:
				_mov_sup.terminar_trepar()
			if _nav:
				_nav.velocidad = vel_patrulla
			_ya_alerto_grupo = false
			_esperando_patrulla = false
			_reproducir_animacion("caminar")
			_ir_a_siguiente_patrulla()

		Estado.SOSPECHA:
			if _mov_sup and _mov_sup.trepando:
				_mov_sup.detener_en_superficie()
			elif _nav:
				_nav.detener()

			var dist_sospecha = global_position.distance_to(_posicion_sospecha)
			var de_frente = false
			if _visual:
				var frente_h = _get_frente_visual()
				frente_h.y = 0.0
				var dir_h = (_posicion_sospecha - global_position)
				dir_h.y = 0.0
				if frente_h.length_squared() > 0.001 and dir_h.length_squared() > 0.001:
					var ang = rad_to_deg(frente_h.normalized().angle_to(dir_h.normalized()))
					if ang <= 40.0:
						de_frente = true
			if dist_sospecha <= 6.0 and de_frente:
				_timer_estado = 0.5
			else:
				_timer_estado = tiempo_sospecha
			_reproducir_animacion("idle")
			_mirar_hacia(_posicion_sospecha, 1.0)

		Estado.PERSECUCION:
			if _mov_sup and _mov_sup.trepando:
				# Si ya estaba trepando, continuar en superficie
				cambiar_estado(Estado.TREPANDO)
				return
			if _nav:
				_nav.velocidad = vel_persecucion
			_reproducir_animacion("correr")
			# Alertar a la manada por primera vez
			if not _ya_alerto_grupo and grupo_alerta != "":
				_ya_alerto_grupo = true
				if _jugador:
					get_tree().call_group(grupo_alerta, "alertar", _jugador.global_position)

		Estado.BUSQUEDA:
			if _mov_sup and _mov_sup.trepando:
				# Si estaba en el techo o pared, bajar al suelo por el punto de salida más cercano
				var p_salida = _encontrar_punto_trepar_mas_cercano(true)
				if p_salida:
					_punto_trepar_bajada = p_salida
					subfase_trepar = SubfaseTrepar.BAJANDO
					_mov_sup.ir_a_superficie(p_salida.global_position)
				else:
					_mov_sup.terminar_trepar()
			if _nav:
				_nav.velocidad = vel_busqueda
			_reproducir_animacion("caminar")
			_timer_estado = tiempo_busqueda
			_puntos_busqueda_restantes = 3
			if _nav and not (_mov_sup and _mov_sup.trepando):
				_nav.ir_a(_ultima_posicion_jugador)

		Estado.ATURDIDO:
			if _mov_sup and _mov_sup.trepando:
				_mov_sup.detener_en_superficie()
			elif _nav:
				_nav.detener()
			_reproducir_animacion("idle")

		Estado.MUERTO:
			if _mov_sup and _mov_sup.trepando:
				_mov_sup.terminar_trepar()
			if _nav:
				_nav.detener()
			velocity = Vector3.ZERO
			if _colision:
				_colision.set_deferred("disabled", true)
			if _label_debug:
				_label_debug.visible = false
			if _indicador_pivot:
				_indicador_pivot.visible = false
			_reproducir_animacion("morir")

			if animaciones_reales:
				if _tween_telegrafia and _tween_telegrafia.is_valid():
					_tween_telegrafia.kill()
				if _visual:
					var tw_fade = create_tween().set_parallel(true)
					tw_fade.tween_property(_visual, "scale", Vector3.ZERO, 0.8).set_delay(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw_fade.chain().tween_callback(queue_free)
				else:
					get_tree().create_timer(1.8).timeout.connect(queue_free)
			elif _visual:
				if _tween_telegrafia and _tween_telegrafia.is_valid():
					_tween_telegrafia.kill()
				var tw = create_tween().set_parallel(true)
				tw.tween_property(_visual, "rotation:z", deg_to_rad(85.0), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tw.tween_property(_visual, "position:y", _visual_pos_base.y - 0.25, 0.4)
				var tw_fade = create_tween().set_parallel(true)
				tw_fade.tween_property(_visual, "scale", Vector3.ZERO, 1.0).set_delay(0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw_fade.chain().tween_callback(queue_free)
			else:
				get_tree().create_timer(1.5).timeout.connect(queue_free)

		Estado.ATAQUE:
			if _mov_sup and _mov_sup.trepando:
				_mov_sup.detener_en_superficie()
				_mov_sup.animacion_bloqueada = true
			elif _nav:
				_nav.detener()

			velocity = Vector3.ZERO
			fase_ataque = FaseAtaque.PREPARACION
			_timer_ataque_fase = tiempo_preparacion

			# Orientar al jugador
			_orientar_ataque_hacia_jugador()
			_reproducir_animacion("atacar")

			if audio_aviso and audio_aviso.stream:
				audio_aviso.play()
			if _indicador_pivot and mostrar_debug:
				_actualizar_transform_indicador_ataque()
				_indicador_pivot.visible = true
			_iniciar_telegrafia_visual()
			_actualizar_label_debug()

		Estado.TREPANDO:
			if _mov_sup:
				_mov_sup.velocidad_trepar = vel_trepar_persecucion
				_mov_sup.nombre_anim_avance = "correr" if anim_trepar_correr else "caminar"
			_actualizar_label_debug()

		Estado.EMBOSCADA:
			_fase_emboscada = 0
			_timer_emboscada = 0.0
			velocity = Vector3.ZERO
			if _nav:
				_nav.detener()
				_nav.set_physics_process(false)
			if _mov_sup:
				_mov_sup.pausar_padre = false
				var n_emb = _detectar_normal_superficie_cercana()
				_normal_emboscada = n_emb
				_mov_sup.iniciar_trepar(n_emb)
				_mov_sup.detener_en_superficie()
			_reproducir_animacion("idle")
			_actualizar_label_debug()


# ==============================================================================
# LÓGICA DE CADA ESTADO
# ==============================================================================

func _proceso_patrulla(delta: float) -> void:
	if _jugador_en_vision:
		_posicion_sospecha = _jugador.global_position
		_ultima_posicion_jugador = _jugador.global_position
		cambiar_estado(Estado.SOSPECHA)
		return

	if _puntos_cache.is_empty():
		_reproducir_animacion("idle")
		return

	if _esperando_patrulla:
		_timer_espera_patrulla -= delta
		if _timer_espera_patrulla <= 0.0:
			_esperando_patrulla = false
			_indice_patrulla = (_indice_patrulla + 1) % _puntos_cache.size()
			_reproducir_animacion("caminar")
			_ir_a_siguiente_patrulla()


func _proceso_sospecha(delta: float) -> void:
	_mirar_hacia(_posicion_sospecha, delta * 2.0)

	if _jugador_en_vision:
		_ultima_posicion_jugador = _jugador.global_position
		cambiar_estado(Estado.PERSECUCION)
		return

	_timer_estado -= delta
	if _timer_estado <= 0.0:
		cambiar_estado(Estado.BUSQUEDA)


func _proceso_persecucion(delta: float) -> void:
	if _jugador_en_vision and _jugador and not _jugador.get("muerto"):
		_ultima_posicion_jugador = _jugador.global_position

		# Si puede trepar, evaluar periódicamente si trepar ofrece una ruta superior
		if puede_trepar and _mov_sup:
			_timer_chequeo_trepar += delta
			if _timer_chequeo_trepar >= 0.35:
				_timer_chequeo_trepar = 0.0
				var eval = buscar_ruta_trepar(_jugador.global_position)
				if eval.conviene_trepar:
					_punto_trepar_subida = eval.punto_subida
					_punto_trepar_bajada = eval.punto_bajada
					subfase_trepar = SubfaseTrepar.SUBIENDO
					cambiar_estado(Estado.TREPANDO)
					return

		var diff = _jugador.global_position - global_position
		var dist_h = Vector2(diff.x, diff.z).length()

		if dist_h <= distancia_ataque and _timer_cooldown_ataque <= 0.0:
			cambiar_estado(Estado.ATAQUE)
			return
		elif dist_h <= distancia_contacto:
			if _nav:
				_nav.detener()
			_mirar_hacia(_jugador.global_position)
			_reproducir_animacion("idle")
			jugador_alcanzado.emit()
		else:
			if _nav:
				_nav.ir_a(_jugador.global_position)
			_reproducir_animacion("correr")
	else:
		cambiar_estado(Estado.BUSQUEDA)


func _proceso_trepando(delta: float) -> void:
	_aplicar_separacion_aranas(delta)

	match subfase_trepar:
		SubfaseTrepar.SUBIENDO:
			if not _punto_trepar_subida or not is_instance_valid(_punto_trepar_subida):
				subfase_trepar = SubfaseTrepar.NINGUNA
				cambiar_estado(Estado.PERSECUCION)
				return

			var dist_sub = global_position.distance_to(_punto_trepar_subida.global_position)
			if dist_sub <= 0.85:
				var n_sub = _punto_trepar_subida.get("normal_superficie")
				if n_sub == null or (n_sub is Vector3 and n_sub == Vector3.ZERO):
					n_sub = Vector3.UP
				if _mov_sup:
					_mov_sup.iniciar_trepar(n_sub)
					_mov_sup.velocidad_trepar = vel_trepar_persecucion
					_mov_sup.nombre_anim_avance = "correr" if anim_trepar_correr else "caminar"
					if _punto_trepar_bajada and is_instance_valid(_punto_trepar_bajada):
						_posicion_meta_superficie = _punto_trepar_bajada.global_position
						_mov_sup.ir_a_superficie(_posicion_meta_superficie)
					elif _jugador:
						_mov_sup.ir_a_superficie(_jugador.global_position)
				subfase_trepar = SubfaseTrepar.EN_SUPERFICIE
				_actualizar_label_debug()
			else:
				if _nav:
					_nav.velocidad = vel_trepar_persecucion
					_nav.ir_a(_punto_trepar_subida.global_position)
				_reproducir_animacion("correr")

		SubfaseTrepar.EN_SUPERFICIE:
			if not _mov_sup or not _mov_sup.trepando:
				subfase_trepar = SubfaseTrepar.NINGUNA
				cambiar_estado(Estado.PERSECUCION if _jugador_en_vision else Estado.BUSQUEDA)
				return

			if _jugador_en_vision and _jugador and not _jugador.get("muerto"):
				_ultima_posicion_jugador = _jugador.global_position
				_tiempo_en_superficie_sin_ver = 0.0

				var dist_3d = global_position.distance_to(_jugador.global_position)
				if dist_3d <= distancia_ataque and _timer_cooldown_ataque <= 0.0:
					_mov_sup.detener_en_superficie()
					cambiar_estado(Estado.ATAQUE)
					return
				elif dist_3d <= distancia_contacto:
					_mov_sup.detener_en_superficie()
					jugador_alcanzado.emit()
				else:
					if _punto_trepar_bajada and is_instance_valid(_punto_trepar_bajada):
						var dist_baj = global_position.distance_to(_punto_trepar_bajada.global_position)
						if dist_baj <= 0.9:
							subfase_trepar = SubfaseTrepar.BAJANDO
							_mov_sup.terminar_trepar()
							_actualizar_label_debug()
							return
						else:
							_mov_sup.ir_a_superficie(_punto_trepar_bajada.global_position)
					else:
						_mov_sup.ir_a_superficie(_jugador.global_position)
			else:
				_tiempo_en_superficie_sin_ver += delta
				if _tiempo_en_superficie_sin_ver >= 2.5:
					# Perdió al jugador: descender y buscar
					var p_salida = _encontrar_punto_trepar_mas_cercano(true)
					if p_salida:
						_punto_trepar_bajada = p_salida
						_mov_sup.ir_a_superficie(p_salida.global_position)
						if global_position.distance_to(p_salida.global_position) <= 0.9:
							subfase_trepar = SubfaseTrepar.BAJANDO
							_mov_sup.terminar_trepar()
							_actualizar_label_debug()
					else:
						subfase_trepar = SubfaseTrepar.BAJANDO
						_mov_sup.terminar_trepar()
						_actualizar_label_debug()

		SubfaseTrepar.BAJANDO:
			if _mov_sup and not _mov_sup.trepando:
				subfase_trepar = SubfaseTrepar.NINGUNA
				cambiar_estado(Estado.PERSECUCION if _jugador_en_vision else Estado.BUSQUEDA)


func _proceso_emboscada(delta: float) -> void:
	if not _jugador or not is_instance_valid(_jugador) or _jugador.get("muerto"):
		_buscar_jugador()
		return

	match _fase_emboscada:
		0: # ACECHO: en el techo/pared, en silencio y quieta
			var pos_enemigo = global_position
			var pos_jugador = _jugador.global_position
			var diff = pos_jugador - pos_enemigo
			var dist_h = Vector2(diff.x, diff.z).length()
			var diff_y = pos_enemigo.y - pos_jugador.y

			# Detección dentro de un cilindro vertical
			if dist_h <= radio_emboscada and diff_y >= -0.5 and diff_y <= altura_max_emboscada:
				if _hay_linea_vision_directa(pos_enemigo, pos_jugador):
					var mirandola = _verificar_si_jugador_lo_mira()
					if mirandola and descubrir_si_mira:
						# Descubierta por el jugador: no cae a ciegas, pasa a persecución
						emboscada = false
						cambiar_estado(Estado.PERSECUCION)
					elif not mirandola:
						# Emboscada disparada: aviso breve de 0.35 s
						_fase_emboscada = 1
						_timer_emboscada = 0.35
						_reproducir_animacion("atacar")
						if audio_aviso and audio_aviso.stream:
							audio_aviso.play()
						_actualizar_label_debug()

		1: # AVISO PREVIO (0.35 s)
			_timer_emboscada -= delta
			if _timer_emboscada <= 0.0:
				_fase_emboscada = 2
				if _mov_sup:
					_mov_sup.terminar_trepar()
				motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
				up_direction = Vector3.UP
				velocity = Vector3(0.0, -3.0, 0.0)
				_actualizar_label_debug()

		2: # CAYENDO CON GRAVEDAD
			velocity += get_gravity() * delta
			move_and_slide()

			if is_on_floor():
				_fase_emboscada = 3
				emboscada = false # Solo cae una vez por emboscada

				var dist_aterrizaje = global_position.distance_to(_jugador.global_position)
				if dist_aterrizaje <= 1.5 and not modo_inmune and not _jugador.get("muerto"):
					if _jugador.has_method("recibir_dano"):
						_jugador.recibir_dano(dano_caida, global_position)
						jugador_alcanzado.emit()

				# Queda aturdida 0.8 s tras el impacto para ventana de contraataque
				aturdir(0.8)


func _proceso_ataque(delta: float) -> void:
	if not _jugador or not is_instance_valid(_jugador) or _jugador.get("muerto"):
		_cancelar_ataque()
		cambiar_estado(Estado.PATRULLA)
		return

	if _indicador_pivot and mostrar_debug:
		_actualizar_transform_indicador_ataque()

	match fase_ataque:
		FaseAtaque.PREPARACION:
			_orientar_ataque_hacia_jugador()
			_timer_ataque_fase -= delta
			if _timer_ataque_fase <= 0.0:
				_ejecutar_golpe()

		FaseAtaque.GOLPE:
			pass

		FaseAtaque.RECUPERACION:
			_timer_ataque_fase -= delta
			if _timer_ataque_fase <= 0.0:
				_finalizar_ataque()


func _ejecutar_golpe() -> void:
	fase_ataque = FaseAtaque.GOLPE
	_actualizar_label_debug()
	if _indicador_pivot:
		_indicador_pivot.visible = false

	# Embestida procedural en Visual si no tiene clips reales
	if _visual and not animaciones_reales:
		if _tween_telegrafia and _tween_telegrafia.is_valid():
			_tween_telegrafia.kill()
		_tween_telegrafia = create_tween()
		_tween_telegrafia.tween_property(_visual, "position:z", _visual_pos_base.z - 0.35, 0.08)
		_tween_telegrafia.tween_property(_visual, "position:z", _visual_pos_base.z, 0.2)
		_tween_telegrafia.tween_property(_visual, "scale", _visual_scale_base, 0.1)

	if audio_golpe and audio_golpe.stream:
		audio_golpe.play()

	var acerto: bool = false
	if _jugador and is_instance_valid(_jugador) and not _jugador.get("muerto"):
		var diff = _jugador.global_position - global_position
		var dist_3d = diff.length()
		var esta_en_superficie = _mov_sup and _mov_sup.trepando

		if not esta_en_superficie:
			var dist_h = Vector2(diff.x, diff.z).length()
			var diff_y = absf(diff.y)
			if dist_h <= alcance_golpe and diff_y <= 3.5:
				var frente = _get_frente_visual()
				var dir_h = Vector3(diff.x, 0.0, diff.z)
				if dir_h.length_squared() > 0.001:
					dir_h = dir_h.normalized()
					var frente_h = Vector3(frente.x, 0.0, frente.z).normalized()
					var ang = rad_to_deg(frente_h.angle_to(dir_h))
					if ang <= (angulo_golpe / 2.0):
						acerto = true
		else:
			# En pared / techo: cálculo en 3D directo con base local
			if dist_3d <= alcance_golpe:
				var dir_3d = diff.normalized()
				var frente_3d = _get_frente_visual().normalized()
				if _mov_sup.normal_superficie.y < -0.65:
					frente_3d = (frente_3d + _mov_sup.normal_superficie).normalized()
				else:
					frente_3d = (frente_3d + _mov_sup.normal_superficie * 0.8).normalized()
				var ang = rad_to_deg(frente_3d.angle_to(dir_3d))
				if ang <= (angulo_golpe / 2.0) or dist_3d <= distancia_ataque:
					acerto = true

	if acerto:
		if not modo_inmune and _jugador.has_method("recibir_dano"):
			_jugador.recibir_dano(dano, global_position)
		jugador_alcanzado.emit()

	fase_ataque = FaseAtaque.RECUPERACION
	_timer_ataque_fase = tiempo_recuperacion
	if not animaciones_reales:
		_reproducir_animacion("idle")
	_actualizar_label_debug()


func _finalizar_ataque() -> void:
	_restaurar_visual()
	fase_ataque = FaseAtaque.NINGUNA
	_timer_cooldown_ataque = cooldown_ataque
	if _mov_sup:
		_mov_sup.animacion_bloqueada = false

	if _mov_sup and _mov_sup.trepando:
		cambiar_estado(Estado.TREPANDO)
	elif _jugador_en_vision and not (_jugador and _jugador.get("muerto")):
		cambiar_estado(Estado.PERSECUCION)
	else:
		cambiar_estado(Estado.BUSQUEDA)


func _cancelar_ataque() -> void:
	if _tween_telegrafia and _tween_telegrafia.is_valid():
		_tween_telegrafia.kill()
	_restaurar_visual()
	if _indicador_pivot:
		_indicador_pivot.visible = false
	if _mov_sup:
		_mov_sup.animacion_bloqueada = false
	fase_ataque = FaseAtaque.NINGUNA


func _proceso_busqueda(delta: float) -> void:
	if _jugador_en_vision:
		_ultima_posicion_jugador = _jugador.global_position
		cambiar_estado(Estado.PERSECUCION)
		return

	_timer_estado -= delta
	if _timer_estado <= 0.0:
		cambiar_estado(Estado.PATRULLA)
		return

	if _nav and _nav.esta_en_destino():
		if _puntos_busqueda_restantes > 0:
			_puntos_busqueda_restantes -= 1
			_investigar_siguiente_punto_busqueda()
		else:
			cambiar_estado(Estado.PATRULLA)


func _proceso_aturdido(delta: float) -> void:
	if _mov_sup and _mov_sup.trepando:
		# En pared/techo se mantiene adherida
		_timer_estado -= delta
		if _timer_estado <= 0.0:
			cambiar_estado(Estado.TREPANDO if _jugador_en_vision else Estado.BUSQUEDA)
		return

	# En el suelo: retroceso y gravedad
	velocity.x = lerp(velocity.x, 0.0, 6.0 * delta)
	velocity.z = lerp(velocity.z, 0.0, 6.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	_timer_estado -= delta
	if _timer_estado <= 0.0:
		if _jugador_en_vision or _posicion_sospecha != Vector3.ZERO:
			cambiar_estado(Estado.PERSECUCION)
		else:
			cambiar_estado(Estado.BUSQUEDA)


# ==============================================================================
# PERCEPCIÓN (VISIÓN Y OÍDO)
# ==============================================================================

func _verificar_vision() -> bool:
	if not _jugador or not is_instance_valid(_jugador):
		_buscar_jugador()
		if not _jugador:
			return false

	var up_actual = _mov_sup.normal_superficie if (_mov_sup and _mov_sup.trepando) else global_transform.basis.y.normalized()
	var frente_actual = _get_frente_visual()
	var pos_ojos = global_position + up_actual * altura_ojos
	var pos_jugador = _jugador.global_position + Vector3(0.0, 0.8, 0.0)
	var dist = pos_ojos.distance_to(pos_jugador)

	# 1. Rango de distancia
	if dist > rango_vision:
		return false

	# 2. Cono de visión
	var esta_en_superficie = _mov_sup and _mov_sup.trepando
	if not esta_en_superficie:
		var dir_h = (pos_jugador - pos_ojos)
		dir_h.y = 0.0
		if dir_h.length_squared() > 0.001:
			dir_h = dir_h.normalized()
			var frente_h = Vector3(frente_actual.x, 0.0, frente_actual.z).normalized()
			var angulo = rad_to_deg(frente_h.angle_to(dir_h))
			if angulo > (angulo_vision / 2.0):
				return false
	else:
		var dir_3d = (pos_jugador - pos_ojos).normalized()
		var dir_cono = frente_actual.normalized()

		# Si está en el techo (normal apuntando hacia abajo), el cono enfoca hacia la habitación
		if up_actual.y < -0.65:
			dir_cono = (frente_actual + up_actual * 1.3).normalized()

		var angulo_3d = rad_to_deg(dir_cono.angle_to(dir_3d))
		if angulo_3d > (angulo_vision / 2.0):
			return false

	# 3. Raycast de oclusión
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(pos_ojos, pos_jugador)
	query.collision_mask = mascara_vision
	query.exclude = [get_rid()]

	var hit = space.intersect_ray(query)
	if hit:
		if hit.collider == _jugador or _jugador.is_ancestor_of(hit.collider):
			return true
		else:
			return false

	return true


func _on_ruido_emitido(posicion_ruido: Vector3, radio_ruido: float) -> void:
	if estado_actual == Estado.MUERTO or estado_actual == Estado.ATURDIDO or estado_actual == Estado.PERSECUCION or estado_actual == Estado.EMBOSCADA:
		return

	var dist = global_position.distance_to(posicion_ruido)
	if dist <= (rango_oido + radio_ruido):
		_posicion_sospecha = posicion_ruido
		_ultima_posicion_jugador = posicion_ruido
		cambiar_estado(Estado.SOSPECHA)


# ==============================================================================
# ALERTA DE GRUPO Y DAÑO
# ==============================================================================

func alertar(posicion_alerta: Vector3) -> void:
	if estado_actual == Estado.MUERTO:
		return

	_posicion_sospecha = posicion_alerta
	_ultima_posicion_jugador = posicion_alerta

	if puede_trepar and _mov_sup:
		var eval = buscar_ruta_trepar(posicion_alerta)
		if eval.conviene_trepar:
			_punto_trepar_subida = eval.punto_subida
			_punto_trepar_bajada = eval.punto_bajada
			subfase_trepar = SubfaseTrepar.SUBIENDO
			cambiar_estado(Estado.TREPANDO)
			return

	if estado_actual == Estado.PATRULLA or estado_actual == Estado.BUSQUEDA:
		cambiar_estado(Estado.PERSECUCION)
	elif estado_actual != Estado.PERSECUCION and estado_actual != Estado.ATURDIDO and estado_actual != Estado.ATAQUE and estado_actual != Estado.TREPANDO:
		cambiar_estado(Estado.SOSPECHA)


func aturdir(duracion: float = 1.5) -> void:
	if estado_actual == Estado.MUERTO:
		return
	if estado_actual == Estado.ATAQUE:
		_cancelar_ataque()
	if _mov_sup and _mov_sup.trepando:
		_mov_sup.detener_en_superficie()
	_timer_estado = duracion
	cambiar_estado(Estado.ATURDIDO)


func morir() -> void:
	if estado_actual == Estado.ATAQUE:
		_cancelar_ataque()
	cambiar_estado(Estado.MUERTO)


func recibir_dano(cantidad: float, origen_o_dir: Vector3 = Vector3.ZERO, atacante: Node = null) -> void:
	if estado_actual == Estado.MUERTO or _muriendo_en_caida:
		return

	vida_actual = maxf(vida_actual - cantidad, 0.0)

	if estado_actual == Estado.ATAQUE:
		_cancelar_ataque()

	if vida_actual <= 0.0:
		if _mov_sup and _mov_sup.trepando:
			# Daño letal en pared o techo: suelta y cae al suelo con gravedad antes de morir
			_mov_sup.terminar_trepar()
			motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			up_direction = Vector3.UP
			_muriendo_en_caida = true
			if _colision:
				_colision.set_deferred("disabled", false)
			return
		else:
			morir()
			return

	var pos_atacante = Vector3.ZERO
	if atacante and is_instance_valid(atacante):
		pos_atacante = atacante.global_position
	elif _jugador and is_instance_valid(_jugador):
		pos_atacante = _jugador.global_position
	elif origen_o_dir.length_squared() > 1.5:
		pos_atacante = origen_o_dir

	if pos_atacante != Vector3.ZERO:
		_ultima_posicion_jugador = pos_atacante
		_posicion_sospecha = pos_atacante

	# En superficie se mantiene pegada; en suelo retrocede
	if _mov_sup and _mov_sup.trepando:
		_mov_sup.detener_en_superficie()
	else:
		var dir_kb = origen_o_dir
		if dir_kb.length_squared() > 1.5:
			dir_kb = (global_position - dir_kb)
		elif dir_kb == Vector3.ZERO and pos_atacante != Vector3.ZERO:
			dir_kb = (global_position - pos_atacante)
		dir_kb.y = 0.2
		if dir_kb.length_squared() > 0.001:
			velocity = dir_kb.normalized() * 4.5

	aturdir(0.3)

	if grupo_alerta != "" and pos_atacante != Vector3.ZERO:
		get_tree().call_group(grupo_alerta, "alertar", pos_atacante)


# ==============================================================================
# ALGORITMO DE RUTA: SUELO vs SUPERFICIE (TREPAR)
# ==============================================================================

func buscar_ruta_trepar(destino: Vector3) -> Dictionary:
	var res = {
		"conviene_trepar": false,
		"punto_subida": null,
		"punto_bajada": null,
		"dist_suelo": INF,
		"dist_trepar": INF,
		"hay_camino": false
	}

	if not puede_trepar or not _mov_sup:
		return res

	var dist_directa = global_position.distance_to(destino)
	if dist_directa < 0.05:
		res["hay_camino"] = true
		return res

	# 1. Longitud de ruta terrestre con NavigationServer
	var nav_map = _nav.get_navigation_map() if _nav else get_world_3d().navigation_map
	var camino_suelo: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, global_position, destino, true)
	var dist_suelo: float = INF
	var suelo_alcanzable: bool = false

	if camino_suelo.size() >= 2:
		dist_suelo = 0.0
		for i in range(camino_suelo.size() - 1):
			dist_suelo += camino_suelo[i].distance_to(camino_suelo[i + 1])
		if camino_suelo[camino_suelo.size() - 1].distance_to(destino) <= 1.8:
			suelo_alcanzable = true

	res["dist_suelo"] = dist_suelo

	# 2. Puntos de trepar en la escena
	var puntos_trepar = get_tree().get_nodes_in_group("punto_trepar")
	if puntos_trepar.is_empty():
		res["hay_camino"] = suelo_alcanzable
		return res

	# Mejor punto de subida (cercano al enemigo)
	var mejor_sub: Node3D = null
	var min_d_sub: float = INF
	for p in puntos_trepar:
		if p is Node3D and (not ("es_entrada_suelo" in p) or p.es_entrada_suelo):
			var d = global_position.distance_to(p.global_position)
			if d < min_d_sub:
				min_d_sub = d
				mejor_sub = p

	# Mejor punto de bajada (cercano al destino)
	var mejor_baj: Node3D = null
	var min_d_baj: float = INF
	for p in puntos_trepar:
		if p is Node3D and p != mejor_sub and (not ("es_salida_suelo" in p) or p.es_salida_suelo):
			var d = destino.distance_to(p.global_position)
			if d < min_d_baj:
				min_d_baj = d
				mejor_baj = p

	if mejor_sub:
		var dist_sup = 0.0
		if mejor_baj:
			dist_sup = mejor_sub.global_position.distance_to(mejor_baj.global_position)
			res["dist_trepar"] = min_d_sub + dist_sup + min_d_baj
		else:
			dist_sup = mejor_sub.global_position.distance_to(destino)
			res["dist_trepar"] = min_d_sub + dist_sup

		res["punto_subida"] = mejor_sub
		res["punto_bajada"] = mejor_baj

	# 3. Regla de conveniencia:
	# Si la ruta por suelo es corta (< 1.5x distancia directa), usar suelo
	if suelo_alcanzable and dist_suelo < (dist_directa * 1.5):
		res["conviene_trepar"] = false
		res["hay_camino"] = true
	elif res["dist_trepar"] < INF:
		if not suelo_alcanzable or res["dist_trepar"] < dist_suelo:
			res["conviene_trepar"] = true
			res["hay_camino"] = true
		else:
			res["conviene_trepar"] = false
			res["hay_camino"] = suelo_alcanzable
	else:
		res["conviene_trepar"] = false
		res["hay_camino"] = suelo_alcanzable

	return res


func _aplicar_separacion_aranas(delta: float) -> void:
	if not _mov_sup or not _mov_sup.trepando:
		return
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	for e in enemigos:
		if e != self and is_instance_valid(e) and e is CharacterBody3D:
			var diff = global_position - e.global_position
			var dist = diff.length()
			if dist < 0.8 and dist > 0.01:
				var dir_sep = diff.slide(_mov_sup.normal_superficie).normalized()
				if dir_sep.length_squared() > 0.001:
					var empuje = (0.8 - dist) * 2.0
					global_position += dir_sep * empuje * delta


func _encontrar_punto_trepar_mas_cercano(solo_salidas: bool = true) -> Node3D:
	var puntos = get_tree().get_nodes_in_group("punto_trepar")
	var mejor: Node3D = null
	var min_d: float = INF
	for p in puntos:
		if p is Node3D:
			if solo_salidas and ("es_salida_suelo" in p) and not p.es_salida_suelo:
				continue
			var d = global_position.distance_to(p.global_position)
			if d < min_d:
				min_d = d
				mejor = p
	return mejor


func _detectar_normal_superficie_cercana() -> Vector3:
	var space = get_world_3d().direct_space_state
	var dirs: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	for d in dirs:
		var q = PhysicsRayQueryParameters3D.create(global_position, global_position + d * 1.5)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		var h = space.intersect_ray(q)
		if not h.is_empty():
			var col = h["collider"]
			if col and (col.is_in_group("trepable") or (col.get_parent() and col.get_parent().is_in_group("trepable"))):
				return (h["normal"] as Vector3).normalized()
	return Vector3.DOWN


# ==============================================================================
# DETECCIÓN DE MIRADA DEL JUGADOR (ANTI-EMBOSCADA)
# ==============================================================================

func _verificar_si_jugador_lo_mira() -> bool:
	if not _jugador or not is_instance_valid(_jugador) or _jugador.get("muerto"):
		return false

	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		cam = _jugador.find_child("Camera3D", true, false) as Camera3D
	if not cam or not is_instance_valid(cam):
		return false

	var cam_fwd = -cam.global_transform.basis.z.normalized()
	var pos_centro = global_position + (_mov_sup.normal_superficie * 0.2 if _mov_sup and _mov_sup.trepando else Vector3.UP * 0.3)
	var vec = pos_centro - cam.global_position
	var dist = vec.length()
	if dist < 0.1:
		return true

	var dir_norm = vec / dist
	var dot = cam_fwd.dot(dir_norm)
	var umbral_dot = cos(deg_to_rad(70.0))

	if dot < umbral_dot:
		return false

	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(cam.global_position, pos_centro)
	query.collision_mask = 1
	var exclude: Array[RID] = [get_rid()]
	if _jugador:
		exclude.append(_jugador.get_rid())
	query.exclude = exclude

	var hit = space.intersect_ray(query)
	return hit.is_empty()


func _hay_linea_vision_directa(origen: Vector3, destino: Vector3) -> bool:
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(origen, destino)
	q.collision_mask = 1 # Oclusión por paredes/techos
	q.exclude = [get_rid()]
	if _jugador:
		q.exclude.append(_jugador.get_rid())
	var hit = space.intersect_ray(q)
	return hit.is_empty()


# ==============================================================================
# SEÑALES DE COMPONENTES
# ==============================================================================

func _on_sup_subio_a_pared() -> void:
	if subfase_trepar == SubfaseTrepar.SUBIENDO:
		subfase_trepar = SubfaseTrepar.EN_SUPERFICIE
		_actualizar_label_debug()


func _on_sup_llego_al_techo() -> void:
	_actualizar_label_debug()


func _on_sup_volvio_al_suelo() -> void:
	if estado_actual == Estado.TREPANDO:
		subfase_trepar = SubfaseTrepar.NINGUNA
		cambiar_estado(Estado.PERSECUCION if _jugador_en_vision else Estado.BUSQUEDA)


func _on_sup_destino_superficie_alcanzado() -> void:
	if estado_actual == Estado.TREPANDO:
		if _punto_trepar_bajada and global_position.distance_to(_punto_trepar_bajada.global_position) <= 1.2:
			subfase_trepar = SubfaseTrepar.BAJANDO
			if _mov_sup:
				_mov_sup.terminar_trepar()


func _inicializar_puntos_patrulla() -> void:
	_puntos_cache.clear()
	for p_path in puntos_patrulla:
		var nodo = get_node_or_null(p_path) as Node3D
		if nodo:
			_puntos_cache.append(nodo.global_position)

	if _puntos_cache.is_empty():
		var patrulla_nodo = find_child("Patrulla", true, false)
		if patrulla_nodo:
			for hijo in patrulla_nodo.get_children():
				if hijo is Node3D:
					_puntos_cache.append(hijo.global_position)


func _ir_a_siguiente_patrulla() -> void:
	if _puntos_cache.is_empty() or not _nav:
		return
	_indice_patrulla = _indice_patrulla % _puntos_cache.size()
	_nav.ir_a(_puntos_cache[_indice_patrulla])


func _on_nav_destino_alcanzado() -> void:
	if estado_actual == Estado.PATRULLA and not _esperando_patrulla:
		_esperando_patrulla = true
		_timer_espera_patrulla = tiempo_espera_patrulla
		if _nav:
			_nav.detener()
		_reproducir_animacion("idle")


func _investigar_siguiente_punto_busqueda() -> void:
	if not _nav:
		return
	var nav_map = _nav.get_navigation_map()
	var offset = Vector3(randf_range(-4.5, 4.5), 0.0, randf_range(-4.5, 4.5))
	var punto_candidato = _ultima_posicion_jugador + offset
	var punto_nav = NavigationServer3D.map_get_closest_point(nav_map, punto_candidato)
	_nav.ir_a(punto_nav)


func _orientar_ataque_hacia_jugador() -> void:
	if not _jugador or not is_instance_valid(_jugador):
		return
	var dir_j = (_jugador.global_position - global_position)
	var esta_en_superficie = _mov_sup and _mov_sup.trepando

	if not esta_en_superficie:
		dir_j.y = 0.0
		if dir_j.length_squared() > 0.01 and _visual:
			_visual.rotation.y = _calcular_angulo_hacia(dir_j.normalized())
	else:
		var norm = _mov_sup.normal_superficie
		var dir_tan = dir_j.slide(norm)
		if dir_tan.length_squared() > 0.01 and _visual:
			var dir_local = global_transform.basis.inverse() * dir_tan.normalized()
			var ang_obj = atan2(-dir_local.x, -dir_local.z) + PI
			_visual.rotation.y = ang_obj


func _mirar_hacia(pos: Vector3, factor: float = 1.0) -> void:
	if not _visual:
		return
	var dir = (pos - global_position)
	var esta_en_superficie = _mov_sup and _mov_sup.trepando

	if not esta_en_superficie:
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
			var angulo_obj = _calcular_angulo_hacia(dir)
			var vel = _nav.velocidad_giro if _nav else 6.0
			_visual.rotation.y = lerp_angle(_visual.rotation.y, angulo_obj, vel * factor * 0.05)
	else:
		var norm = _mov_sup.normal_superficie
		var dir_tan = dir.slide(norm)
		if dir_tan.length_squared() > 0.01:
			var dir_local = global_transform.basis.inverse() * dir_tan.normalized()
			var angulo_obj = atan2(-dir_local.x, -dir_local.z) + PI
			var vel = _nav.velocidad_giro if _nav else 6.0
			_visual.rotation.y = lerp_angle(_visual.rotation.y, angulo_obj, vel * factor * 0.05)


func _get_frente_visual() -> Vector3:
	if not _visual:
		return -global_transform.basis.z.normalized()
	var offset_y = _nav.offset_rotacion_y if (_nav and "offset_rotacion_y" in _nav) else 0.0
	if is_equal_approx(absf(offset_y), PI):
		return _visual.global_transform.basis.z.normalized()
	return -_visual.global_transform.basis.z.normalized()


func _calcular_angulo_hacia(dir_h: Vector3) -> float:
	var offset_y = _nav.offset_rotacion_y if (_nav and "offset_rotacion_y" in _nav) else 0.0
	return atan2(-dir_h.x, -dir_h.z) + offset_y


func _buscar_jugador() -> void:
	var j = get_tree().get_first_node_in_group("jugador") as CharacterBody3D
	if not j:
		j = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if j != _jugador:
		if _jugador and is_instance_valid(_jugador) and _jugador.has_signal("jugador_murio") and _jugador.jugador_murio.is_connected(_on_jugador_murio):
			_jugador.jugador_murio.disconnect(_on_jugador_murio)
		_jugador = j
		if _jugador and _jugador.has_signal("jugador_murio"):
			_jugador.jugador_murio.connect(_on_jugador_murio)


func _on_jugador_murio() -> void:
	if estado_actual == Estado.MUERTO:
		return
	_cancelar_ataque()
	if _mov_sup and _mov_sup.trepando:
		var p_salida = _encontrar_punto_trepar_mas_cercano(true)
		if p_salida:
			_punto_trepar_bajada = p_salida
			subfase_trepar = SubfaseTrepar.BAJANDO
			_mov_sup.ir_a_superficie(p_salida.global_position)
		else:
			_mov_sup.terminar_trepar()
	elif _nav:
		_nav.detener()
	cambiar_estado(Estado.PATRULLA)


func _buscar_animador(nodo: Node) -> Node:
	for hijo in nodo.get_children():
		if hijo.has_method("reproducir"):
			return hijo
		var sub = _buscar_animador(hijo)
		if sub:
			return sub
	return null


func _reproducir_animacion(nombre: String) -> void:
	if _animador and _animador.has_method("reproducir"):
		_animador.reproducir(nombre)


func _iniciar_telegrafia_visual() -> void:
	if not _visual or animaciones_reales:
		return
	if _tween_telegrafia and _tween_telegrafia.is_valid():
		_tween_telegrafia.kill()
	_tween_telegrafia = create_tween().set_parallel(true)
	_tween_telegrafia.tween_property(_visual, "position:z", _visual_pos_base.z + 0.25, tiempo_preparacion * 0.85)
	_tween_telegrafia.tween_property(_visual, "scale", _visual_scale_base * 1.08, tiempo_preparacion * 0.85)


func _restaurar_visual() -> void:
	if not _visual or animaciones_reales:
		return
	_visual.position = _visual_pos_base
	_visual.scale = _visual_scale_base


func _crear_indicador_ataque() -> void:
	_indicador_pivot = Node3D.new()
	_indicador_pivot.name = "IndicadorAtaquePivot"
	add_child(_indicador_pivot)

	_mesh_indicador = MeshInstance3D.new()
	_mesh_indicador.name = "MeshIndicador"

	var cyl := CylinderMesh.new()
	cyl.top_radius = alcance_golpe * 0.5
	cyl.bottom_radius = alcance_golpe * 0.5
	cyl.height = 0.04
	_mesh_indicador.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.45)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_indicador.material_override = mat

	_mesh_indicador.position = Vector3(0.0, 0.05, -alcance_golpe * 0.5)
	_indicador_pivot.add_child(_mesh_indicador)
	_indicador_pivot.visible = false


func _actualizar_transform_indicador_ataque() -> void:
	if not _indicador_pivot:
		return
	var esta_en_superficie = _mov_sup and _mov_sup.trepando
	if not esta_en_superficie:
		if _visual:
			_indicador_pivot.rotation.y = _visual.rotation.y
	else:
		if _jugador and is_instance_valid(_jugador):
			var dir_3d = (_jugador.global_position - global_position).normalized()
			var up_ref = _mov_sup.normal_superficie
			if absf(dir_3d.dot(up_ref)) > 0.95:
				up_ref = Vector3.RIGHT
			_indicador_pivot.global_transform = Transform3D(Basis.looking_at(dir_3d, up_ref), global_position)


func _crear_label_debug() -> void:
	_label_debug = Label3D.new()
	_label_debug.name = "DebugLabel3D"
	_label_debug.position = Vector3(0.0, altura_ojos + 0.6, 0.0)
	_label_debug.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_label_debug.pixel_size = 0.006
	_label_debug.font_size = 28
	_label_debug.outline_size = 6
	_label_debug.outline_modulate = Color(0.05, 0.03, 0.02, 1.0)
	add_child(_label_debug)


func _actualizar_label_debug() -> void:
	if not _label_debug:
		return
	match estado_actual:
		Estado.PATRULLA:
			_label_debug.text = "[ PATRULLA ]"
			_label_debug.modulate = Color(0.75, 0.9, 1.0)
		Estado.SOSPECHA:
			_label_debug.text = "[ SOSPECHA ]"
			_label_debug.modulate = Color(1.0, 0.85, 0.2)
		Estado.PERSECUCION:
			_label_debug.text = "[ PERSECUCIÓN ]"
			_label_debug.modulate = Color(1.0, 0.2, 0.2)
		Estado.BUSQUEDA:
			_label_debug.text = "[ BÚSQUEDA ]"
			_label_debug.modulate = Color(1.0, 0.55, 0.1)
		Estado.ATURDIDO:
			_label_debug.text = "[ ATURDIDO ]"
			_label_debug.modulate = Color(0.3, 0.9, 1.0)
		Estado.MUERTO:
			_label_debug.text = "[ MUERTO ]"
			_label_debug.modulate = Color(0.5, 0.5, 0.5)
		Estado.ATAQUE:
			match fase_ataque:
				FaseAtaque.PREPARACION:
					_label_debug.text = "[ ATAQUE: PREPARACIÓN ]"
					_label_debug.modulate = Color(1.0, 0.7, 0.1)
				FaseAtaque.GOLPE:
					_label_debug.text = "[ ATAQUE: GOLPE ]"
					_label_debug.modulate = Color(1.0, 0.1, 0.1)
				FaseAtaque.RECUPERACION:
					_label_debug.text = "[ ATAQUE: RECUPERACIÓN ]"
					_label_debug.modulate = Color(0.85, 0.5, 0.85)
				_:
					_label_debug.text = "[ ATAQUE ]"
					_label_debug.modulate = Color(1.0, 0.2, 0.2)
		Estado.TREPANDO:
			match subfase_trepar:
				SubfaseTrepar.SUBIENDO:
					_label_debug.text = "[ TREPANDO: SUBIENDO ]"
					_label_debug.modulate = Color(0.2, 0.95, 0.8)
				SubfaseTrepar.EN_SUPERFICIE:
					_label_debug.text = "[ TREPANDO: EN SUPERFICIE ]"
					_label_debug.modulate = Color(0.1, 1.0, 0.6)
				SubfaseTrepar.BAJANDO:
					_label_debug.text = "[ TREPANDO: BAJANDO ]"
					_label_debug.modulate = Color(0.4, 0.8, 1.0)
				_:
					_label_debug.text = "[ TREPANDO ]"
					_label_debug.modulate = Color(0.2, 0.95, 0.8)
		Estado.EMBOSCADA:
			match _fase_emboscada:
				0:
					_label_debug.text = "[ EMBOSCADA: ACECHANDO ]"
					_label_debug.modulate = Color(0.85, 0.4, 1.0)
				1:
					_label_debug.text = "[ EMBOSCADA: AVISO ]"
					_label_debug.modulate = Color(1.0, 0.6, 0.1)
				2:
					_label_debug.text = "[ EMBOSCADA: CAYENDO ]"
					_label_debug.modulate = Color(1.0, 0.2, 0.2)
				_:
					_label_debug.text = "[ EMBOSCADA ]"
					_label_debug.modulate = Color(0.85, 0.4, 1.0)
