extends Node3D
class_name AnimacionIdle

signal animacion_terminada(nombre_logico: String)

## Control de Levitación (Seno en eje Y)
@export var levitacion_activa: bool = true
@export var amplitud_levitacion: float = 0.08
@export var velocidad_levitacion: float = 2.0

## Control de Balanceo Lateral (Rotación en Z)
@export var balanceo_activo: bool = false
@export var amplitud_balanceo_deg: float = 4.0
@export var velocidad_balanceo: float = 2.5

## Control de Respiración (Escalado sutil)
@export var respiracion_activa: bool = true
@export var factor_respiracion: float = 0.02
@export var velocidad_respiracion: float = 1.5

## Activar colores por vértice en materiales hijos sin alterar assets originales
@export var activar_colores_vertice: bool = false
@export var vertex_color_is_srgb: bool = true

## Desfase temporal
@export var desfase_tiempo: float = 0.0

var animacion_actual: String = "idle"

var _tiempo: float = 0.0
var _pos_y_base: float = 0.0
var _rot_z_base: float = 0.0
var _escala_base: Vector3 = Vector3.ONE

var _mod_velocidad: float = 1.0
var _mod_amplitud: float = 1.0

func _ready() -> void:
	_pos_y_base = position.y
	_rot_z_base = rotation.z
	_escala_base = scale
	
	if activar_colores_vertice:
		_aplicar_colores_vertice(self)

func _process(delta: float) -> void:
	_tiempo += delta * _mod_velocidad
	var t: float = _tiempo + desfase_tiempo

	# 1. Levitación
	if levitacion_activa and amplitud_levitacion > 0.0:
		position.y = _pos_y_base + sin(t * velocidad_levitacion) * (amplitud_levitacion * _mod_amplitud)

	# 2. Balanceo lateral
	if balanceo_activo and amplitud_balanceo_deg > 0.0:
		rotation.z = _rot_z_base + deg_to_rad(amplitud_balanceo_deg * _mod_amplitud) * sin(t * velocidad_balanceo)

	# 3. Respiración
	if respiracion_activa and factor_respiracion > 0.0:
		var factor: float = 1.0 + sin(t * velocidad_respiracion) * (factor_respiracion * _mod_amplitud)
		scale = Vector3(
			_escala_base.x * (1.0 + (factor - 1.0) * 0.4),
			_escala_base.y * factor,
			_escala_base.z * (1.0 + (factor - 1.0) * 0.4)
		)

## Misma interfaz que AnimadorEnemigo para consumo de IA
func reproducir(nombre_logico: String, velocidad: float = 1.0) -> void:
	animacion_actual = nombre_logico
	match nombre_logico.to_lower():
		"idle":
			_mod_velocidad = velocidad
			_mod_amplitud = 1.0
		"caminar":
			_mod_velocidad = velocidad * 1.8
			_mod_amplitud = 1.4
		"correr":
			_mod_velocidad = velocidad * 2.6
			_mod_amplitud = 1.8
		"atacar":
			_mod_velocidad = velocidad * 3.0
			_mod_amplitud = 2.2
		"morir":
			_mod_velocidad = 0.2
			_mod_amplitud = 0.2
		_:
			print("[AnimacionIdle] Acción '" + nombre_logico + "' adaptada a procedural en " + get_parent().name)
			_mod_velocidad = velocidad
			
	print("[AnimacionIdle] " + get_parent().name + " cambiando a estado procedural: '" + nombre_logico + "'")

func _aplicar_colores_vertice(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for s in range(node.mesh.get_surface_count()):
			var arrays = node.mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null:
				var orig_mat = node.get_surface_override_material(s)
				if not orig_mat:
					orig_mat = node.mesh.surface_get_material(s)
				
				var mat: StandardMaterial3D
				if orig_mat is StandardMaterial3D:
					mat = orig_mat.duplicate()
				else:
					mat = StandardMaterial3D.new()
				
				mat.vertex_color_use_as_albedo = true
				mat.albedo_color = Color.WHITE
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.vertex_color_is_srgb = vertex_color_is_srgb
				
				node.set_surface_override_material(s, mat)
	for c in node.get_children():
		_aplicar_colores_vertice(c)
