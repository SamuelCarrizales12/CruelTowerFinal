class_name EnemigoAcechador
extends EnemigoIA

## Enemigo Acechador (basado en el modelo Coat).
## Comportamiento de "Ángel Llorón": solo se mueve y persigue si el jugador NO lo mira.
## Al ser enfocado por la cámara del jugador sin obstáculos, se congela por completo.

signal acechador_cerca(distancia: float)
signal congelado_cambiado(esta_congelado: bool)

@export_group("Acechador - Mecánicas")
@export var angulo_cono_camara: float = 70.0 ## Ángulo en grados respecto al frente de la cámara
@export var tiempo_histeresis_descongelar: float = 0.15 ## Tolerancia para evitar parpadeo en bordes
@export var distancia_aviso_cerca: float = 8.0 ## Rango para emitir señal de tensión cuando da la espalda
@export var tiempo_mirada_para_boost: float = 3.0 ## Tiempo continuo mirado para castigar exploit
@export var distancia_max_boost: float = 5.0 ## Distancia mínima requerida para acumular boost
@export var duracion_boost: float = 1.5 ## Duración del boost de velocidad al desviar la mirada
@export var factor_boost_velocidad: float = 1.3 ## +30% de velocidad tras mirada prolongada

# Estado de congelación
var esta_congelado: bool = false
var _timer_chequeo_mirada: float = 0.0
var _tiempo_sin_mirar: float = 0.0
var _tiempo_mirado_continuo: float = 0.0
var _boost_acumulado: bool = false
var _tiempo_restante_boost: float = 0.0
var _timer_aviso_cerca: float = 0.0


func _ready() -> void:
	# Valores por defecto específicos del Acechador
	vida_maxima = 150.0
	vel_persecucion = 4.0
	vel_patrulla = 1.8
	vel_busqueda = 2.2
	rango_vision = 18.0
	rango_oido = 4.0
	altura_ojos = 1.4
	dano = 25.0
	tiempo_preparacion = 0.3
	distancia_ataque = 1.8
	alcance_golpe = 2.2
	angulo_golpe = 60.0
	tiempo_recuperacion = 0.7
	cooldown_ataque = 1.0

	super._ready()


func _physics_process(delta: float) -> void:
	if estado_actual == Estado.MUERTO:
		return

	# Chequeo de visión de la cámara del jugador cada 0.05 s
	_timer_chequeo_mirada += delta
	if _timer_chequeo_mirada >= 0.05:
		var dt_mirada = _timer_chequeo_mirada
		_timer_chequeo_mirada = 0.0
		_actualizar_deteccion_mirada(dt_mirada)

	# Control de anti-exploit (mirada sostenida > 3 s a menos de 5 m)
	if esta_congelado and _jugador and is_instance_valid(_jugador) and not _jugador.get("muerto"):
		var dist_j = global_position.distance_to(_jugador.global_position)
		if dist_j <= distancia_max_boost:
			_tiempo_mirado_continuo += delta
			if _tiempo_mirado_continuo >= tiempo_mirada_para_boost:
				_boost_acumulado = true
		else:
			_tiempo_mirado_continuo = 0.0
	else:
		_tiempo_mirado_continuo = 0.0

	# Temporizador del boost de velocidad activo
	if _tiempo_restante_boost > 0.0:
		_tiempo_restante_boost -= delta
		if _tiempo_restante_boost <= 0.0:
			_tiempo_restante_boost = 0.0
			if estado_actual == Estado.PERSECUCION and _nav:
				_nav.velocidad = vel_persecucion

	# Aviso de cercanía a espaldas del jugador
	_timer_aviso_cerca += delta
	if _timer_aviso_cerca >= 0.2:
		_timer_aviso_cerca = 0.0
		_comprobar_aviso_cercania()

	# Lógica según estado de congelación y aturdimiento
	if estado_actual == Estado.ATURDIDO:
		_proceso_aturdido(delta)
	elif esta_congelado:
		_procesar_congelado(delta)
	else:
		# Aplicar velocidad aumentada si tiene boost
		if estado_actual == Estado.PERSECUCION and _nav:
			var vel_final = vel_persecucion * (factor_boost_velocidad if _tiempo_restante_boost > 0.0 else 1.0)
			_nav.velocidad = vel_final

		super._physics_process(delta)


# ==============================================================================
# MECÁNICA DE CONGELACIÓN (CÁLCULO DE MIRADA Y VISIBILIDAD)
# ==============================================================================

func _actualizar_deteccion_mirada(delta_interval: float) -> void:
	var mirado_ahora = _verificar_si_jugador_lo_mira()

	if mirado_ahora:
		_tiempo_sin_mirar = 0.0
		if not esta_congelado:
			_set_congelado(true)
	else:
		_tiempo_sin_mirar += delta_interval
		if _tiempo_sin_mirar >= tiempo_histeresis_descongelar:
			if esta_congelado:
				_set_congelado(false)


func _verificar_si_jugador_lo_mira() -> bool:
	if not _jugador or not is_instance_valid(_jugador) or _jugador.get("muerto"):
		return false

	var cam = get_viewport().get_camera_3d()
	if not cam:
		cam = _jugador.find_child("Camera3D", true, false) as Camera3D
	if not cam or not is_instance_valid(cam):
		return false

	var cam_fwd = -cam.global_transform.basis.z.normalized()
	var pos_ojos = global_position + Vector3(0.0, altura_ojos, 0.0)
	var pos_torso = global_position + Vector3(0.0, 0.85, 0.0)
	var umbral_dot = cos(deg_to_rad(angulo_cono_camara))

	# Comprobar si al menos la cabeza o el torso están en el cono y sin oclusión
	var visible_ojos = _punto_visible_desde_camara(cam, cam_fwd, pos_ojos, umbral_dot)
	if visible_ojos:
		return true

	var visible_torso = _punto_visible_desde_camara(cam, cam_fwd, pos_torso, umbral_dot)
	return visible_torso


func _punto_visible_desde_camara(cam: Camera3D, cam_fwd: Vector3, pt: Vector3, umbral_dot: float) -> bool:
	var vec = pt - cam.global_position
	var dist = vec.length()
	if dist < 0.1:
		return true

	var dir_norm = vec / dist
	var dot = cam_fwd.dot(dir_norm)

	# 1. Ángulo respecto al frente de la cámara
	if dot < umbral_dot:
		return false

	# 2. Raycast de oclusión: verificar si hay pared entre la cámara y el punto
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(cam.global_position, pt)
	query.collision_mask = 1 # Capa 1 (Paredes del mundo)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var exclude_list: Array[RID] = [get_rid()]
	if _jugador:
		exclude_list.append(_jugador.get_rid())
	query.exclude = exclude_list

	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return true

	# Si choca con el propio enemigo o un hijo, está despejado
	if hit.collider == self or is_ancestor_of(hit.collider):
		return true

	return false


func _set_congelado(congelar: bool) -> void:
	if esta_congelado == congelar:
		return

	esta_congelado = congelar
	congelado_cambiado.emit(esta_congelado)

	if esta_congelado:
		# 1. Detención en seco instantánea (sin deslizarse, salvo que esté aturdido por disparo)
		if estado_actual != Estado.ATURDIDO:
			velocity = Vector3.ZERO
		if _nav:
			_nav.detener()

		# 2. Pausar animación procedural y congelar en pose neutra
		if _visual:
			_visual.set_process(false)
			_visual.position = _visual_pos_base
			_visual.rotation.z = 0.0
			_visual.scale = _visual_scale_base
		if _animador and _animador != _visual:
			_animador.set_process(false)

		# 3. No puede iniciar ni preparar ataques estando congelado
		if estado_actual == Estado.ATAQUE:
			if fase_ataque == FaseAtaque.PREPARACION:
				_cancelar_ataque()
				cambiar_estado(Estado.PERSECUCION)

		_actualizar_label_debug()
	else:
		# 1. Reanudar animación procedural
		if _visual:
			_visual.set_process(true)
		if _animador and _animador != _visual:
			_animador.set_process(true)

		# 2. Si acumuló boost por mirada fija, activar impulso (+30% por 1.5 s)
		if _boost_acumulado:
			_boost_acumulado = false
			_tiempo_restante_boost = duracion_boost

		_actualizar_label_debug()

		# 3. Retomar navegación según estado actual
		if estado_actual == Estado.PERSECUCION:
			if _nav:
				_nav.velocidad = vel_persecucion * (factor_boost_velocidad if _tiempo_restante_boost > 0.0 else 1.0)
				if _jugador and is_instance_valid(_jugador):
					_nav.ir_a(_jugador.global_position)
			_reproducir_animacion("correr")
		elif estado_actual == Estado.PATRULLA:
			if _nav:
				_nav.velocidad = vel_patrulla
			_reproducir_animacion("caminar")
			_ir_a_siguiente_patrulla()
		elif estado_actual == Estado.BUSQUEDA:
			if _nav:
				_nav.velocidad = vel_busqueda
			_reproducir_animacion("caminar")


func _procesar_congelado(delta: float) -> void:
	# Mantener quieto en horizontal
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if _nav:
		_nav.detener()

	# Reducción de cooldown de ataque
	if _timer_cooldown_ataque > 0.0:
		_timer_cooldown_ataque -= delta

	# Comprobación de visión periódica para mantener tracking
	_timer_vision += delta
	if _timer_vision >= 0.1:
		_timer_vision = 0.0
		_jugador_en_vision = _verificar_vision()
		if _jugador_en_vision and _jugador:
			_ultima_posicion_jugador = _jugador.global_position

	# Si ya estaba en la fase GOLPE o RECUPERACION, permitir completarlo
	if estado_actual == Estado.ATAQUE:
		if fase_ataque == FaseAtaque.GOLPE or fase_ataque == FaseAtaque.RECUPERACION:
			_proceso_ataque(delta)
		elif fase_ataque == FaseAtaque.PREPARACION:
			_cancelar_ataque()
			cambiar_estado(Estado.PERSECUCION)


func _comprobar_aviso_cercania() -> void:
	if estado_actual == Estado.MUERTO or not _jugador or not is_instance_valid(_jugador) or _jugador.get("muerto"):
		return

	var dist = global_position.distance_to(_jugador.global_position)
	if dist <= distancia_aviso_cerca:
		var cam = get_viewport().get_camera_3d()
		if not cam and _jugador:
			cam = _jugador.find_child("Camera3D", true, false) as Camera3D
		if cam:
			var cam_fwd = -cam.global_transform.basis.z.normalized()
			var dir_cam_enemigo = (global_position - cam.global_position).normalized()
			# Si la cámara apunta en sentido contrario (el jugador le da la espalda)
			if cam_fwd.dot(dir_cam_enemigo) < 0.2:
				acechador_cerca.emit(dist)


# ==============================================================================
# COMBATE Y RECEPCIÓN DE DAÑO
# ==============================================================================

func _proceso_aturdido(delta: float) -> void:
	# Amortiguar velocidad por retroceso (knockback suave de ~1 m)
	velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
	velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	_timer_estado -= delta
	if _timer_estado <= 0.0:
		if _nav:
			_nav.set_physics_process(true)
		if _jugador_en_vision or _posicion_sospecha != Vector3.ZERO:
			cambiar_estado(Estado.PERSECUCION)
		else:
			cambiar_estado(Estado.BUSQUEDA)


func recibir_dano(cantidad: float, origen_o_dir: Vector3 = Vector3.ZERO, atacante: Node = null) -> void:
	if estado_actual == Estado.MUERTO:
		return

	# 1. Restar vida
	vida_actual = maxf(vida_actual - cantidad, 0.0)

	# 2. Cancelar preparación de ataque si estaba en curso
	if estado_actual == Estado.ATAQUE:
		_cancelar_ataque()

	# 3. Muerte si la vida llega a 0
	if vida_actual <= 0.0:
		if _nav:
			_nav.set_physics_process(false)
		morir()
		return

	# 4. Determinar atacante y dirección
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

	# 5. Desactivar temporalmente la física de _nav para permitir el retroceso libre
	if _nav:
		_nav.set_physics_process(false)

	# 6. Aturdimiento de 0.8 s
	aturdir(0.8)

	# 7. Retroceso de ~1 m
	var dir_kb = Vector3.ZERO
	if pos_atacante != Vector3.ZERO:
		dir_kb = (global_position - pos_atacante)
	elif origen_o_dir != Vector3.ZERO:
		dir_kb = origen_o_dir if origen_o_dir.length_squared() <= 1.5 else (global_position - origen_o_dir)
	else:
		dir_kb = global_transform.basis.z

	dir_kb.y = 0.0
	if dir_kb.length_squared() > 0.001:
		dir_kb = dir_kb.normalized()
	else:
		dir_kb = Vector3.BACK

	velocity = dir_kb * 5.0

	# 8. Alertar comportamiento si estaba en patrulla o sospecha
	if estado_actual == Estado.PATRULLA or estado_actual == Estado.SOSPECHA:
		if pos_atacante != Vector3.ZERO:
			alertar(pos_atacante)
		if grupo_alerta != "":
			get_tree().call_group(grupo_alerta, "alertar", pos_atacante)


# ==============================================================================
# DEPURACIÓN VISUAL
# ==============================================================================

func _actualizar_label_debug() -> void:
	if not _label_debug:
		return

	if esta_congelado and estado_actual != Estado.MUERTO and estado_actual != Estado.ATURDIDO:
		_label_debug.text = "[ CONGELADO ]"
		_label_debug.modulate = Color(0.4, 0.85, 1.0)
		return

	super._actualizar_label_debug()
