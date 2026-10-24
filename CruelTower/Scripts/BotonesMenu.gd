extends Control

## Velocidad de rotación panorámica 3D estilo Minecraft (en radianes por segundo)
const PANORAMA_ROTATION_SPEED: float = 0.05
const CAMERA_SWAY_FREQUENCY: float = 0.35
const CAMERA_SWAY_AMPLITUDE: float = 0.025

# Referencias a botones mediante Unique Scene Nodes (%) con fallback
@onready var btn_nueva_partida: TextureButton = %BtnNuevaPartida if has_node("%BtnNuevaPartida") else get_node_or_null("BS")
@onready var btn_continuar: TextureButton = %BtnContinuar if has_node("%BtnContinuar") else get_node_or_null("BS2")
@onready var btn_configuracion: TextureButton = %BtnConfiguracion if has_node("%BtnConfiguracion") else get_node_or_null("BS3")
@onready var btn_salir: TextureButton = %BtnSalir if has_node("%BtnSalir") else get_node_or_null("BS4")

# Referencias a fondo panorámico 3D
@onready var camera_pivot: Node3D = get_node_or_null("BackgroundViewportContainer/BackgroundViewport/Panorama3D/CameraPivot")
@onready var camera: Camera3D = get_node_or_null("BackgroundViewportContainer/BackgroundViewport/Panorama3D/CameraPivot/Camera3D")
@onready var title_label: Label = %TitleLabel if has_node("%TitleLabel") else null

# Almacén de tweens por botón para evitar competencias entre animaciones
var _button_tweens: Dictionary = {}
var _time_elapsed: float = 0.0
var _buttons_list: Array[TextureButton] = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_buttons_list = []
	for b in [btn_nueva_partida, btn_continuar, btn_configuracion, btn_salir]:
		if is_instance_valid(b):
			_buttons_list.append(b)

	_setup_button_events()
	_play_intro_animation()

	# Soporte inmediato para mando / teclado
	if is_instance_valid(btn_nueva_partida):
		btn_nueva_partida.grab_focus()

func _process(delta: float) -> void:
	_rotate_panorama(delta)

## Rotación panorámica suave continua estilo Minecraft
func _rotate_panorama(delta: float) -> void:
	if not is_instance_valid(camera_pivot):
		return

	_time_elapsed += delta
	# Giro continuo sobre el eje Y
	camera_pivot.rotation.y += PANORAMA_ROTATION_SPEED * delta

	# Leve balanceo orgánico sobre el eje X (cámara viva)
	if is_instance_valid(camera):
		camera.rotation.x = -0.10 + sin(_time_elapsed * CAMERA_SWAY_FREQUENCY) * CAMERA_SWAY_AMPLITUDE

## Conexión de señales y configuración de pivotes para escalado centrado
func _setup_button_events() -> void:
	for btn in _buttons_list:
		if not is_instance_valid(btn):
			continue

		# Ajuste del pivote al centro del botón para que el hover escale simétricamente
		if btn.custom_minimum_size != Vector2.ZERO:
			btn.pivot_offset = btn.custom_minimum_size / 2.0
		btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)

		# Señales de interacción visual (Hover / Focus)
		btn.mouse_entered.connect(_on_button_hovered.bind(btn))
		btn.mouse_exited.connect(_on_button_unhovered.bind(btn))
		btn.focus_entered.connect(_on_button_hovered.bind(btn))
		btn.focus_exited.connect(_on_button_unhovered.bind(btn))
		btn.button_down.connect(_on_button_pressed_down.bind(btn))
		btn.button_up.connect(_on_button_hovered.bind(btn))

	# Conexión de lógica funcional de juego
	if is_instance_valid(btn_nueva_partida):
		btn_nueva_partida.pressed.connect(_on_nueva_partida_pressed)
	if is_instance_valid(btn_continuar):
		btn_continuar.pressed.connect(_on_continuar_pressed)
	if is_instance_valid(btn_configuracion):
		btn_configuracion.pressed.connect(_on_configuracion_pressed)
	if is_instance_valid(btn_salir):
		btn_salir.pressed.connect(_on_salir_pressed)

## Animación de entrada elegante y escalonada (Staggered Intro)
func _play_intro_animation() -> void:
	if is_instance_valid(title_label):
		title_label.modulate.a = 0.0
		var title_tween := create_tween()
		title_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title_label, "modulate:a", 1.0, 0.7)

	for i in range(_buttons_list.size()):
		var btn = _buttons_list[i]
		if not is_instance_valid(btn):
			continue
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.92, 0.92)

		var intro_tween := create_tween()
		intro_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		intro_tween.tween_interval(0.15 + (i * 0.08))
		intro_tween.parallel().tween_property(btn, "modulate:a", 1.0, 0.4)
		intro_tween.parallel().tween_property(btn, "scale", Vector2.ONE, 0.4)

## Efecto Hover / Focus: aumento sutil + resplandor dorado cálido
func _on_button_hovered(btn: TextureButton) -> void:
	if not is_instance_valid(btn):
		return

	_kill_button_tween(btn)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.18)
	tween.tween_property(btn, "modulate", Color(1.15, 1.10, 1.02, 1.0), 0.18)
	_button_tweens[btn] = tween

## Regreso al estado normal
func _on_button_unhovered(btn: TextureButton) -> void:
	if not is_instance_valid(btn):
		return

	_kill_button_tween(btn)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.2)
	_button_tweens[btn] = tween

## Feedback táctil al presionar
func _on_button_pressed_down(btn: TextureButton) -> void:
	if not is_instance_valid(btn):
		return

	_kill_button_tween(btn)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.08)
	tween.tween_property(btn, "modulate", Color(0.9, 0.88, 0.85, 1.0), 0.08)
	_button_tweens[btn] = tween

func _kill_button_tween(btn: TextureButton) -> void:
	if _button_tweens.has(btn) and is_instance_valid(_button_tweens[btn]):
		_button_tweens[btn].kill()
	_button_tweens.erase(btn)

# --- ACCIONES FUNCIONALES DEL JUEGO ---

func _on_nueva_partida_pressed() -> void:
	print("Iniciando nueva partida...")
	get_tree().change_scene_to_file("res://SPG.tscn")

func _on_continuar_pressed() -> void:
	print("Cargando partida guardada...")
	get_tree().change_scene_to_file("res://SPG.tscn")

func _on_configuracion_pressed() -> void:
	print("Abriendo menú de configuración...")
	get_tree().change_scene_to_file("res://Settings.tscn")

func _on_salir_pressed() -> void:
	print("Saliendo del juego...")
	get_tree().quit()
