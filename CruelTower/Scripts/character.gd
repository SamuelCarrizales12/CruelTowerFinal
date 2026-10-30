extends CharacterBody3D

signal vida_cambiada(vida_actual: float, vida_maxima: float)
signal jugador_murio

@export var vida_maxima: float = 100.0
@export var vida_actual: float = 100.0
@export var tiempo_invulnerabilidad: float = 0.5

const SPEED = 2.5
const SPEED_RUN = 3.5
const MOUSE_SENSITIVITY = 0.003

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var raycast = $CameraPivot/SpringArm3D/Camera3D/RayCast3D
@onready var camara = $CameraPivot/SpringArm3D/Camera3D
@onready var mirilla = $CanvasLayer/ColorRect
@onready var texto_interaccion = $CanvasLayer/Label

@onready var overlay_danio: ColorRect = $CanvasLayer/DanioOverlay
@onready var barra_vida: ProgressBar = $CanvasLayer/HUDVida/ProgressBar
@onready var label_vida_val: Label = $CanvasLayer/HUDVida/LabelValor
@onready var game_over_screen: GameOverScreen = $GameOver
@onready var audio_danio: AudioStreamPlayer = $AudioDanio

const FOV_NORMAL = 75.0
const FOV_APUNTADO = 40.0
var esta_disparando = false
var tiempo_paso = 0.0

@export var tiene_pistola: bool = false

var invulnerable: bool = false
var muerto: bool = false
var _shake_offset: Vector2 = Vector2.ZERO
var _tween_shake: Tween = null
var _tween_flash: Tween = null
var _tween_barra: Tween = null
var _tiempo_ruido_paso: float = 0.0

func _ready():
	add_to_group("jugador")
	add_to_group("player")
	collision_layer = collision_layer | 2
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	vida_actual = vida_maxima
	if game_over_screen:
		jugador_murio.connect(game_over_screen.mostrar)
	vida_cambiada.connect(_on_vida_cambiada)
	_on_vida_cambiada(vida_actual, vida_maxima)

func _process(delta: float) -> void:
	# Viñeta suave y permanente con latido lento cuando la vida está bajo 30%
	if overlay_danio and overlay_danio.material:
		var mat := overlay_danio.material as ShaderMaterial
		if not muerto and (vida_actual / vida_maxima) <= 0.3:
			var latido: float = 0.28 + 0.14 * sin(Time.get_ticks_msec() * 0.004)
			var cur_vig = mat.get_shader_parameter("vignette_intensity")
			var vig_val: float = cur_vig if cur_vig != null else 0.0
			mat.set_shader_parameter("vignette_intensity", maxf(vig_val, latido))

func _unhandled_input(event):
	# Si está muerto, se desactiva todo el control del jugador (cámara, movimiento, disparo)
	if muerto:
		return

	# Depuración con F1 / F2 (solo en compilaciones de depuración)
	if OS.is_debug_build() and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F1:
			recibir_dano(20.0, global_position + Vector3(0, 0, 1.0))
		elif event.keycode == KEY_F2:
			curar(20.0)

	if esta_disparando:
		return
		
	if event is InputEventMouseMotion:
		pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-75), deg_to_rad(45))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Si ha muerto, se desactiva el movimiento y solo desacelera
	if muerto:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	if not esta_disparando:	
		var velocidad_actual = SPEED
		if Input.is_action_pressed("correr") and not Input.is_action_pressed("apuntar"):
			velocidad_actual = SPEED_RUN
			
		var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
		var direction := (pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
		if direction:
			velocity.x = direction.x * velocidad_actual
			velocity.z = direction.z * velocidad_actual
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad_actual)
			velocity.z = move_toward(velocity.z, 0, velocidad_actual)
	
		if Input.is_action_just_pressed("disparar") and tiene_pistola:
			disparar()
			
		if Input.is_action_just_pressed("interactuar"):
			raycast.force_raycast_update()
			if raycast.is_colliding():
				var objeto_mirado = raycast.get_collider()
				if objeto_mirado.has_method("recoger"):
					var distancia = global_position.distance_to(objeto_mirado.global_position)
					if distancia <= 1.0:
						objeto_mirado.recoger(self)
			
		if direction and is_on_floor() and not esta_disparando:
			tiempo_paso += delta * velocity.length() * 1.5
			var amplitud = 0.02
			if velocidad_actual == SPEED_RUN:
				amplitud = 0.06
				_tiempo_ruido_paso += delta
				if _tiempo_ruido_paso >= 0.35:
					_tiempo_ruido_paso = 0.0
					var ev_sonido = get_node_or_null("/root/EventosSonido")
					if ev_sonido:
						ev_sonido.emitir_ruido(global_position, 8.0)
				
			camara.h_offset = cos(tiempo_paso * 0.5) * amplitud + _shake_offset.x
			camara.v_offset = sin(tiempo_paso) * amplitud + _shake_offset.y
		else:
			camara.h_offset = lerp(camara.h_offset, _shake_offset.x, 8.0 * delta)
			camara.v_offset = lerp(camara.v_offset, _shake_offset.y, 8.0 * delta)
			
		if Input.is_action_pressed("apuntar"):
			camara.fov = lerp(camara.fov, FOV_APUNTADO, 10.0 * delta)
		else:
			camara.fov = lerp(camara.fov, FOV_NORMAL, 10.0 * delta)
	
	else:
		velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
		
	# --- LÓGICA DE COLOR DE LA MIRA Y TEXTO DE INTERACCIÓN ---
	if raycast.is_colliding():
		var objetivo_mirado = raycast.get_collider()
		if is_instance_valid(objetivo_mirado):
			# 1. Si miramos a un enemigo
			if objetivo_mirado.has_method("recibir_dano") or objetivo_mirado.has_method("alertar"):
				mirilla.color = Color(0.714, 0.0, 0.157, 1.0) 
				texto_interaccion.visible = false
			# 2. Si miramos a un objeto interactuable
			elif objetivo_mirado.has_method("recoger"):
				var distancia = global_position.distance_to(objetivo_mirado.global_position)
				if distancia <= 1.0:
					mirilla.color = Color(1, 1, 1) 
					texto_interaccion.visible = true
					texto_interaccion.text = "Presiona [ E ] para recoger arma"
				else:
					mirilla.color = Color(1,1,1)
					texto_interaccion.visible = false
			# 3. Si es pared o suelo
			else:
				mirilla.color = Color(1, 1, 1) 
				texto_interaccion.visible = false
		else:
			mirilla.color = Color(1, 1, 1)
			texto_interaccion.visible = false
	else:
		mirilla.color = Color(1, 1, 1)
		texto_interaccion.visible = false
		
	move_and_slide()

func disparar():
	esta_disparando = true
	var ev_sonido = get_node_or_null("/root/EventosSonido")
	if ev_sonido:
		ev_sonido.emitir_ruido(global_position, 20.0)
	var direccion_retroceso = pivot.transform.basis.z.normalized()
	velocity.x = direccion_retroceso.x * 10.0
	velocity.z = direccion_retroceso.z * 10.0
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var objetivo = raycast.get_collider()
		
		if objetivo.has_method("recibir_dano"):
			var direccion_tiro = global_position.direction_to(objetivo.global_position)
			objetivo.recibir_dano(35, direccion_tiro, self)
		
	var tween = create_tween()
	var posicion_original_z = 7.0
	
	tween.tween_property(camara, "position:z", 0.5, 0.0)
	tween.tween_property(camara, "position:z", posicion_original_z, 0.8)
	tween.tween_callback(func(): esta_disparando = false)

func recibir_dano(cantidad: float, origen: Vector3 = Vector3.ZERO) -> void:
	if muerto or invulnerable or cantidad <= 0.0:
		return
		
	invulnerable = true
	get_tree().create_timer(tiempo_invulnerabilidad).timeout.connect(func(): invulnerable = false)
	
	vida_actual = maxf(vida_actual - cantidad, 0.0)
	vida_cambiada.emit(vida_actual, vida_maxima)
	
	# Knockback alejándolo del origen
	if origen != Vector3.ZERO:
		var knock = (global_position - origen)
		knock.y = 0.0
		if knock.length_squared() > 0.001:
			velocity += knock.normalized() * 5.0
			
	# Sacudida de cámara breve (0.25 s) con Tween
	var intensidad_shake = clampf(cantidad / 35.0, 0.3, 1.2) * 0.08
	if _tween_shake and _tween_shake.is_valid():
		_tween_shake.kill()
	_tween_shake = create_tween()
	_tween_shake.tween_method(func(prog: float):
		_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * intensidad_shake * prog
	, 1.0, 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_shake.tween_callback(func(): _shake_offset = Vector2.ZERO)
	
	# Destello rojo en pantalla con viñeta (se desvanece en ~0.6 s)
	if overlay_danio and overlay_danio.material:
		var mat := overlay_danio.material as ShaderMaterial
		mat.set_shader_parameter("flash_intensity", 1.0)
		mat.set_shader_parameter("vignette_intensity", clampf(cantidad / 25.0, 0.6, 1.0))
		if _tween_flash and _tween_flash.is_valid():
			_tween_flash.kill()
		_tween_flash = create_tween().set_parallel(true)
		_tween_flash.tween_property(mat, "shader_parameter/flash_intensity", 0.0, 0.4)
		_tween_flash.tween_property(mat, "shader_parameter/vignette_intensity", 0.0, 0.6)
		
	# Sonido de daño preparado
	if audio_danio and audio_danio.stream != null:
		audio_danio.play()
		
	# Comprobación de muerte
	if vida_actual <= 0.0 and not muerto:
		muerto = true
		jugador_murio.emit()

func curar(cantidad: float) -> void:
	if muerto or cantidad <= 0.0:
		return
	vida_actual = minf(vida_actual + cantidad, vida_maxima)
	vida_cambiada.emit(vida_actual, vida_maxima)
	
	# Si la vida sube por encima del 30%, desvanecer la viñeta permanente
	if (vida_actual / vida_maxima) > 0.3 and overlay_danio and overlay_danio.material:
		var mat := overlay_danio.material as ShaderMaterial
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/vignette_intensity", 0.0, 0.4)

func _on_vida_cambiada(nueva_vida: float, max_v: float) -> void:
	if barra_vida:
		barra_vida.max_value = max_v
		if _tween_barra and _tween_barra.is_valid():
			_tween_barra.kill()
		_tween_barra = create_tween()
		_tween_barra.tween_property(barra_vida, "value", nueva_vida, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if label_vida_val:
		label_vida_val.text = "%d / %d" % [roundi(nueva_vida), roundi(max_v)]
