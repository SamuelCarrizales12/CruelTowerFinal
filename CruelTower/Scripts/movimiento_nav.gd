class_name MovimientoNav
extends NavigationAgent3D

## Componente de navegación y movimiento reutilizable para enemigos CharacterBody3D.
## Se conecta como hijo de un CharacterBody3D y gestiona el pathfinding, la velocidad,
## la rotación suave del nodo Visual y la física de movimiento.

signal destino_alcanzado
signal sin_camino

@export_group("Movimiento")
@export var velocidad: float = 2.0
@export var velocidad_giro: float = 6.0
@export var vuela: bool = false
@export var tiempo_recalculo: float = 0.25
@export var offset_rotacion_y: float = 0.0

var _padre: CharacterBody3D
var _visual: Node3D
var _activo: bool = false
var _ha_llegado: bool = false
var _sin_camino_emitido: bool = false
var _tiempo_acumulado: float = 0.0
var _posicion_solicitada: Vector3 = Vector3.ZERO
var _primera_asignacion: bool = true


func _ready() -> void:
	_padre = get_parent() as CharacterBody3D
	if not _padre:
		push_warning("MovimientoNav: El padre no es un CharacterBody3D.")
		return
	
	# Buscar el nodo Visual en el padre para la rotación suave
	_visual = _padre.get_node_or_null("Visual") as Node3D
	if not _visual:
		_visual = _padre.find_child("Visual", true, false) as Node3D
		
	# Ajustar distancias por defecto del NavigationAgent3D
	path_desired_distance = 0.5
	target_desired_distance = 0.8


func _physics_process(delta: float) -> void:
	if not _padre:
		return

	# Manejo de gravedad si no vuela
	if not vuela:
		if not _padre.is_on_floor():
			_padre.velocity += _padre.get_gravity() * delta
		else:
			# Evitar acumular velocidad hacia abajo en el suelo
			if _padre.velocity.y < 0:
				_padre.velocity.y = 0.0

	# Si no está activo el movimiento, detener velocidad horizontal
	if not _activo:
		_frenar_horizontal()
		_padre.move_and_slide()
		return

	# Throttling de recálculo: actualizar target_position cada tiempo_recalculo
	_tiempo_acumulado += delta
	if _tiempo_acumulado >= tiempo_recalculo:
		_tiempo_acumulado = 0.0
		if target_position.distance_to(_posicion_solicitada) > 0.05:
			_asignar_target(_posicion_solicitada)

	# Verificar si hay ruta válida y si el objetivo es alcanzable
	if not is_target_reachable() or get_current_navigation_path().is_empty():
		_frenar_horizontal()
		_padre.move_and_slide()
		if not _sin_camino_emitido:
			_sin_camino_emitido = true
			sin_camino.emit()
		return
	else:
		_sin_camino_emitido = false

	# Verificar si se llegó al destino final
	if is_navigation_finished():
		_frenar_horizontal()
		_padre.move_and_slide()
		if not _ha_llegado:
			_ha_llegado = true
			_activo = false
			destino_alcanzado.emit()
		return

	# Obtener siguiente punto en la ruta
	var siguiente_pos: Vector3 = get_next_path_position()
	var pos_actual: Vector3 = _padre.global_position

	var dir: Vector3
	if vuela:
		dir = (siguiente_pos - pos_actual).normalized()
		_padre.velocity = dir * velocidad
	else:
		dir = (siguiente_pos - pos_actual)
		dir.y = 0.0
		dir = dir.normalized()
		_padre.velocity.x = dir.x * velocidad
		_padre.velocity.z = dir.z * velocidad

	_padre.move_and_slide()

	# Rotación suave del nodo Visual hacia la dirección de movimiento (-Z adelante)
	_rotar_hacia(dir, delta)


func ir_a(posicion: Vector3) -> void:
	_posicion_solicitada = posicion
	_ha_llegado = false

	if not _activo or _primera_asignacion:
		_primera_asignacion = false
		_asignar_target(posicion)
		_tiempo_acumulado = 0.0

	_activo = true


func detener() -> void:
	_activo = false
	_ha_llegado = false
	_sin_camino_emitido = false
	_primera_asignacion = true
	if _padre:
		_frenar_horizontal()
		_padre.move_and_slide()


func esta_en_destino() -> bool:
	return _ha_llegado or is_navigation_finished()


func _asignar_target(pos: Vector3) -> void:
	target_position = pos


func _frenar_horizontal() -> void:
	if _padre:
		_padre.velocity.x = 0.0
		_padre.velocity.z = 0.0
		if vuela:
			_padre.velocity.y = 0.0


func _rotar_hacia(dir: Vector3, delta: float) -> void:
	if not _visual:
		return
	var dir_h = Vector3(dir.x, 0.0, dir.z)
	if dir_h.length_squared() > 0.001:
		# En Godot, el frente del modelo estándar es -Z.
		# offset_rotacion_y permite compensar modelos que miran hacia +Z (ej. Spider con PI).
		var angulo_objetivo = atan2(-dir_h.x, -dir_h.z) + offset_rotacion_y
		_visual.rotation.y = lerp_angle(_visual.rotation.y, angulo_objetivo, velocidad_giro * delta)
