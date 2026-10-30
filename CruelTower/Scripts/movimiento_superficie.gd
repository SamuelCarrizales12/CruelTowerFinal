class_name MovimientoSuperficie
extends Node

## Componente reutilizable para locomoción en paredes y techos (hermano de MovimientoNav).
## Permite a un CharacterBody3D adherirse a superficies con el grupo "trepable",
## transicionar suavemente por esquinas cóncavas y convexas, y volver al suelo con seguridad.

signal subio_a_pared
signal llego_al_techo
signal volvio_al_suelo
signal destino_superficie_alcanzado

enum ModoSuperficie {
	SUELO,
	PARED,
	TECHO
}

@export_group("Locomoción en Superficie")
@export var velocidad_trepar: float = 2.0
@export var velocidad_giro_esquina: float = 8.0
@export var distancia_adherencia: float = 0.3
@export var pausar_padre: bool = false
@export var animacion_bloqueada: bool = false
var nombre_anim_avance: String = "caminar"

@export_group("Geometría y Colisión")
@export var radio_cuerpo: float = 0.45
@export var grupo_trepable: String = "trepable"
@export_flags_3d_physics var mascara_colision: int = 1

@export_group("Depuración")
@export var dibujar_debug: bool = false:
	set(valor):
		dibujar_debug = valor
		_actualizar_visibilidad_debug()

var normal_superficie: Vector3 = Vector3.UP
var trepando: bool = false
var modo_actual: ModoSuperficie = ModoSuperficie.SUELO

var _padre: CharacterBody3D = null
var _visual: Node3D = null
var _animador: Node = null
var _mov_nav: Node = null

var _escala_visual_base: Vector3 = Vector3(0.075, 0.075, 0.075)
var _offset_rotacion_y: float = PI
var _padre_procesaba_ia: bool = true
var _nav_procesaba_fisica: bool = true

# Navegación directa sobre superficie
var _tiene_destino: bool = false
var _destino_actual: Vector3 = Vector3.ZERO
var _cola_destinos: Array[Vector3] = []
var _bajar_al_llegar: bool = false
var _ultima_dir_tangente: Vector3 = Vector3.FORWARD

# Control de adherencia y esquinas
var _ultimo_punto_adherencia: Vector3 = Vector3.ZERO
var _frames_sin_superficie: int = 0
var _en_giro_convexo: bool = false
var _progreso_convexo: float = 0.0
var _arista_convexa: Vector3 = Vector3.ZERO
var _pos_inicio_convexo: Vector3 = Vector3.ZERO
var _pos_fin_convexo: Vector3 = Vector3.ZERO
var _quat_inicio_convexo: Quaternion = Quaternion.IDENTITY
var _quat_fin_convexo: Quaternion = Quaternion.IDENTITY
var _dir_salida_convexa: Vector3 = Vector3.ZERO
var _cooldown_convexo: float = 0.0

# Fase de retorno seguro al suelo
var _aterrizando: bool = false

# Visualización de raycasts de depuración
var _debug_mesh_instance: MeshInstance3D = null
var _debug_immediate_mesh: ImmediateMesh = null
var _debug_material: StandardMaterial3D = null
var _lineas_debug: Array[Dictionary] = []


func _ready() -> void:
	_padre = get_parent() as CharacterBody3D
	if not _padre:
		push_warning("MovimientoSuperficie: El nodo padre debe ser un CharacterBody3D.")
		set_physics_process(false)
		return

	_visual = _padre.get_node_or_null("Visual") as Node3D
	if not _visual:
		_visual = _padre.find_child("Visual", true, false) as Node3D

	if _visual:
		_escala_visual_base = _visual.scale
		if _visual.has_method("reproducir"):
			_animador = _visual
		else:
			_animador = _buscar_nodo_con_metodo(_visual, "reproducir")

	_mov_nav = _padre.get_node_or_null("MovimientoNav")
	if not _mov_nav:
		_mov_nav = _padre.find_child("MovimientoNav", true, false)
	if _mov_nav and "offset_rotacion_y" in _mov_nav:
		_offset_rotacion_y = _mov_nav.offset_rotacion_y

	_crear_nodo_debug()
	# Inactivo por defecto para no alterar ningún comportamiento del enemigo en el suelo
	set_physics_process(false)


func _process(_delta: float) -> void:
	if not dibujar_debug or not _padre:
		return
	if not trepando and not _aterrizando:
		_lineas_debug.clear()
		var origen_n: Vector3 = _padre.global_position + Vector3.UP * (radio_cuerpo * 1.4)
		_registrar_linea_debug(origen_n, origen_n + Vector3.UP * 0.9, Color(0.1, 0.95, 1.0))
		_renderizar_debug()


# ==============================================================================
# INTERFAZ PÚBLICA REQUERIDA
# ==============================================================================

func iniciar_trepar(normal: Vector3) -> void:
	if not _padre:
		return

	var n_limpia: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	_aterrizando = false
	_en_giro_convexo = false
	_frames_sin_superficie = 0
	_cooldown_convexo = 0.15

	if not trepando:
		# Pausar IA terrestre y NavigationAgent mientras trepa
		_padre_procesaba_ia = _padre.is_physics_processing()
		if pausar_padre:
			_padre.set_physics_process(false)

		if _mov_nav:
			_nav_procesaba_fisica = _mov_nav.is_physics_processing()
			if _mov_nav.has_method("detener"):
				_mov_nav.detener()
			_mov_nav.set_physics_process(false)

		# Transferir orientación horizontal actual de Visual a la base CharacterBody3D
		# manteniendo Visual exactamente con escala 0.075 y rotación 180° en Y.
		var frente_mundo: Vector3 = _obtener_frente_visual_mundo()
		frente_mundo.y = 0.0
		if frente_mundo.length_squared() < 0.0001:
			frente_mundo = -_padre.global_transform.basis.z
			frente_mundo.y = 0.0
		if frente_mundo.length_squared() < 0.0001:
			frente_mundo = Vector3.FORWARD
		frente_mundo = frente_mundo.normalized()

		var centro_esfera: Vector3 = _padre.global_position + _padre.global_transform.basis.y.normalized() * radio_cuerpo
		var basis_inicial: Basis = _construir_basis_desde_up_y_frente(Vector3.UP, frente_mundo)
		_padre.global_transform.basis = basis_inicial
		_padre.global_position = centro_esfera - basis_inicial.y * radio_cuerpo
		_fijar_transform_visual_trepado()

	trepando = true
	normal_superficie = n_limpia
	_ultimo_punto_adherencia = _padre.global_position
	_padre.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_padre.up_direction = normal_superficie

	# Calcular dirección tangente inicial proyectando la intención previa (subir si viene del suelo)
	var up_previo: Vector3 = _padre.global_transform.basis.y.normalized()
	var frente_previo: Vector3 = (-_padre.global_transform.basis.z).normalized()
	var q_trans: Quaternion = _quat_entre_vectores(up_previo, normal_superficie, _padre.global_transform.basis.x.normalized())
	var tangente_inicial: Vector3 = (q_trans * frente_previo).slide(normal_superficie)
	if tangente_inicial.length_squared() > 0.0001:
		_ultima_dir_tangente = tangente_inicial.normalized()

	_actualizar_modo_y_senales(normal_superficie)
	set_physics_process(true)


func terminar_trepar() -> void:
	if not _padre:
		return
	if not trepando and not _aterrizando:
		return

	trepando = false
	_tiene_destino = false
	_cola_destinos.clear()
	_bajar_al_llegar = false
	_en_giro_convexo = false
	_aterrizando = true

	_padre.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_padre.up_direction = Vector3.UP
	normal_superficie = Vector3.UP
	set_physics_process(true)


func ir_a_superficie(destino: Vector3) -> void:
	_cola_destinos.clear()
	_bajar_al_llegar = false
	_destino_actual = destino
	_tiene_destino = true


func seguir_ruta_superficie(puntos: Array[Vector3], terminar_al_final: bool = false) -> void:
	if puntos.is_empty():
		return
	_cola_destinos = puntos.duplicate()
	_bajar_al_llegar = terminar_al_final
	_destino_actual = _cola_destinos.pop_front()
	_tiene_destino = true


func detener_en_superficie() -> void:
	_tiene_destino = false
	_cola_destinos.clear()
	_bajar_al_llegar = false
	if _padre and trepando:
		_padre.velocity = Vector3.ZERO
	_reproducir_anim("idle", 1.0)


func obtener_modo_texto() -> String:
	if not trepando:
		return "SUELO"
	if normal_superficie.y < -0.65:
		return "TECHO"
	elif absf(normal_superficie.y) <= 0.65:
		return "PARED"
	else:
		return "TECHO (SUP.)"


func alternar_debug_rayos() -> bool:
	dibujar_debug = not dibujar_debug
	return dibujar_debug


# ==============================================================================
# BUCLE FÍSICO PRINCIPAL
# ==============================================================================

func _physics_process(delta: float) -> void:
	if not _padre:
		return

	_lineas_debug.clear()

	if _aterrizando:
		_procesar_aterrizaje(delta)
		_renderizar_debug()
		return

	if not trepando:
		set_physics_process(false)
		_renderizar_debug()
		return

	# Asegurar invariante de Visual (escala 0.075 y rotación 180° en Y)
	_fijar_transform_visual_trepado()

	if _cooldown_convexo > 0.0:
		_cooldown_convexo -= delta

	# Si está ejecutando el giro alrededor de un borde convexo
	if _en_giro_convexo:
		_procesar_giro_convexo(delta)
		_renderizar_debug()
		return

	var space: PhysicsDirectSpaceState3D = _padre.get_world_3d().direct_space_state
	var basis_actual: Basis = _padre.global_transform.basis
	if not basis_actual.is_orthonormal():
		basis_actual = basis_actual.orthonormalized()
		_padre.global_transform.basis = basis_actual

	var up_cuerpo: Vector3 = basis_actual.y.normalized()
	var centro_cuerpo: Vector3 = _padre.global_position + up_cuerpo * radio_cuerpo

	# 1. Determinar dirección tangente de avance sobre la superficie actual
	var dir_avance: Vector3 = _calcular_direccion_avance(centro_cuerpo)
	var en_movimiento: bool = dir_avance.length_squared() > 0.0001
	var dir_frente_rayo: Vector3 = dir_avance if en_movimiento else (-basis_actual.z).slide(normal_superficie).normalized()
	if dir_frente_rayo.length_squared() < 0.0001:
		dir_frente_rayo = -basis_actual.z.normalized()

	# 2. RAYO DE ESQUINA CÓNCAVA (hacia adelante desde el centro del cuerpo)
	var largo_frente: float = radio_cuerpo + distancia_adherencia
	var origen_frente: Vector3 = centro_cuerpo
	var fin_frente: Vector3 = origen_frente + dir_frente_rayo * largo_frente
	var hit_frente: Dictionary = _lanzar_rayo(space, origen_frente, fin_frente)

	_registrar_linea_debug(origen_frente, hit_frente.get("position", fin_frente),
		Color(1.0, 0.55, 0.0) if not hit_frente.is_empty() else Color(1.0, 0.9, 0.1))

	if not hit_frente.is_empty() and en_movimiento:
		var col_frente: Object = hit_frente["collider"]
		var norm_frente: Vector3 = (hit_frente["normal"] as Vector3).normalized()
		if _es_trepable(col_frente):
			if norm_frente.dot(normal_superficie) < 0.85:
				# Esquina cóncava hacia otra superficie trepable (ej. Pared -> Techo)
				_cambiar_normal_superficie(norm_frente, hit_frente["position"])
				dir_avance = _calcular_direccion_avance(centro_cuerpo)
				en_movimiento = dir_avance.length_squared() > 0.0001
		elif norm_frente.y > 0.7 and dir_frente_rayo.y < -0.25:
			# Llegó bajando por la pared hasta chocar con el suelo normal -> volver al suelo
			terminar_trepar()
			_procesar_aterrizaje(delta)
			_renderizar_debug()
			return

	# 3. RAYO DE ESQUINA CONVEXA (adelante y abajo + rayo envolvente bajo el borde)
	if en_movimiento and _cooldown_convexo <= 0.0:
		var dist_sonda_adelante: float = radio_cuerpo + 0.12
		var punto_adelante: Vector3 = centro_cuerpo + dir_frente_rayo * dist_sonda_adelante
		var largo_abajo: float = radio_cuerpo + distancia_adherencia + 0.30
		var fin_adelante_abajo: Vector3 = punto_adelante - normal_superficie * largo_abajo
		var hit_acantilado: Dictionary = _lanzar_rayo(space, punto_adelante, fin_adelante_abajo)

		_registrar_linea_debug(punto_adelante, hit_acantilado.get("position", fin_adelante_abajo),
			Color(0.85, 0.25, 1.0))

		if hit_acantilado.is_empty():
			# No hay superficie delante: lanzar rayo envolvente hacia atrás bajo el borde
			var punto_bajo_borde: Vector3 = punto_adelante - normal_superficie * (radio_cuerpo + 0.24)
			var fin_envolvente: Vector3 = punto_bajo_borde - dir_frente_rayo * (dist_sonda_adelante + 0.45)
			var hit_envolvente: Dictionary = _lanzar_rayo(space, punto_bajo_borde, fin_envolvente)

			_registrar_linea_debug(punto_bajo_borde, hit_envolvente.get("position", fin_envolvente),
				Color(1.0, 0.15, 0.75))

			if not hit_envolvente.is_empty() and _es_trepable(hit_envolvente["collider"]):
				var norm_env: Vector3 = (hit_envolvente["normal"] as Vector3).normalized()
				if norm_env.dot(normal_superficie) < 0.75:
					var arista: Vector3 = _calcular_arista_convexa(
						_padre.global_position,
						_ultimo_punto_adherencia,
						normal_superficie,
						hit_envolvente["position"],
						norm_env
					)
					var dist_pies_a_arista: float = (_padre.global_position - arista).dot(dir_frente_rayo)
					# Iniciar el giro convexo justo cuando los pies alcanzan el borde
					if dist_pies_a_arista >= -0.03:
						_iniciar_giro_convexo(arista, norm_env)
						_procesar_giro_convexo(delta)
						_renderizar_debug()
						return

	# 4. RAYO DE ADHERENCIA ("pegarse": hacia -normal desde el centro del cuerpo)
	var largo_adherencia: float = radio_cuerpo + distancia_adherencia + 0.35
	var fin_adherencia: Vector3 = centro_cuerpo - normal_superficie * largo_adherencia
	var hit_adherencia: Dictionary = _lanzar_rayo(space, centro_cuerpo, fin_adherencia)

	# Si el rayo sobre -normal_superficie falla durante una interpolación, probar sobre -up_cuerpo
	if hit_adherencia.is_empty():
		var fin_alt: Vector3 = centro_cuerpo - up_cuerpo * largo_adherencia
		hit_adherencia = _lanzar_rayo(space, centro_cuerpo, fin_alt)

	_registrar_linea_debug(centro_cuerpo, hit_adherencia.get("position", fin_adherencia),
		Color(0.15, 1.0, 0.35) if not hit_adherencia.is_empty() else Color(1.0, 0.15, 0.15))

	var vel_adherencia: Vector3 = Vector3.ZERO
	if not hit_adherencia.is_empty() and _es_trepable(hit_adherencia["collider"]):
		_frames_sin_superficie = 0
		var pos_contacto: Vector3 = hit_adherencia["position"]
		var norm_contacto: Vector3 = (hit_adherencia["normal"] as Vector3).normalized()
		_ultimo_punto_adherencia = pos_contacto

		if norm_contacto.dot(normal_superficie) > 0.5:
			_cambiar_normal_superficie(norm_contacto, pos_contacto)

		# Corrección elástica suave de distancia a la superficie + leve presión constante
		var dist_centro_plano: float = (centro_cuerpo - pos_contacto).dot(normal_superficie)
		var dist_deseada: float = radio_cuerpo + 0.015
		var error_dist: float = dist_deseada - dist_centro_plano
		vel_adherencia = normal_superficie * clampf(error_dist * 16.0, -5.0, 5.0) - normal_superficie * 0.25
	else:
		_frames_sin_superficie += 1
		vel_adherencia = -normal_superficie * 1.5
		if _frames_sin_superficie >= 8:
			# Perdió la superficie por completo -> caer al suelo de forma segura
			terminar_trepar()
			_procesar_aterrizaje(delta)
			_renderizar_debug()
			return

	# 5. ORIENTACIÓN SUAVE DE LA BASE (Quaternion slerp preservando el centro de colisión)
	var basis_objetivo: Basis = _construir_basis_objetivo(basis_actual, normal_superficie, dir_avance)
	var q_actual: Quaternion = basis_actual.get_rotation_quaternion()
	var q_objetivo: Quaternion = basis_objetivo.get_rotation_quaternion()
	var peso_giro: float = clampf(velocidad_giro_esquina * delta, 0.0, 1.0)
	var nueva_basis: Basis = Basis(q_actual.slerp(q_objetivo, peso_giro)).orthonormalized()

	_padre.global_transform.basis = nueva_basis
	_padre.global_position = centro_cuerpo - nueva_basis.y * radio_cuerpo
	_padre.up_direction = normal_superficie

	# 6. MOVIMIENTO Y ANIMACIÓN
	if not animacion_bloqueada:
		if en_movimiento:
			_padre.velocity = dir_avance * velocidad_trepar + vel_adherencia
			var escala_vel_anim: float = clampf(velocidad_trepar / 1.5, 0.7, 2.0)
			_reproducir_anim(nombre_anim_avance, escala_vel_anim)
		else:
			_padre.velocity = vel_adherencia
			_reproducir_anim("idle", 1.0)
	else:
		if en_movimiento:
			_padre.velocity = dir_avance * velocidad_trepar + vel_adherencia
		else:
			_padre.velocity = vel_adherencia

	_padre.move_and_slide()

	# Vector normal de depuración (flecha cian desde el lomo)
	var origen_normal_dbg: Vector3 = _padre.global_position + nueva_basis.y * (radio_cuerpo * 1.4)
	_registrar_linea_debug(origen_normal_dbg, origen_normal_dbg + normal_superficie * 0.9, Color(0.1, 0.95, 1.0))
	_renderizar_debug()


# ==============================================================================
# NAVEGACIÓN DIRECTA EN SUPERFICIE Y GIRO CONVEXO
# ==============================================================================

func _calcular_direccion_avance(centro_cuerpo: Vector3) -> Vector3:
	if not _tiene_destino:
		return Vector3.ZERO

	var pos_pies: Vector3 = _padre.global_position
	var delta_pies: Vector3 = _destino_actual - pos_pies
	var dist_directa: float = delta_pies.length()

	# Verificar llegada al punto objetivo
	if dist_directa <= 0.35:
		if not _cola_destinos.is_empty():
			_destino_actual = _cola_destinos.pop_front()
			delta_pies = _destino_actual - pos_pies
		else:
			_tiene_destino = false
			if _bajar_al_llegar:
				_bajar_al_llegar = false
				terminar_trepar()
			destino_superficie_alcanzado.emit()
			return Vector3.ZERO

	# Proyectar hacia el destino sobre el plano tangente de la superficie actual
	var proyeccion: Vector3 = delta_pies.slide(normal_superficie)
	if proyeccion.length_squared() > 0.02:
		_ultima_dir_tangente = proyeccion.normalized()
		return _ultima_dir_tangente

	# Si el destino está en otra cara perpendicular (proyección tangente casi nula pero lejos),
	# mantener la dirección tangente previa para alcanzar la esquina que conecta ambas caras.
	var proy_previa: Vector3 = _ultima_dir_tangente.slide(normal_superficie)
	if proy_previa.length_squared() > 0.001:
		_ultima_dir_tangente = proy_previa.normalized()
		return _ultima_dir_tangente

	var frente_actual: Vector3 = (-_padre.global_transform.basis.z).slide(normal_superficie)
	if frente_actual.length_squared() > 0.001:
		return frente_actual.normalized()

	return Vector3.ZERO


func _iniciar_giro_convexo(arista: Vector3, nueva_normal: Vector3) -> void:
	var normal_anterior: Vector3 = normal_superficie
	var dir_salida: Vector3 = (-normal_anterior).slide(nueva_normal)
	if dir_salida.length_squared() < 0.0001:
		dir_salida = (-_padre.global_transform.basis.z).slide(nueva_normal)
	dir_salida = dir_salida.normalized()

	_en_giro_convexo = true
	_progreso_convexo = 0.0
	_arista_convexa = arista
	_dir_salida_convexa = dir_salida
	_ultima_dir_tangente = dir_salida

	_pos_inicio_convexo = _padre.global_position
	_pos_fin_convexo = arista + dir_salida * 0.18 + nueva_normal * 0.02

	var basis_ini: Basis = _padre.global_transform.basis.orthonormalized()
	var basis_fin: Basis = _construir_basis_desde_up_y_frente(nueva_normal, dir_salida)
	_quat_inicio_convexo = basis_ini.get_rotation_quaternion()
	_quat_fin_convexo = basis_fin.get_rotation_quaternion()

	_cambiar_normal_superficie(nueva_normal, arista)


func _procesar_giro_convexo(delta: float) -> void:
	# Pivotar alrededor de la arista convexa manteniendo los pies plantados en el borde
	var vel_angular: float = maxf(velocidad_giro_esquina * 0.55, 2.5)
	_progreso_convexo = minf(_progreso_convexo + vel_angular * delta, 1.0)

	var q_interp: Quaternion = _quat_inicio_convexo.slerp(_quat_fin_convexo, _progreso_convexo)
	var nueva_basis: Basis = Basis(q_interp).orthonormalized()
	_padre.global_transform.basis = nueva_basis
	_padre.up_direction = normal_superficie

	var punto_pivote_arco: Vector3 = _arista_convexa + nueva_basis.y * 0.03
	var pos_objetivo: Vector3
	if _progreso_convexo < 0.72:
		var t_pivote: float = clampf(_progreso_convexo / 0.35, 0.0, 1.0)
		pos_objetivo = _pos_inicio_convexo.lerp(punto_pivote_arco, t_pivote)
	else:
		var t_salida: float = clampf((_progreso_convexo - 0.72) / 0.28, 0.0, 1.0)
		pos_objetivo = punto_pivote_arco.lerp(_pos_fin_convexo, t_salida)

	if delta > 0.0001:
		_padre.velocity = (pos_objetivo - _padre.global_position) / delta
	_padre.move_and_slide()

	var escala_vel_anim: float = clampf(velocidad_trepar / 1.5, 0.7, 2.0)
	_reproducir_anim("caminar", escala_vel_anim)

	var origen_normal_dbg: Vector3 = _padre.global_position + nueva_basis.y * (radio_cuerpo * 1.4)
	_registrar_linea_debug(origen_normal_dbg, origen_normal_dbg + normal_superficie * 0.9, Color(0.1, 0.95, 1.0))
	_registrar_linea_debug(_arista_convexa, _pos_fin_convexo, Color(1.0, 0.2, 0.8))

	if _progreso_convexo >= 1.0:
		_en_giro_convexo = false
		_cooldown_convexo = 0.20
		_ultimo_punto_adherencia = _padre.global_position


# ==============================================================================
# ATERRIZAJE SEGURO Y RESTAURACIÓN DE GRAVEDAD NORMAL
# ==============================================================================

func _procesar_aterrizaje(delta: float) -> void:
	var basis_actual: Basis = _padre.global_transform.basis.orthonormalized()
	var centro_esfera: Vector3 = _padre.global_position + basis_actual.y * radio_cuerpo

	# Transportar el frente actual al plano horizontal del suelo
	var q_enderezado: Quaternion = _quat_entre_vectores(basis_actual.y, Vector3.UP, basis_actual.x)
	var frente_h: Vector3 = q_enderezado * (-basis_actual.z)
	frente_h.y = 0.0
	if frente_h.length_squared() < 0.0001:
		frente_h = Vector3.FORWARD
	frente_h = frente_h.normalized()

	var basis_suelo: Basis = _construir_basis_desde_up_y_frente(Vector3.UP, frente_h)
	var q_actual: Quaternion = basis_actual.get_rotation_quaternion()
	var q_suelo: Quaternion = basis_suelo.get_rotation_quaternion()
	var peso: float = clampf(velocidad_giro_esquina * 1.2 * delta, 0.0, 1.0)
	var nueva_basis: Basis = Basis(q_actual.slerp(q_suelo, peso)).orthonormalized()

	_padre.global_transform.basis = nueva_basis
	_padre.global_position = centro_esfera - nueva_basis.y * radio_cuerpo

	# Aplicar gravedad normal de CharacterBody3D en modo GROUNDED
	if not _padre.is_on_floor():
		_padre.velocity += _padre.get_gravity() * delta
		# Leve empuje horizontal para despegarse limpiamente de la base de la pared
		_padre.velocity.x = move_toward(_padre.velocity.x, frente_h.x * 0.8, 6.0 * delta)
		_padre.velocity.z = move_toward(_padre.velocity.z, frente_h.z * 0.8, 6.0 * delta)
	else:
		_padre.velocity.x = move_toward(_padre.velocity.x, 0.0, 10.0 * delta)
		_padre.velocity.z = move_toward(_padre.velocity.z, 0.0, 10.0 * delta)
		if _padre.velocity.y < 0.0:
			_padre.velocity.y = 0.0

	_padre.move_and_slide()

	var alineado_vertical: bool = nueva_basis.y.dot(Vector3.UP) >= 0.998
	if _padre.is_on_floor() and alineado_vertical:
		# Restaurar convención terrestre: CharacterBody3D sin rotación y giro en Visual.rotation.y
		var frente_final: Vector3 = -nueva_basis.z
		frente_final.y = 0.0
		if frente_final.length_squared() < 0.0001:
			frente_final = Vector3.FORWARD
		frente_final = frente_final.normalized()

		_padre.global_transform.basis = Basis.IDENTITY
		if _visual:
			_visual.position = Vector3.ZERO
			_visual.scale = _escala_visual_base
			var yaw_visual: float = atan2(-frente_final.x, -frente_final.z) + _offset_rotacion_y
			_visual.rotation = Vector3(0.0, yaw_visual, 0.0)

		_aterrizando = false
		modo_actual = ModoSuperficie.SUELO
		normal_superficie = Vector3.UP
		_reproducir_anim("idle", 1.0)

		# Reactivar MovimientoNav y EnemigoIA
		if _mov_nav:
			_mov_nav.set_physics_process(_nav_procesaba_fisica)
		if pausar_padre and _padre_procesaba_ia and _padre:
			_padre.set_physics_process(true)

		set_physics_process(false)
		volvio_al_suelo.emit()


# ==============================================================================
# UTILIDADES MATEMÁTICAS Y DE FÍSICA
# ==============================================================================

func _cambiar_normal_superficie(nueva_normal: Vector3, punto_ref: Vector3) -> void:
	normal_superficie = nueva_normal.normalized()
	_ultimo_punto_adherencia = punto_ref
	if _padre:
		_padre.up_direction = normal_superficie
	_actualizar_modo_y_senales(normal_superficie)


func _actualizar_modo_y_senales(n: Vector3) -> void:
	var nuevo_modo: ModoSuperficie
	if n.y < -0.65:
		nuevo_modo = ModoSuperficie.TECHO
	elif absf(n.y) <= 0.65:
		nuevo_modo = ModoSuperficie.PARED
	else:
		nuevo_modo = ModoSuperficie.SUELO

	if nuevo_modo != modo_actual:
		modo_actual = nuevo_modo
		match nuevo_modo:
			ModoSuperficie.PARED:
				subio_a_pared.emit()
			ModoSuperficie.TECHO:
				llego_al_techo.emit()


func _lanzar_rayo(space: PhysicsDirectSpaceState3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(desde, hasta, mascara_colision)
	query.exclude = [_padre.get_rid()]
	return space.intersect_ray(query)


func _es_trepable(collider: Object) -> bool:
	if not collider or not (collider is Node):
		return false
	var nodo := collider as Node
	if nodo.is_in_group(grupo_trepable):
		return true
	if nodo.get_parent() and nodo.get_parent().is_in_group(grupo_trepable):
		return true
	return false


func _construir_basis_objetivo(basis_actual: Basis, n: Vector3, dir_mov: Vector3) -> Basis:
	var up_actual: Vector3 = basis_actual.y.normalized()
	var frente_actual: Vector3 = (-basis_actual.z).normalized()
	var f_objetivo: Vector3

	if dir_mov.length_squared() > 0.0001:
		f_objetivo = dir_mov.slide(n).normalized()
	else:
		var q_tilt: Quaternion = _quat_entre_vectores(up_actual, n, basis_actual.x.normalized())
		var f_trans: Vector3 = (q_tilt * frente_actual).slide(n)
		if f_trans.length_squared() < 0.0001:
			f_trans = basis_actual.x.cross(n)
		f_objetivo = f_trans.normalized()

	return _construir_basis_desde_up_y_frente(n, f_objetivo)


func _construir_basis_desde_up_y_frente(eje_up: Vector3, frente: Vector3) -> Basis:
	var y_ax: Vector3 = eje_up.normalized()
	var f_limpio: Vector3 = frente.slide(y_ax)
	if f_limpio.length_squared() < 0.0001:
		var aux: Vector3 = Vector3.RIGHT if absf(y_ax.x) < 0.9 else Vector3.FORWARD
		f_limpio = aux.slide(y_ax)
	var z_ax: Vector3 = -f_limpio.normalized()
	var x_ax: Vector3 = y_ax.cross(z_ax).normalized()
	z_ax = x_ax.cross(y_ax).normalized()
	return Basis(x_ax, y_ax, z_ax).orthonormalized()


func _quat_entre_vectores(desde: Vector3, hasta: Vector3, eje_respaldo: Vector3) -> Quaternion:
	var a: Vector3 = desde.normalized()
	var b: Vector3 = hasta.normalized()
	var d: float = a.dot(b)
	if d >= 0.99995:
		return Quaternion.IDENTITY
	if d <= -0.99995:
		var eje: Vector3 = eje_respaldo.normalized() if eje_respaldo.length_squared() > 0.001 else Vector3.RIGHT
		return Quaternion(eje, PI)
	return Quaternion(a, b)


func _calcular_arista_convexa(p_ref: Vector3, p1: Vector3, n1: Vector3, p2: Vector3, n2: Vector3) -> Vector3:
	var d1: float = (p1 - p_ref).dot(n1)
	var d2: float = (p2 - p_ref).dot(n2)
	var c: float = n1.dot(n2)
	var denom: float = 1.0 - c * c
	if absf(denom) < 0.0001:
		return p_ref
	var a: float = (d1 - d2 * c) / denom
	var b: float = (d2 - d1 * c) / denom
	return p_ref + n1 * a + n2 * b


func _obtener_frente_visual_mundo() -> Vector3:
	if not _visual:
		return -_padre.global_transform.basis.z.normalized()
	if is_equal_approx(absf(_offset_rotacion_y), PI):
		return _visual.global_transform.basis.z.normalized()
	return -_visual.global_transform.basis.z.normalized()


func _fijar_transform_visual_trepado() -> void:
	if not _visual:
		return
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3(0.0, _offset_rotacion_y, 0.0)
	_visual.scale = _escala_visual_base


func _reproducir_anim(nombre_logico: String, velocidad_anim: float = 1.0) -> void:
	if not _animador or not _animador.has_method("reproducir"):
		return
	if "animacion_actual" in _animador and _animador.animacion_actual == nombre_logico:
		return
	_animador.reproducir(nombre_logico, velocidad_anim)


func _buscar_nodo_con_metodo(raiz: Node, metodo: String) -> Node:
	for hijo in raiz.get_children():
		if hijo.has_method(metodo):
			return hijo
		var sub: Node = _buscar_nodo_con_metodo(hijo, metodo)
		if sub:
			return sub
	return null


# ==============================================================================
# DIBUJO DE RAYCASTS Y NORMAL DE DEPURACIÓN (TECLA Y)
# ==============================================================================

func _crear_nodo_debug() -> void:
	_debug_immediate_mesh = ImmediateMesh.new()
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.vertex_color_use_as_albedo = true
	_debug_material.no_depth_test = true

	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.name = "DebugRaycastsTrepar"
	_debug_mesh_instance.top_level = true
	_debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_mesh_instance.mesh = _debug_immediate_mesh
	_debug_mesh_instance.material_override = _debug_material
	_debug_mesh_instance.visible = dibujar_debug
	add_child(_debug_mesh_instance)


func _actualizar_visibilidad_debug() -> void:
	if _debug_mesh_instance:
		_debug_mesh_instance.visible = dibujar_debug
		if not dibujar_debug and _debug_immediate_mesh:
			_debug_immediate_mesh.clear_surfaces()


func _registrar_linea_debug(desde: Vector3, hasta: Vector3, color: Color) -> void:
	if not dibujar_debug:
		return
	_lineas_debug.append({"desde": desde, "hasta": hasta, "color": color})


func _renderizar_debug() -> void:
	if not _debug_immediate_mesh:
		return
	_debug_immediate_mesh.clear_surfaces()
	if not dibujar_debug or _lineas_debug.is_empty():
		return

	_debug_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for linea in _lineas_debug:
		var a: Vector3 = linea["desde"]
		var b: Vector3 = linea["hasta"]
		var col: Color = linea["color"]
		_debug_immediate_mesh.surface_set_color(col)
		_debug_immediate_mesh.surface_add_vertex(a)
		_debug_immediate_mesh.surface_set_color(col)
		_debug_immediate_mesh.surface_add_vertex(b)

		# Pequeña cruz en la punta para visualizar impacto/dirección claramente
		var d: Vector3 = (b - a)
		if d.length_squared() > 0.01:
			var tam: float = 0.06
			_debug_immediate_mesh.surface_set_color(col)
			_debug_immediate_mesh.surface_add_vertex(b - Vector3(tam, 0, 0))
			_debug_immediate_mesh.surface_set_color(col)
			_debug_immediate_mesh.surface_add_vertex(b + Vector3(tam, 0, 0))
			_debug_immediate_mesh.surface_set_color(col)
			_debug_immediate_mesh.surface_add_vertex(b - Vector3(0, tam, 0))
			_debug_immediate_mesh.surface_set_color(col)
			_debug_immediate_mesh.surface_add_vertex(b + Vector3(0, tam, 0))
	_debug_immediate_mesh.surface_end()
