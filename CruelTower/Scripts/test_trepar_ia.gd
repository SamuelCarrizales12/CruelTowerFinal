class_name TestTreparIA
extends Node3D

## Controlador para la escena de prueba res://Escenas/test_trepar_ia.tscn
## Teclas de depuración:
##   1 = Forzar PERSECUCIÓN en las arañas
##   2 = Forzar BÚSQUEDA en las arañas
##   3 = Forzar EMBOSCADA en la araña del techo
##   4 = Mostrar rutas de trepar y marcadores
##   5 = Aturdir la araña más cercana

@onready var spider_patrulla: CharacterBody3D = $EnemigoSpiderPatrulla
@onready var spider_emboscada: CharacterBody3D = $EnemigoSpiderEmboscada
@onready var jugador: CharacterBody3D = $CharacterBody3D
@onready var label_hud: Label = $CanvasLayer/PanelHUD/LabelHUD
@onready var marcador_subida: Node3D = $PuntoTreparAbajo
@onready var marcador_arriba: Node3D = $PuntoTreparArriba
@onready var marcador_bajada: Node3D = $PuntoTreparBajada

var mostrar_rutas_debug: bool = false
var _debug_mesh_inst: MeshInstance3D = null
var _debug_imm_mesh: ImmediateMesh = null
var _debug_mat: StandardMaterial3D = null
var ultimo_evento: String = "Escena iniciada"


func _ready() -> void:
	_crear_visualizador_rutas()

	if spider_patrulla and spider_patrulla.has_signal("estado_cambiado"):
		spider_patrulla.estado_cambiado.connect(func(_ant, nuevo):
			ultimo_evento = "Spider Patrulla cambió a estado %s" % nuevo
		)

	if spider_emboscada and spider_emboscada.has_signal("estado_cambiado"):
		spider_emboscada.estado_cambiado.connect(func(_ant, nuevo):
			ultimo_evento = "Spider Emboscada cambió a estado %s" % nuevo
		)

	_actualizar_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	match event.keycode:
		KEY_1:
			forzar_persecucion()
		KEY_2:
			forzar_busqueda()
		KEY_3:
			forzar_emboscada()
		KEY_4:
			alternar_rutas_debug()
		KEY_5:
			aturdir_mas_cercana()


func _process(_delta: float) -> void:
	_actualizar_hud()
	if mostrar_rutas_debug:
		_dibujar_rutas_y_marcadores()


func forzar_persecucion() -> void:
	ultimo_evento = "Tecla [1]: Forzando PERSECUCIÓN hacia el jugador"
	for s in [spider_patrulla, spider_emboscada]:
		if s and is_instance_valid(s) and s.get("estado_actual") != EnemigoIA.Estado.MUERTO:
			s.cambiar_estado(EnemigoIA.Estado.PERSECUCION)


func forzar_busqueda() -> void:
	ultimo_evento = "Tecla [2]: Forzando BÚSQUEDA"
	for s in [spider_patrulla, spider_emboscada]:
		if s and is_instance_valid(s) and s.get("estado_actual") != EnemigoIA.Estado.MUERTO:
			s.cambiar_estado(EnemigoIA.Estado.BUSQUEDA)


func forzar_emboscada() -> void:
	ultimo_evento = "Tecla [3]: Forzando EMBOSCADA en el techo"
	if spider_emboscada and is_instance_valid(spider_emboscada) and spider_emboscada.get("estado_actual") != EnemigoIA.Estado.MUERTO:
		spider_emboscada.emboscada = true
		spider_emboscada.global_position = Vector3(-0.9, 4.15, -0.7)
		spider_emboscada.cambiar_estado(EnemigoIA.Estado.EMBOSCADA)


func alternar_rutas_debug() -> void:
	mostrar_rutas_debug = not mostrar_rutas_debug
	ultimo_evento = "Tecla [4]: Rutas y marcadores debug = %s" % ("ACTIVADO" if mostrar_rutas_debug else "DESACTIVADO")
	if _debug_mesh_inst:
		_debug_mesh_inst.visible = mostrar_rutas_debug
	if not mostrar_rutas_debug and _debug_imm_mesh:
		_debug_imm_mesh.clear_surfaces()


func aturdir_mas_cercana() -> void:
	var obj_ref = jugador if (jugador and is_instance_valid(jugador)) else self
	var pos_ref = obj_ref.global_position
	var mejor: CharacterBody3D = null
	var min_d: float = INF

	for s in [spider_patrulla, spider_emboscada]:
		if s and is_instance_valid(s) and s.get("estado_actual") != EnemigoIA.Estado.MUERTO:
			var d = s.global_position.distance_to(pos_ref)
			if d < min_d:
				min_d = d
				mejor = s

	if mejor:
		mejor.aturdir(2.0)
		ultimo_evento = "Tecla [5]: Aturdida araña '%s' (2.0 s)" % mejor.name


func _actualizar_hud() -> void:
	if not label_hud:
		return

	var txt = "=== PRUEBA DE IA Y TREPADO SPIDER ===\n"
	txt += "[1] Forzar PERSECUCIÓN | [2] Forzar BÚSQUEDA | [3] Forzar EMBOSCADA\n"
	txt += "[4] Mostrar Rutas y Marcadores (%s) | [5] Aturdir Más Cercana\n\n" % ("ON" if mostrar_rutas_debug else "OFF")

	if spider_patrulla and is_instance_valid(spider_patrulla):
		var est = spider_patrulla.get("estado_actual")
		var subf = spider_patrulla.get("subfase_trepar")
		var sup = spider_patrulla.get_node_or_null("MovimientoSuperficie") as MovimientoSuperficie
		var modo_sup = sup.obtener_modo_texto() if sup else "N/A"
		txt += "• Spider Patrulla: Estado=%s | Subfase=%s | Superficie=%s | HP=%.0f\n" % [est, subf, modo_sup, spider_patrulla.get("vida_actual")]
	else:
		txt += "• Spider Patrulla: [MUERTA/ELIMINADA]\n"

	if spider_emboscada and is_instance_valid(spider_emboscada):
		var est = spider_emboscada.get("estado_actual")
		var subf = spider_emboscada.get("subfase_trepar")
		var sup = spider_emboscada.get_node_or_null("MovimientoSuperficie") as MovimientoSuperficie
		var modo_sup = sup.obtener_modo_texto() if sup else "N/A"
		txt += "• Spider Emboscada: Estado=%s | Subfase=%s | Superficie=%s | HP=%.0f\n" % [est, subf, modo_sup, spider_emboscada.get("vida_actual")]
	else:
		txt += "• Spider Emboscada: [MUERTA/ELIMINADA]\n"

	if jugador and is_instance_valid(jugador):
		txt += "• Jugador: HP=%.0f / %.0f | Invulnerable=%s\n" % [jugador.get("vida_actual"), jugador.get("vida_maxima"), jugador.get("invulnerable")]
	txt += "\nÚltimo evento: %s" % ultimo_evento

	label_hud.text = txt


func _crear_visualizador_rutas() -> void:
	_debug_mesh_inst = MeshInstance3D.new()
	_debug_mesh_inst.name = "VisualizadorRutasIA"
	_debug_imm_mesh = ImmediateMesh.new()
	_debug_mesh_inst.mesh = _debug_imm_mesh

	_debug_mat = StandardMaterial3D.new()
	_debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mat.vertex_color_use_as_albedo = true
	_debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_debug_mat.no_depth_test = true
	_debug_mesh_inst.material_override = _debug_mat

	add_child(_debug_mesh_inst)
	_debug_mesh_inst.visible = false


func _dibujar_rutas_y_marcadores() -> void:
	if not _debug_imm_mesh:
		return
	_debug_imm_mesh.clear_surfaces()
	_debug_imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var puntos = get_tree().get_nodes_in_group("punto_trepar")
	for p in puntos:
		if p is Node3D:
			var pos = p.global_position
			var norm = p.get("normal_superficie")
			var n_vec = norm if (norm is Vector3) else Vector3.UP

			# Dibujar cruz en cada marcador
			_linea_imm(pos - Vector3(0.2, 0, 0), pos + Vector3(0.2, 0, 0), Color(1, 0.8, 0.1))
			_linea_imm(pos - Vector3(0, 0.2, 0), pos + Vector3(0, 0.2, 0), Color(1, 0.8, 0.1))
			_linea_imm(pos - Vector3(0, 0, 0.2), pos + Vector3(0, 0, 0.2), Color(1, 0.8, 0.1))
			# Flecha normal
			_linea_imm(pos, pos + n_vec * 0.6, Color(0.1, 1.0, 0.9))

	# Conexión sugerida entre marcadores (ruta de trepar)
	if marcador_subida and marcador_arriba:
		_linea_imm(marcador_subida.global_position, marcador_arriba.global_position, Color(0.2, 0.9, 0.3, 0.8))
	if marcador_arriba and marcador_bajada:
		_linea_imm(marcador_arriba.global_position, marcador_bajada.global_position, Color(0.2, 0.9, 0.3, 0.8))

	_debug_imm_mesh.surface_end()


func _linea_imm(p1: Vector3, p2: Vector3, color: Color) -> void:
	_debug_imm_mesh.surface_set_color(color)
	_debug_imm_mesh.surface_add_vertex(p1)
	_debug_imm_mesh.surface_set_color(color)
	_debug_imm_mesh.surface_add_vertex(p2)
