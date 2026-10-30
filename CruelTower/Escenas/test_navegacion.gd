extends Node3D

@onready var laberinto = $Mapa1
@onready var jugador = $Jugador
@onready var escorpion = $EnemigoScorpion
@onready var camara_cenital = $CamaraCenital
@onready var movimiento_nav = $EnemigoScorpion/MovimientoNav

@onready var lbl_estado = $UI/Panel/Margin/VBox/LblEstado
@onready var lbl_distancia = $UI/Panel/Margin/VBox/LblDistancia
@onready var lbl_evento = $UI/Panel/Margin/VBox/LblEvento
@onready var lbl_camara = $UI/Panel/Margin/VBox/LblCamara

var persiguiendo: bool = false
var camara_cenital_activa: bool = true
var ultimo_evento: String = "Listo"


func _ready() -> void:
	# Activar debug visual de navegación (malla celeste/azul de Godot)
	NavigationServer3D.set_debug_enabled(true)
	
	# Conectar señales del componente de navegación
	movimiento_nav.destino_alcanzado.connect(_on_destino_alcanzado)
	movimiento_nav.sin_camino.connect(_on_sin_camino)
	
	# Activar cámara cenital por defecto para ver la malla y las esquinas
	_actualizar_camaras()
	_actualizar_ui()


func _process(_delta: float) -> void:
	if persiguiendo and jugador and is_instance_valid(jugador):
		movimiento_nav.ir_a(jugador.global_position)
	
	_actualizar_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_N:
				persiguiendo = true
				ultimo_evento = "Persecución iniciada (Tecla N)"
				movimiento_nav.ir_a(jugador.global_position)
			KEY_M:
				persiguiendo = false
				ultimo_evento = "Detenido manualmente (Tecla M)"
				movimiento_nav.detener()
			KEY_V:
				camara_cenital_activa = not camara_cenital_activa
				_actualizar_camaras()
			KEY_1:
				# Teletransportar jugador a esquina normal
				jugador.global_position = Vector3(-2.5, 0.5, 2.0)
				ultimo_evento = "Jugador en posición normal (esquina)"
			KEY_2:
				# Teletransportar jugador a pasillo estrecho
				jugador.global_position = Vector3(-10.0, 0.5, -16.0)
				ultimo_evento = "Jugador en pasillo estrecho"
			KEY_3:
				# Teletransportar jugador a zona inalcanzable (fuera del laberinto)
				jugador.global_position = Vector3(80.0, 0.5, 80.0)
				ultimo_evento = "Jugador en zona inalcanzable (80, 0.5, 80)"


func _on_destino_alcanzado() -> void:
	persiguiendo = false
	ultimo_evento = "¡Destino alcanzado!"


func _on_sin_camino() -> void:
	persiguiendo = false
	ultimo_evento = "¡Sin camino! (Objetivo inalcanzable, detenido limpiamente)"


func _actualizar_camaras() -> void:
	camara_cenital.current = camara_cenital_activa
	# Si la cenital está activa, liberar el cursor del ratón; si es jugador, capturarlo
	if camara_cenital_activa:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _actualizar_ui() -> void:
	if not lbl_estado or not escorpion or not jugador:
		return
		
	var estado_str = "DETENIDO"
	if persiguiendo:
		if movimiento_nav.esta_en_destino():
			estado_str = "EN DESTINO"
		else:
			estado_str = "PERSIGUIENDO"
	elif movimiento_nav.esta_en_destino():
		estado_str = "EN DESTINO"
		
	var dist = escorpion.global_position.distance_to(jugador.global_position)
	lbl_estado.text = "Estado: %s" % estado_str
	lbl_distancia.text = "Distancia al jugador: %.2f m" % dist
	lbl_evento.text = "Último evento: %s" % ultimo_evento
	lbl_camara.text = "Cámara activa: %s (V para alternar)" % ("Cenital / Perspectiva" if camara_cenital_activa else "Primera Persona (Jugador)")
