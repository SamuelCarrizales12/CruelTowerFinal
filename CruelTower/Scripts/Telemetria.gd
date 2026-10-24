extends Node
## Autoload "Telemetria": registra lo que hace el jugador y lo manda a la API local.
## Se agrega en Proyecto > Configuración del proyecto > Globales > Autoload (nombre: Telemetria).

const API_URL := "http://localhost:3000/api/telemetry/batch"
const GAME_VERSION := "1.0.0"
const INTERVALO_ENVIO := 5.0       # segundos entre envíos
const INTERVALO_POSICION := 1.0    # una muestra de posición por segundo
const MAX_EVENTOS := 2000
const MAX_COLA := 100
const CONFIG_PATH := "user://telemetria.cfg"

var username: String = ""          # Se puede cambiar: Telemetria.username = "Ana"
var session_id: String = ""
var run_id: String = ""            # vacío = no hay run activo
var level_name: String = "Nivel 1"
var t_run: float = 0.0             # segundos jugados (no cuenta el tiempo en pausa)

var _jugador: Node3D = null
var _eventos: Array = []
var _posiciones: Array = []
var _seq_evento := 0
var _seq_pos := 0
var _acc_pos := 0.0
var _acc_envio := 0.0
var _acc_latido := 0.0

var _http: HTTPRequest
var _cola: Array = []              # lotes JSON pendientes de enviar
var _ocupado := false
var _saliendo := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue enviando aunque el juego esté en pausa
	get_tree().set_auto_accept_quit(false)   # para poder avisar al servidor antes de cerrar
	username = _cargar_username()
	session_id = _nuevo_id()
	_http = HTTPRequest.new()
	_http.timeout = 5.0
	add_child(_http)
	_http.request_completed.connect(_on_http_done)
	_encolar_lote()  # registra el inicio de sesión (sirve para medir quién abre y no juega)

# ---------------------------------------------------------------- API pública

## Llamar desde Character._ready()
func iniciar_run(jugador: Node3D, nivel: String = "Nivel 1") -> void:
	if run_id != "":
		finalizar_run("quit", "cambio_de_escena")
	_jugador = jugador
	level_name = nivel
	run_id = _nuevo_id()
	t_run = 0.0
	_seq_evento = 0
	_seq_pos = 0
	_acc_pos = 0.0
	jugador.tree_exiting.connect(_on_jugador_sale, CONNECT_ONE_SHOT)
	evento("level_start")

## Registra un evento. Si no se pasa posición, usa la del jugador.
func evento(tipo: String, datos: Dictionary = {}, pos: Variant = null) -> void:
	if run_id == "" or _eventos.size() >= MAX_EVENTOS:
		return
	var p: Vector3 = Vector3.ZERO
	if pos is Vector3:
		p = pos
	elif is_instance_valid(_jugador):
		p = _jugador.global_position
	_eventos.append({
		"seq": _seq_evento, "type": tipo, "t": snappedf(t_run, 0.01),
		"x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01),
		"data": datos
	})
	_seq_evento += 1

## El jugador murió: guarda el evento y cierra el run
func muerte(causa: String = "desconocido") -> void:
	evento("death", {"cause": causa})
	finalizar_run("died")

## Cambia el nombre con el que se reporta al jugador (lo llama SaveLoad al elegir/cargar una partida).
## Lo guarda en user://telemetria.cfg para recordarlo la próxima vez que se abra el juego.
func set_username(nombre: String) -> void:
	nombre = nombre.strip_edges()
	if nombre == "" or nombre == username:
		return
	username = nombre
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("jugador", "username", nombre)
	cfg.save(CONFIG_PATH)
	_encolar_lote()  # actualiza la sesión en la base de datos con el nombre nuevo

## Para cuando agregues una meta al nivel
func nivel_completado() -> void:
	evento("level_complete")
	finalizar_run("completed")

func finalizar_run(resultado: String, motivo: String = "") -> void:
	if run_id == "":
		return
	if resultado == "quit":
		evento("quit", {"reason": motivo})
	_encolar_lote(resultado)
	run_id = ""
	_jugador = null

## Usar en lugar de get_tree().quit()
func salir_del_juego() -> void:
	if _saliendo:
		return
	_saliendo = true
	finalizar_run("quit", "cerrar_juego")
	_encolar_lote("", "quit_game")
	var limite := Time.get_ticks_msec() + 2500  # espera máximo 2.5 s a que se envíe
	while (_ocupado or not _cola.is_empty()) and Time.get_ticks_msec() < limite:
		_enviar_siguiente()
		await get_tree().process_frame
	get_tree().quit()

# ------------------------------------------------------------------ internos

func _process(delta: float) -> void:
	_acc_envio += delta
	_acc_latido += delta
	var en_pausa := get_tree().paused

	if run_id != "" and not en_pausa:
		t_run += delta
		_acc_pos += delta
		if _acc_pos >= INTERVALO_POSICION:
			_acc_pos = 0.0
			_muestrear_posicion()

	if _acc_envio >= INTERVALO_ENVIO:
		_acc_envio = 0.0
		if run_id != "" or not _eventos.is_empty():
			_encolar_lote()
		elif _acc_latido >= 20.0:  # en menús: señal de vida cada 20 s
			_acc_latido = 0.0
			_encolar_lote()
	_enviar_siguiente()

func _muestrear_posicion() -> void:
	if not is_instance_valid(_jugador):
		return
	var p := _jugador.global_position
	_posiciones.append({
		"seq": _seq_pos, "t": snappedf(t_run, 0.01),
		"x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01)
	})
	_seq_pos += 1

func _encolar_lote(fin_run: String = "", fin_sesion: String = "") -> void:
	var slot := 1
	if has_node("/root/SaveLoad"):
		slot = SaveLoad.current_slot
	var lote := {
		"username": username, "session_id": session_id,
		"game_version": GAME_VERSION, "platform": OS.get_name(),
		"run_id": run_id, "level_name": level_name, "slot": slot,
		"t": snappedf(t_run, 0.01),
		"events": _eventos, "positions": _posiciones,
		"run_end": fin_run, "session_end": fin_sesion
	}
	_cola.append(JSON.stringify(lote))
	_eventos = []
	_posiciones = []
	while _cola.size() > MAX_COLA:
		_cola.pop_front()
	_enviar_siguiente()

func _enviar_siguiente() -> void:
	if _ocupado or _cola.is_empty():
		return
	_ocupado = true
	var err := _http.request(API_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, _cola[0])
	if err != OK:
		_ocupado = false

func _on_http_done(resultado: int, codigo: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_ocupado = false
	if resultado != HTTPRequest.RESULT_SUCCESS:
		return  # sin conexión: el lote se queda en la cola y se reintenta
	if codigo == 200 or (codigo >= 400 and codigo < 500):
		_cola.pop_front()  # 4xx se descarta para que un lote inválido no bloquee la cola
	if not _cola.is_empty():
		_enviar_siguiente()

func _on_jugador_sale() -> void:
	# El jugador salió del árbol (cambio de escena) sin haber muerto: cuenta como abandono
	if run_id != "":
		finalizar_run("quit", "salio_de_la_escena")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		salir_del_juego()

func _nuevo_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()

func _cargar_username() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK and str(cfg.get_value("jugador", "username", "")) != "":
		return str(cfg.get_value("jugador", "username"))
	var nuevo := "Jugador_%d" % randi_range(1000, 9999)
	cfg.set_value("jugador", "username", nuevo)
	cfg.save(CONFIG_PATH)
	return nuevo
